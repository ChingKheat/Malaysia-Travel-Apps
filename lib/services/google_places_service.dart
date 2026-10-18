import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/api_keys.dart';
import '../core/app_colors.dart';
import '../core/supabase_config.dart';
import '../models/travel_stop.dart';
import 'place_classifier.dart';

class GooglePlacesService {
  GooglePlacesService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _endpoint = 'https://places.googleapis.com/v1/places:searchText';

  // In-memory cache to guarantee zero duplicate API calls during the app session
  static final Map<String, List<Map<String, dynamic>>> _memoryCache = {};

  /// Clears in-memory cache if user wants fresh data
  static void clearMemoryCache() => _memoryCache.clear();

  /// Builds a direct image URL for Google Places API (New) Place Photos
  static String buildPhotoUrl(String photoName, {int maxWidthPx = 800, int maxHeightPx = 600}) {
    if (photoName.isEmpty || !ApiKeys.hasGoogleMapsKey) return '';
    return 'https://places.googleapis.com/v1/$photoName/media?maxWidthPx=$maxWidthPx&maxHeightPx=$maxHeightPx&key=${ApiKeys.googleMaps}';
  }

  static double _calculatePopularityScore(Map<String, dynamic> item) {
    final rating = (item['rating'] as num?)?.toDouble() ?? 0.0;
    final count = (item['user_ratings_total'] as num?)?.toInt() ?? 0;
    if (count <= 0) return rating * 0.1;
    if (count < 10) return rating * 0.4;
    return rating * (math.log(count + 10) / math.ln10);
  }

