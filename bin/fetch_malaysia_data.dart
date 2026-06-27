// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('Fetching Malaysia states and cities from OpenStreetMap Overpass API...');

  // Overpass QL query: Find all nodes tagged as place=city or place=town inside Malaysia (ISO: MY)
  const query = '''
    [out:json][timeout:60];
    area["ISO3166-1"="MY"]->.malaysia;
    (
      node["place"="city"](area.malaysia);
      node["place"="town"](area.malaysia);
    );
    out body;
  ''';

  final url = Uri.https('overpass-api.de', '/api/interpreter', {'data': query});

  try {
    final response = await http.get(
      url,
      headers: {
        'User-Agent': 'SmartTravelPlanner/1.0 (chingkheat@example.com) Educational-Project',
      },
    );
    if (response.statusCode != 200) {
      print('Failed to load data: ${response.statusCode}');
      return;
    }

    final data = jsonDecode(response.body);
    final List elements = data['elements'] ?? [];

    print('Fetched ${elements.length} places. Grouping by state...');

    // Map to group areas by state
    // Key: State Name, Value: List of cities
    final Map<String, List<Map<String, dynamic>>> groupedData = {};

    for (final element in elements) {
      final tags = element['tags'] ?? {};
      final name = tags['name'] ?? tags['name:en'] ?? '';
      final lat = element['lat']?.toDouble();
      final lon = element['lon']?.toDouble();

      if (name.isEmpty || lat == null || lon == null) continue;

      // Extract state name from tags
      String state = tags['is_in:state'] ?? tags['addr:state'] ?? '';

      // Clean up state names or fallback if missing
      state = _cleanStateName(state, name);

      if (state.isEmpty) continue;

      groupedData.putIfAbsent(state, () => []);
      
      // Avoid duplicate names in the same state
      final exists = groupedData[state]!.any((e) => e['name'] == name);
      if (!exists) {
        groupedData[state]!.add({
          'name': name,
          'latitude': lat,
          'longitude': lon,
        });
      }
    }

    // Sort states and their cities alphabetically
    final sortedStates = groupedData.keys.toList()..sort();

    // Generate Dart file content
    final buffer = StringBuffer();
    buffer.writeln('// Generated automatically using Overpass API script. Do not edit manually.');
    buffer.writeln('');
    buffer.writeln('class CityArea {');
    buffer.writeln('  final String name;');
    buffer.writeln('  final double latitude;');
    buffer.writeln('  final double longitude;');
    buffer.writeln('');
    buffer.writeln('  const CityArea({');
    buffer.writeln('    required this.name,');
    buffer.writeln('    required this.latitude,');
    buffer.writeln('    required this.longitude,');
    buffer.writeln('  });');
    buffer.writeln('}');
    buffer.writeln('');
    buffer.writeln('class MalaysiaStateData {');
    buffer.writeln('  final String name;');
    buffer.writeln('  final List<CityArea> areas;');
    buffer.writeln('');
    buffer.writeln('  const MalaysiaStateData({');
    buffer.writeln('    required this.name,');
    buffer.writeln('    required this.areas,');
    buffer.writeln('  });');
    buffer.writeln('}');
    buffer.writeln('');
    buffer.writeln('const malaysiaStatesData = [');

    for (final stateName in sortedStates) {
      final cities = groupedData[stateName]!;
      // Limit to max 12 popular cities per state to keep the UI clean
      cities.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      final displayCities = cities.take(12);

      buffer.writeln('  MalaysiaStateData(');
      buffer.writeln('    name: \'$stateName\',');
      buffer.writeln('    areas: [');
      for (final city in displayCities) {
        buffer.writeln('      CityArea(name: \'${city['name']}\', latitude: ${city['latitude']}, longitude: ${city['longitude']}),');
      }
      buffer.writeln('    ],');
      buffer.writeln('  ),');
    }

    buffer.writeln('];');
    buffer.writeln('');
    buffer.writeln('List<String> get malaysiaStates => malaysiaStatesData.map((e) => e.name).toList();');

    // Write file
    final file = File('lib/data/malaysia_states.dart');
    await file.writeAsString(buffer.toString());

    print('Successfully generated ${file.path} with ${sortedStates.length} states and their areas!');
  } catch (e) {
    print('Error occurred: $e');
  }
}

// Fallback state mapping helper for OpenStreetMap's incomplete is_in:state tags
String _cleanStateName(String rawState, String cityName) {
  final clean = rawState.trim().toLowerCase();
  
  if (clean.contains('penang') || clean.contains('pulau pinang')) return 'Penang';
  if (clean.contains('johar') || clean.contains('johor')) return 'Johor';
  if (clean.contains('kedah')) return 'Kedah';
  if (clean.contains('kelantan')) return 'Kelantan';
  if (clean.contains('kuala lumpur')) return 'Kuala Lumpur';
  if (clean.contains('melaka') || clean.contains('malacca')) return 'Melaka';
  if (clean.contains('negeri sembilan')) return 'Negeri Sembilan';
  if (clean.contains('pahang')) return 'Pahang';
  if (clean.contains('perak')) return 'Perak';
  if (clean.contains('perlis')) return 'Perlis';
  if (clean.contains('sabah')) return 'Sabah';
  if (clean.contains('sarawak')) return 'Sarawak';
  if (clean.contains('selangor')) return 'Selangor';
  if (clean.contains('terengganu')) return 'Terengganu';
  if (clean.contains('putrajaya')) return 'Putrajaya';
  if (clean.contains('labuan')) return 'Labuan';

  // Manual geographical falls for major cities if state tag is empty
  final city = cityName.toLowerCase();
  if (const ['george town', 'butterworth', 'batu ferringhi', 'bayon lepas'].contains(city)) return 'Penang';
  if (const ['johor bahru', 'muar', 'batu pahat', 'kluang', 'seken'].contains(city)) return 'Johor';
  if (const ['kuala lumpur', 'bukit bintang', 'batu caves'].contains(city)) return 'Kuala Lumpur';
  if (const ['shah alam', 'petaling jaya', 'subang jaya', 'klang', 'kajang', 'rawang'].contains(city)) return 'Selangor';
  if (const ['melaka', 'alor gajah', 'jacin'].contains(city)) return 'Melaka';
  if (const ['kota kinabalu', 'sandakan', 'tawau', 'ranau'].contains(city)) return 'Sabah';
  if (const ['kuching', 'miri', 'sibu', 'bintulu'].contains(city)) return 'Sarawak';
  if (const ['ipoh', 'taiping', 'teluk intan'].contains(city)) return 'Perak';
  if (const ['langkawi', 'alor setar', 'sungai petani'].contains(city)) return 'Kedah';
  if (const ['kuantan', 'bentong', 'temerloh'].contains(city)) return 'Pahang';

  return ''; // Discard if we cannot identify the state
}
