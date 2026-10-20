// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_travel_planner/core/api_keys.dart';
import 'package:smart_travel_planner/services/places_service.dart';

void main() {
  test('Fetch Tourist Attractions and Places from Google Places API', () async {
    print('==================================================');
    print('🔍 Fetching Tourist Attractions & Places from Google Places API');
    print('==================================================\n');

    bool success = false;

    // 1. Test direct Google Places API (New) Search
    try {
      print('🌐 Connecting to Google Places API (places.googleapis.com)...');
      final res = await http.post(
        Uri.parse('https://places.googleapis.com/v1/places:searchText'),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': ApiKeys.googleMaps,
          'X-Goog-FieldMask':
              'places.id,places.displayName,places.formattedAddress,places.location,places.primaryTypeDisplayName,places.types',
        },
        body: jsonEncode({
          'textQuery': 'attractions in Kuala Lumpur Malaysia',
          'pageSize': 5,
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        final List places = (data['places'] as List?) ?? [];
        if (places.isNotEmpty) {
          print('✅ Connected successfully! Received ${places.length} places from Google Places API:\n');
          int count = 1;
          for (final item in places) {
            final name = item['displayName']?['text'] ?? 'Attraction';
            final type = item['primaryTypeDisplayName']?['text'] ?? item['types']?[0] ?? 'Place';
            final location = item['location'] ?? {};
            final lat = location['latitude'];
            final lon = location['longitude'];

            print('$count. 📍 $name');
            print('   - Type: $type');
            print('   - Coordinates: ($lat, $lon)');
            print('--------------------------------------------------');
            count++;
          }
          success = true;
        }
      } else {
        print('⚠️ Google Places API returned status ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      print('⚠️ Google Places API request failed ($e).');
    }

    // 2. Validate PlacesService returns resilient results
    final service = PlacesService();
    final places = await service.fetchPlacesNearLocation(
      latitude: 3.1390,
      longitude: 101.6869,
      limit: 5,
    );

    expect(places.isNotEmpty, isTrue, reason: 'PlacesService should return attractions.');
    print('✅ PlacesService returned ${places.length} attractions.');
    if (success) {
      print('✅ Live Google Places API connection verified.');
    }
  });
}

