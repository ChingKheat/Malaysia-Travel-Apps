// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const String googleApiKey = 'AIzaSyDAPLDpQt61HmTptGwswe9usaUVRoxhcMw';
const String supabaseUrl = 'https://yavslytukzgphvaqspcq.supabase.co';
const String supabaseKey = 'sb_publishable_6ERkrwdS5BLYRfd-JlBj2w_WTngwXsP';

/// Predefined states to seed
const List<String> defaultStates = [
  'Penang',
  'Kuala Lumpur',
  'Melaka',
];

void main(List<String> args) async {
  final targetStates = args.isNotEmpty ? args : defaultStates;

  print('===============================================================');
  print('🚀 SMART TRAVEL PLANNER - BULK PLACE DATA SEEDER');
  print('🌐 Destination States: ${targetStates.join(', ')}');
  print('===============================================================\n');

  final client = http.Client();

  for (final state in targetStates) {
    print('📍 [Fetching State] Starting data fetch for: $state ...');
    await seedState(client, state);
    print('---------------------------------------------------------------\n');
  }

  client.close();
  print('🎉 All states successfully seeded into Supabase database!');
}

Future<void> seedState(http.Client client, String state) async {
  final queries = [
    {
      'query': 'top tourist attractions and famous landmarks in $state, Malaysia',
      'categoryHint': 'Attraction',
    },
    {
      'query': 'famous local food, hawker centers and top restaurants in $state, Malaysia',
      'categoryHint': 'Restaurant',
    },
    {
      'query': 'nature parks, beaches, scenic viewpoints and cultural spots in $state, Malaysia',
      'categoryHint': 'Nature & Culture',
    },
  ];

  final allPlaces = <String, Map<String, dynamic>>{};

  for (final q in queries) {
    final queryText = q['query']!;
    final categoryHint = q['categoryHint']!;
    print('   🔎 Querying Google Places API: "$queryText" ...');

    try {
      final res = await client.post(
        Uri.parse('https://places.googleapis.com/v1/places:searchText'),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': googleApiKey,
          'X-Goog-FieldMask':
              'places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount,places.regularOpeningHours,places.primaryTypeDisplayName,places.editorialSummary,places.types,places.photos',
        },
        body: jsonEncode({
          'textQuery': queryText,
          'languageCode': 'en',
          'maxResultCount': 15,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final placesList = (data['places'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
        print('   ✅ Received ${placesList.length} places from Google.');

        for (final p in placesList) {
          final placeId = p['id']?.toString();
          if (placeId == null || placeId.isEmpty) continue;

          final name = (p['displayName'] as Map<String, dynamic>?)?['text'] ?? 'Point of Interest';
          final primaryType = (p['primaryTypeDisplayName'] as Map<String, dynamic>?)?['text'] ?? categoryHint;
          final location = p['location'] as Map<String, dynamic>?;
          final lat = (location?['latitude'] as num?)?.toDouble() ?? 0.0;
          final lng = (location?['longitude'] as num?)?.toDouble() ?? 0.0;
          final rating = (p['rating'] as num?)?.toDouble();

          final photosRaw = (p['photos'] as List<dynamic>? ?? []);
          final photoUrls = photosRaw
              .take(5)
              .map((ph) {
                final photoName = ph['name']?.toString() ?? '';
                if (photoName.isEmpty) return '';
                return 'https://places.googleapis.com/v1/$photoName/media?maxWidthPx=800&maxHeightPx=600&key=$googleApiKey';
              })
              .where((url) => url.isNotEmpty)
              .toList();

          allPlaces[placeId] = {
            'place_id': placeId,
            'name': name,
            'state': state,
            'category': primaryType,
            'latitude': lat,
            'longitude': lng,
            'rating': rating,
            'photo_url': photoUrls.isNotEmpty ? photoUrls.join('|') : null,
            'operating_hours': p['regularOpeningHours'],
          };
        }
      } else {
        print('   ❌ Google API error (${res.statusCode}): ${res.body}');
      }
    } catch (e) {
      print('   ⚠️ Exception querying Google: $e');
    }
  }

  print('   📦 Total unique places gathered for $state: ${allPlaces.length}');

  if (allPlaces.isNotEmpty) {
    final rows = allPlaces.values.toList();
    try {
      File('tool/${state.toLowerCase()}_places.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(rows),
      );
      print('   💾 Saved ${rows.length} places locally to tool/${state.toLowerCase()}_places.json');
    } catch (_) {}

    print('   💾 Uploading/Upserting to Supabase PostgreSQL database...');

    try {
      final supabaseRes = await client.post(
        Uri.parse('$supabaseUrl/rest/v1/places'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': supabaseKey,
          'Authorization': 'Bearer sb_publishable_6ERkrwdS5BLYRfd-JlBj2w_WTngwXsP',
          'Prefer': 'resolution=merge-duplicates',
        },
        body: jsonEncode(rows),
      );

      if (supabaseRes.statusCode >= 200 && supabaseRes.statusCode < 300) {
        print('   🎉 SUCCESS! Saved ${rows.length} places for $state into Supabase database with real photos & coordinates!');
      } else {
        print('   ❌ Supabase error (${supabaseRes.statusCode}): ${supabaseRes.body}');
      }
    } catch (dbErr) {
      print('   ⚠️ Exception saving to Supabase: $dbErr');
    }
  }
}
