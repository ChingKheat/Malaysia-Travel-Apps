import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_keys.dart';
import '../models/attraction.dart';

class OpenTripMapService {
  OpenTripMapService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _baseUrl = 'api.opentripmap.com';

  Future<List<Attraction>> fetchAttractionsNearKualaLumpur({
    required double latitude,
    required double longitude,
    int radiusMeters = 8000,
    int limit = 40,
  }) async {
    if (!ApiKeys.hasOpenTripMapKey) {
      return [];
    }

    final uri = Uri.https(_baseUrl, '/0.1/en/places/radius', {
      'radius': '$radiusMeters',
      'lon': '$longitude',
      'lat': '$latitude',
      'kinds': 'interesting_places,cultural,historic,architecture,foods,shops,natural',
      'format': 'json',
      'limit': '$limit',
      'apikey': ApiKeys.openTripMap,
    });

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      return [];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return [];
    }

    final attractions = decoded
        .whereType<Map<String, dynamic>>()
        .map(Attraction.fromOpenTripMapJson)
        .where(
          (item) => item.xid.isNotEmpty && item.name != 'Unnamed attraction',
        )
        .toList();

    return attractions;
  }

  Future<Attraction> fetchAttractionDetails(Attraction attraction) async {
    if (!ApiKeys.hasOpenTripMapKey || attraction.xid.startsWith('demo_')) {
      return attraction;
    }

    final uri = Uri.https(_baseUrl, '/0.1/en/places/xid/${attraction.xid}', {
      'apikey': ApiKeys.openTripMap,
    });

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return attraction;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return attraction;

    return Attraction.fromOpenTripMapDetails(attraction, decoded);
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