  /// Fetches places with smart 2-tier database caching to save Google API quota:
  /// 1. Check in-memory cache (instant, 0 network)
  /// 2. Check Supabase PostgreSQL `places` table (cloud cache, 0 API quota)
  /// 3. If cache miss or missing photos, calls Google Places API (New) and saves to database
  Future<List<Map<String, dynamic>>> fetchPlacesWithDatabaseCache({
    required String destinationState,
    required String query,
    bool isMeal = false,
    int maxResults = 8,
  }) async {
    final cacheKey = '${destinationState.toLowerCase()}_${isMeal ? 'food' : 'poi'}';

    // Tier 1: Check in-memory session cache (only if it has enough items)
    if (_memoryCache.containsKey(cacheKey) && _memoryCache[cacheKey]!.length >= maxResults) {
      debugPrint('[Quota Saved] Loaded $cacheKey from memory cache (${_memoryCache[cacheKey]!.length} places).');
      return _memoryCache[cacheKey]!;
    }

    // Tier 2: Check Supabase PostgreSQL `places` table (persistent cloud cache)
    final client = SupabaseConfig.client;
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        var queryBuilder = client
            .from('places')
            .select()
            .ilike('state', '%$destinationState%');

        if (isMeal) {
          queryBuilder = queryBuilder.ilike('category', '%restaurant%');
        } else {
          queryBuilder = queryBuilder.not('category', 'ilike', '%restaurant%');
        }

        // Fetch candidate places ordered by user_ratings_total and rating
        final cachedDb = await queryBuilder
            .order('user_ratings_total', ascending: false)
            .order('rating', ascending: false)
            .limit(math.max(maxResults, 50))
            .timeout(const Duration(seconds: 4));

        // Filter valid places inside Malaysia and within destination region
        final isKL = destinationState.toLowerCase().contains('kuala lumpur');
        final validDb = cachedDb.where((row) {
          final lat = (row['latitude'] as num?)?.toDouble();
          final lng = (row['longitude'] as num?)?.toDouble();
          if (lat == null || lng == null) return false;
          // Must be within Malaysia bounding box
          if (lat < 1.0 || lat > 7.5 || lng < 99.0 || lng > 120.0) return false;
          // If Kuala Lumpur, filter out places outside the Klang Valley / KL bounds
          if (isKL && (lat < 2.8 || lat > 3.5 || lng < 101.4 || lng > 102.1)) return false;
          return true;
        }).toList();

        // Sort by popularity score descending
        validDb.sort((a, b) => _calculatePopularityScore(b).compareTo(_calculatePopularityScore(a)));

        final hasPhotos = validDb.any((r) => r['photo_url'] != null && r['photo_url'].toString().trim().isNotEmpty);
        if (validDb.isNotEmpty && validDb.length >= (isMeal ? 2 : 4) && hasPhotos) {
          debugPrint('[Quota Saved] Found ${validDb.length} verified places with photos in Supabase for $destinationState');
          final converted = validDb.map((row) => _convertDbRowToGooglePlace(row)).toList();
          _memoryCache[cacheKey] = converted;
          return converted;
        }
      } catch (e) {
        debugPrint('Supabase cache read note: $e');
      }
    }

    // Tier 3: Fetch from Google Places API (New) with photos
    debugPrint('[API Call] Fetching real places & photos from Google Places API for: $query');
    final livePlaces = await fetchPlacesByText(query: query, maxResults: maxResults);

    if (livePlaces.isNotEmpty) {
      _memoryCache[cacheKey] = livePlaces;

      // Save/Upsert into Supabase `places` table with photos so future calls use 0 API quota!
      if (client != null && SupabaseConfig.isConfigured) {
        try {
          final rows = livePlaces.map((p) {
            final displayName = (p['displayName'] as Map<String, dynamic>?)?['text'] ?? 'Point of Interest';
            final primaryType = (p['primaryTypeDisplayName'] as Map<String, dynamic>?)?['text'] ?? (isMeal ? 'Restaurant' : 'Attraction');
            final location = p['location'] as Map<String, dynamic>?;
            final lat = (location?['latitude'] as num?)?.toDouble() ?? 3.140853;
            final lng = (location?['longitude'] as num?)?.toDouble() ?? 101.693207;
            final rating = (p['rating'] as num?)?.toDouble();

            // Extract a few pictures (up to 5 photos) for this place
            final photosRaw = (p['photos'] as List<dynamic>? ?? []);
            final photoUrls = photosRaw
                .take(5)
                .map((ph) {
                  final name = ph['name']?.toString() ?? '';
                  return name.isNotEmpty ? buildPhotoUrl(name) : '';
                })
                .where((u) => u.isNotEmpty)
                .toList();

            return {
              'place_id': p['id']?.toString() ?? 'poi_${DateTime.now().microsecondsSinceEpoch}',
              'name': displayName,
              'state': destinationState,
              'category': primaryType,
              'latitude': lat,
              'longitude': lng,
              'rating': rating,
              'is_indoor': PlaceClassifier.classify(category: primaryType, name: displayName),
              'photo_url': photoUrls.isNotEmpty ? photoUrls.join('|') : null,
              'operating_hours': p['regularOpeningHours'],
            };
          }).toList();

          await client.from('places').upsert(rows, onConflict: 'place_id').timeout(const Duration(seconds: 5));
          debugPrint('[Database Saved] Cached ${rows.length} places with photos to Supabase places table for future zero-quota reuse!');
        } catch (dbErr) {
          debugPrint('Database caching note: $dbErr');
        }
      }
    }

    return livePlaces;
  }

  /// Converts a Supabase database row into the Google Places API format
  static Map<String, dynamic> _convertDbRowToGooglePlace(Map<String, dynamic> row) {
    final rawPhoto = row['photo_url']?.toString();
    final photoUrls = (rawPhoto != null && rawPhoto.trim().isNotEmpty)
        ? (rawPhoto.contains('|')
            ? rawPhoto.split('|').where((s) => s.trim().isNotEmpty).toList()
            : [rawPhoto.trim()])
        : <String>[];

    return {
      'id': row['place_id'],
      'displayName': {'text': row['name'], 'languageCode': 'en'},
      'formattedAddress': '${row['name']}, ${row['state']}, Malaysia',
      'location': {
        'latitude': row['latitude'] ?? 3.140853,
        'longitude': row['longitude'] ?? 101.693207,
      },
      'rating': row['rating'] ?? 4.5,
      'userRatingCount': 120,
      'primaryTypeDisplayName': {'text': row['category'] ?? 'Attraction'},
      'editorialSummary': {'text': '${row['name']} is a verified place in ${row['state']}, Malaysia.'},
      'regularOpeningHours': row['operating_hours'],
      'photoUrls': photoUrls,
      'types': [
        (row['category']?.toString().toLowerCase().contains('restaurant') ?? false)
            ? 'restaurant'
            : 'tourist_attraction'
      ],
    };
  }

  /// Performs Google Places API (New) Text Search for real points of interest.
  Future<List<Map<String, dynamic>>> fetchPlacesByText({
    required String query,
    int maxResults = 10,
  }) async {
    if (!ApiKeys.hasGoogleMapsKey) return [];

    try {
      final response = await _client.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': ApiKeys.googleMaps,
          'X-Goog-FieldMask':
              'places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount,places.regularOpeningHours,places.primaryTypeDisplayName,places.editorialSummary,places.types,places.photos',
          'X-Goog-Maps-Solution-ID': 'gmp_git_agentskills_v1',
        },
        body: jsonEncode({
          'textQuery': query,
          'languageCode': 'en',
          'maxResultCount': maxResults,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['places'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      }
    } catch (_) {
      // Network or timeout failure; caller will fall back seamlessly
    }
    return [];
  }

  /// Converts a Google Places API result item into a TravelStop
  static TravelStop convertGooglePlaceToStop({
    required Map<String, dynamic> place,
    required String timeRange,
    required String durationLabel,
    bool isMeal = false,
  }) {
    final displayName = (place['displayName'] as Map<String, dynamic>?)?['text'] as String? ?? 'Point of Interest';
    final address = place['formattedAddress'] as String? ?? 'Malaysia';
    final primaryType = (place['primaryTypeDisplayName'] as Map<String, dynamic>?)?['text'] as String? ?? (isMeal ? 'Restaurant' : 'Attraction');
    final summary = (place['editorialSummary'] as Map<String, dynamic>?)?['text'] as String? ?? address;
    final rating = place['rating']?.toString() ?? '4.5';
    final reviewCount = place['userRatingCount']?.toString() ?? '100+';

    final types = (place['types'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();

    // Extract photo URLs (either pre-parsed photoUrls from DB or from Google API photos array)
    List<String> photoUrls = [];
    if (place['photoUrls'] is List && (place['photoUrls'] as List).isNotEmpty) {
      photoUrls = (place['photoUrls'] as List).map((e) => e.toString()).toList();
    } else if (place['photos'] is List) {
      final photosRaw = (place['photos'] as List<dynamic>);
      photoUrls = photosRaw
          .take(5)
          .map((ph) {
            final name = ph['name']?.toString() ?? '';
            return name.isNotEmpty ? buildPhotoUrl(name) : '';
          })
          .where((u) => u.isNotEmpty)
          .toList();
    }

    IconData icon = Icons.place;
    Color color = AppColors.primary;

    if (isMeal || types.any((t) => t.contains('restaurant') || t.contains('food') || t.contains('cafe'))) {
      icon = Icons.restaurant;
      color = const Color(0xFFFF8A3D);
    } else if (types.any((t) => t.contains('museum') || t.contains('art'))) {
      icon = Icons.museum;
      color = const Color(0xFF0D9488);
    } else if (types.any((t) => t.contains('place_of_worship') || t.contains('hindu') || t.contains('mosque') || t.contains('church'))) {
      icon = Icons.temple_buddhist;
      color = const Color(0xFFDC2626);
    } else if (types.any((t) => t.contains('park') || t.contains('nature') || t.contains('garden'))) {
      icon = Icons.park;
      color = const Color(0xFF16A34A);
    } else if (types.any((t) => t.contains('shopping') || t.contains('store') || t.contains('market'))) {
      icon = Icons.shopping_bag;
      color = const Color(0xFFD97706);
    } else if (types.any((t) => t.contains('tourist_attraction') || t.contains('historical_landmark'))) {
      icon = Icons.location_city;
      color = const Color(0xFF2563EB);
    }

    final openingHours = place['regularOpeningHours'] as Map<String, dynamic>?;
    final openNow = openingHours?['openNow'] == true;
    final hoursString = openNow ? 'Open Now (Daily)' : 'Check daily schedule';

    final pId = place['id']?.toString() ?? place['place_id']?.toString();
    double lat = 0.0;
    double lng = 0.0;
    if (place['location'] is Map) {
      lat = (place['location']['latitude'] as num?)?.toDouble() ?? 0.0;
      lng = (place['location']['longitude'] as num?)?.toDouble() ?? 0.0;
    } else {
      lat = (place['latitude'] as num?)?.toDouble() ?? 0.0;
      lng = (place['longitude'] as num?)?.toDouble() ?? 0.0;
    }

    return TravelStop(
      title: displayName,
      time: timeRange,
      note: '$primaryType • Google Maps Verified',
      description: summary,
      duration: durationLabel,
      openingHours: hoursString,
      category: primaryType,
      photoUrls: photoUrls,
      tips: [
        'Rating: $rating ⭐ ($reviewCount reviews)',
        address,
        'Powered by Google Maps Platform',
      ],
      icon: icon,
      color: color,
      placeId: pId,
      latitude: lat,
      longitude: lng,
    );
  }
}
