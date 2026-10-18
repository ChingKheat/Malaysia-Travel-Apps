import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../data/curated_attractions.dart';
import '../models/attraction.dart';

class PlacesService {
  PlacesService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _overpassUrl = 'https://overpass-api.de/api/interpreter';

  Future<List<Attraction>> fetchPlacesNearLocation({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
    int limit = 30,
  }) async {
    try {
      final query = '''
[out:json][timeout:8];
(
  node["tourism"](around:$radiusMeters,$latitude,$longitude);
  node["amenity"~"restaurant|cafe|fast_food|marketplace|place_of_worship"](around:$radiusMeters,$latitude,$longitude);
  node["shop"~"mall|department_store|supermarket|craft"](around:$radiusMeters,$latitude,$longitude);
  node["historic"](around:$radiusMeters,$latitude,$longitude);
);
out body $limit;
''';

      final response = await _client
          .post(
            Uri.parse(_overpassUrl),
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
        if (decoded != null) {
          final elements = decoded['elements'] as List<dynamic>? ?? [];
          final List<Attraction> results = [];

          for (final element in elements) {
            if (element is Map<String, dynamic>) {
              final tags = element['tags'] as Map<String, dynamic>?;
              if (tags != null && (tags.containsKey('name') || tags.containsKey('name:en'))) {
                final attraction = Attraction.fromOverpassJson(
                  element,
                  centerLat: latitude,
                  centerLon: longitude,
                );
                results.add(attraction);
              }
            }
          }

          if (results.isNotEmpty) {
            // Sort by proximity
            results.sort((a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));
            return results;
          }
        }
      }
    } catch (_) {
      // Offline, timeout, or Overpass network error - proceed to resilient fallback
    }

    // Seamless offline/unreachable fallback conforming to Rule 2
    return _getFallbackAttractions(latitude, longitude, limit);
  }

  /// Calculates real-time distance from user coordinates to curated Malaysian attractions
  List<Attraction> _getFallbackAttractions(
    double userLat,
    double userLon,
    int limit,
  ) {
    const distanceCalc = Distance();
    final userPos = LatLng(userLat, userLon);

    final mapped = curatedMalaysianAttractions.map((attraction) {
      final dist = distanceCalc.as(
        LengthUnit.Meter,
        userPos,
        LatLng(attraction.latitude, attraction.longitude),
      );
      return attraction.copyWith(distanceMeters: dist);
    }).toList();

    mapped.sort((a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));
    return mapped.take(limit).toList();
  }
}

