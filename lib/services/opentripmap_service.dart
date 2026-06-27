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
      // In mock mode, we filter demoAttractions based on distance/relevance to selected coordinate
      // to make the mock experience feel dynamic and real!
      return _getFilteredDemoAttractions(latitude, longitude);
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

    return attractions.isEmpty ? _getFilteredDemoAttractions(latitude, longitude) : attractions;
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

  // Simulates fetching relevant mock data based on selected area
  List<Attraction> _getFilteredDemoAttractions(double lat, double lon) {
    // If coordinates are close to George Town, Penang (Lat ~5.4, Lon ~100.3)
    if ((lat - 5.4).abs() < 0.2) {
      return demoPenangAttractions;
    }
    // If coordinates are close to Melaka (Lat ~2.2, Lon ~102.2)
    if ((lat - 2.2).abs() < 0.2) {
      return demoMelakaAttractions;
    }
    // Default to Kuala Lumpur mock database
    return demoKLAttractions;
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

// Kuala Lumpur Mock Database with Sights, Food, Shops & Nature
const demoKLAttractions = [
  Attraction(
    xid: 'demo_batu_caves',
    name: 'Batu Caves Hindu Temple',
    latitude: 3.2379,
    longitude: 101.6840,
    category: 'religion, cultural, sights',
    description: 'A limestone hill with Hindu temples, colorful stairs and popular tourist photo spots.',
    distanceMeters: 1200,
  ),
  Attraction(
    xid: 'demo_central_market',
    name: 'Central Market Souvenirs',
    latitude: 3.1457,
    longitude: 101.6953,
    category: 'culture, shopping, shops',
    description: 'A heritage market with Malaysian crafts, souvenirs, snacks and local cultural products.',
    distanceMeters: 450,
  ),
  Attraction(
    xid: 'demo_jalan_alor',
    name: 'Jalan Alor Street Food',
    latitude: 3.1468,
    longitude: 101.7087,
    category: 'foods, restaurant, local experience',
    description: 'A famous food street in Bukit Bintang with local dishes and lively night dining.',
    distanceMeters: 1400,
  ),
  Attraction(
    xid: 'demo_petronas',
    name: 'Petronas Twin Towers',
    latitude: 3.1579,
    longitude: 101.7120,
    category: 'architecture, landmark, sights',
    description: 'Malaysia iconic twin skyscrapers with nearby mall access and excellent city views.',
    distanceMeters: 2200,
  ),
  Attraction(
    xid: 'demo_klcc_park',
    name: 'KLCC Park & Fountains',
    latitude: 3.1541,
    longitude: 101.7155,
    category: 'park, natural, nature',
    description: 'A landscaped city park near KLCC with walking paths, skyline views and relaxation spots.',
    distanceMeters: 2500,
  ),
  Attraction(
    xid: 'demo_suria_klcc',
    name: 'Suria KLCC Shopping Mall',
    latitude: 3.1575,
    longitude: 101.7115,
    category: 'shopping, mall, shops',
    description: 'A premier 6-story shopping mall located at the foot of the Petronas Twin Towers.',
    distanceMeters: 2150,
  ),
  Attraction(
    xid: 'demo_vcr_cafe',
    name: 'VCR Specialty Cafe',
    latitude: 3.1420,
    longitude: 101.7025,
    category: 'foods, cafe, restaurant',
    description: 'A highly rated coffee spot serving artisan coffee, breakfast and famous local cakes.',
    distanceMeters: 900,
  ),
  Attraction(
    xid: 'demo_pavilion_kl',
    name: 'Pavilion Kuala Lumpur Mall',
    latitude: 3.1488,
    longitude: 101.7135,
    category: 'shopping, mall, shops',
    description: 'A large, upscale shopping mall in the Bukit Bintang district known for luxury shopping.',
    distanceMeters: 1800,
  ),
];

// Penang Mock Database with Sights, Food, Shops & Nature
const demoPenangAttractions = [
  Attraction(
    xid: 'demo_kek_lok_si',
    name: 'Kek Lok Si Temple',
    latitude: 5.3670,
    longitude: 100.2730,
    category: 'religion, history, sights',
    description: 'A grand Buddhist temple in Air Itam with a towering pagoda, bronze statue, and panoramic views.',
    distanceMeters: 6200,
  ),
  Attraction(
    xid: 'demo_penang_hill',
    name: 'Penang Hill Funicular & Nature',
    latitude: 5.4243,
    longitude: 100.2693,
    category: 'natural, park, nature',
    description: 'A lush forested peak offering fresh mountain air, walking trails, and city views reached by train.',
    distanceMeters: 5500,
  ),
  Attraction(
    xid: 'demo_gurney_drive',
    name: 'Gurney Drive Food Hawker',
    latitude: 5.4325,
    longitude: 100.3090,
    category: 'foods, restaurant, local experience',
    description: 'Famous seafront street market with Penang char koay teow, laksa, rojak, and satay stalls.',
    distanceMeters: 2200,
  ),
  Attraction(
    xid: 'demo_armenian_street',
    name: 'Armenian Street Murals',
    latitude: 5.4150,
    longitude: 100.3378,
    category: 'cultural, historic, sights',
    description: 'Artistic street in George Town filled with famous murals, historic shophouses, and craft stores.',
    distanceMeters: 800,
  ),
  Attraction(
    xid: 'demo_gurney_plaza',
    name: 'Gurney Plaza Shopping Mall',
    latitude: 5.4370,
    longitude: 100.3085,
    category: 'shopping, mall, shops',
    description: 'A premier beachfront shopping mall along Gurney Drive containing international brands.',
    distanceMeters: 2400,
  ),
  Attraction(
    xid: 'demo_chinahouse',
    name: 'ChinaHouse Cafe & Bakery',
    latitude: 5.4147,
    longitude: 100.3395,
    category: 'foods, cafe, restaurant',
    description: 'A popular heritage compound housing a bakery, art gallery, live music, and famous tall cakes.',
    distanceMeters: 900,
  ),
];

// Melaka Mock Database with Sights, Food, Shops & Nature
const demoMelakaAttractions = [
  Attraction(
    xid: 'demo_red_square',
    name: 'Melaka Dutch Red Square',
    latitude: 2.1948,
    longitude: 102.2492,
    category: 'historic, landmark, sights',
    description: 'Historic central plaza featuring the red-painted Christ Church, Stadthuys, and clock tower.',
    distanceMeters: 200,
  ),
  Attraction(
    xid: 'demo_famosa',
    name: 'A Famosa Portuguese Fort',
    latitude: 2.1925,
    longitude: 102.2505,
    category: 'historic, fortress, sights',
    description: 'A preserved gateway (Porta de Santiago) from the 16th-century Portuguese fortress of Melaka.',
    distanceMeters: 400,
  ),
  Attraction(
    xid: 'demo_jonker_walk',
    name: 'Jonker Street Night Market',
    latitude: 2.1963,
    longitude: 102.2475,
    category: 'shopping, shops, foods, local experience',
    description: 'A famous night street market in Chinatown filled with antiques, local foods, and street snacks.',
    distanceMeters: 300,
  ),
  Attraction(
    xid: 'demo_melaka_river',
    name: 'Melaka River Cruise & Walk',
    latitude: 2.1980,
    longitude: 102.2485,
    category: 'natural, natural, nature',
    description: 'A picturesque river winding through the city lined with historical murals, cafes, and walkways.',
    distanceMeters: 500,
  ),
  Attraction(
    xid: 'demo_jonker_chicken',
    name: 'Hoe Kee Chicken Rice Ball',
    latitude: 2.1955,
    longitude: 102.2482,
    category: 'foods, restaurant, local experience',
    description: 'Famous local restaurant serving Melaka specialty chicken rice balls and Hainan chicken.',
    distanceMeters: 150,
  ),
  Attraction(
    xid: 'demo_pahlawan_mall',
    name: 'Dataran Pahlawan Megamall',
    latitude: 2.1905,
    longitude: 102.2520,
    category: 'shopping, mall, shops',
    description: 'The largest shopping mall in Southern Malaysia, built directly on historical fields.',
    distanceMeters: 600,
  ),
];
