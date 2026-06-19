import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_keys.dart';
import '../models/attraction.dart';

class OpenTripMapService {
  OpenTripMapService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _baseUrl = 'api.opentripmap.com';

  Future<List<Attraction>> fetchAttractionsNearKualaLumpur({
    double latitude = 3.1390,
    double longitude = 101.6869,
    int radiusMeters = 9000,
    int limit = 24,
  }) async {
    if (!ApiKeys.hasOpenTripMapKey) return demoAttractions;

    final uri = Uri.https(_baseUrl, '/0.1/en/places/radius', {
      'radius': '$radiusMeters',
      'lon': '$longitude',
      'lat': '$latitude',
      'kinds': 'interesting_places,cultural,historic,architecture',
      'format': 'json',
      'limit': '$limit',
      'apikey': ApiKeys.openTripMap,
    });

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw ApiException('OpenTripMap request failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const ApiException('OpenTripMap returned an unexpected response.');
    }

    final attractions = decoded
        .whereType<Map<String, dynamic>>()
        .map(Attraction.fromOpenTripMapJson)
        .where(
          (item) => item.xid.isNotEmpty && item.name != 'Unnamed attraction',
        )
        .toList();

    return attractions.isEmpty ? demoAttractions : attractions;
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

const demoAttractions = [
  Attraction(
    xid: 'demo_batu_caves',
    name: 'Batu Caves',
    latitude: 3.2379,
    longitude: 101.6840,
    category: 'religion, cultural',
    description:
        'A limestone hill with Hindu temples, colorful stairs and popular tourist photo spots.',
    distanceMeters: 8900,
  ),
  Attraction(
    xid: 'demo_central_market',
    name: 'Central Market',
    latitude: 3.1457,
    longitude: 101.6953,
    category: 'culture, shopping',
    description:
        'A heritage market with Malaysian crafts, souvenirs, snacks and local cultural products.',
    distanceMeters: 1200,
  ),
  Attraction(
    xid: 'demo_jalan_alor',
    name: 'Jalan Alor',
    latitude: 3.1468,
    longitude: 101.7087,
    category: 'food, local experience',
    description:
        'A famous food street in Bukit Bintang with local dishes and lively night dining.',
    distanceMeters: 2400,
  ),
  Attraction(
    xid: 'demo_petronas',
    name: 'Petronas Twin Towers',
    latitude: 3.1579,
    longitude: 101.7120,
    category: 'architecture, landmark',
    description:
        'Malaysia iconic twin skyscrapers with nearby mall access and excellent city views.',
    distanceMeters: 3100,
  ),
  Attraction(
    xid: 'demo_klcc_park',
    name: 'KLCC Park',
    latitude: 3.1541,
    longitude: 101.7155,
    category: 'park, outdoor',
    description:
        'A landscaped city park near KLCC with walking paths, skyline views and relaxation spots.',
    distanceMeters: 3400,
  ),
  Attraction(
    xid: 'demo_masjid_jamek',
    name: 'Masjid Jamek',
    latitude: 3.1496,
    longitude: 101.6955,
    category: 'religion, history',
    description:
        'A historic mosque located near the meeting point of the Klang and Gombak rivers.',
    distanceMeters: 1300,
  ),
];
