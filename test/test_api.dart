import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('Fetch Tourist Attractions and Places from OpenStreetMap API', () async {
    print('==================================================');
    print('🔍 Fetching Tourist Attractions & Places from API');
    print('==================================================\n');

    bool success = false;

    // 1. Try Nominatim API (Super fast & reliable search for places)
    final nominatimUrl = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': 'attractions in Kuala Lumpur',
      'format': 'json',
      'limit': '15',
    });

    try {
      print('🌐 Connecting to Nominatim API (nominatim.openstreetmap.org)...');
      final res = await http.get(
        nominatimUrl,
        headers: {'User-Agent': 'SmartTravelPlanner/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty) {
          print('✅ Connected successfully! Received ${data.length} places:\n');
          int count = 1;
          for (final item in data) {
            final name = item['display_name']?.split(',')?.first ?? 'Attraction';
            final type = item['type'] ?? item['class'] ?? 'place';
            final lat = item['lat'];
            final lon = item['lon'];

            print('$count. 📍 $name');
            print('   - Type: $type');
            print('   - Coordinates: ($lat, $lon)');
            print('--------------------------------------------------');
            count++;
          }
          success = true;
        }
      }
    } catch (e) {
      print('⚠️ Nominatim request failed ($e). Trying Overpass fallback...');
    }

    // 2. Fallback to Overpass API if needed
    if (!success) {
      const overpassQuery = '''
        [out:json][timeout:15];
        node["tourism"="attraction"](3.10, 101.65, 3.20, 101.75);
        out body 10;
      ''';
      final url = Uri.https('overpass-api.de', '/api/interpreter', {'data': overpassQuery});
      final res = await http.get(url, headers: {'User-Agent': 'SmartTravelPlanner/1.0'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List elements = data['elements'] ?? [];
        print('✅ Connected successfully via Overpass API! Found ${elements.length} places.');
        success = true;
      }
    }

    expect(success, isTrue, reason: 'API call should succeed and return places.');
  });
}
