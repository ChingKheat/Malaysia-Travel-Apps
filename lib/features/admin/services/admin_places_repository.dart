import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_travel_planner/core/config/supabase_config.dart';

class AdminPlacesPage {
  const AdminPlacesPage({required this.rows, required this.totalCount});
  final List<Map<String, dynamic>> rows;
  final int totalCount;
}

/// Database-only operations; these never request Google data.
class AdminPlacesRepository {
  static String? googleState(Map<String, dynamic> place) {
    const aliases = {
      'pulau pinang': 'Penang',
      'penang': 'Penang',
      'malacca': 'Melaka',
      'melaka': 'Melaka',
      'federal territory of kuala lumpur': 'Kuala Lumpur',
      'wilayah persekutuan kuala lumpur': 'Kuala Lumpur',
      'kuala lumpur': 'Kuala Lumpur',
      'putrajaya': 'Putrajaya',
      'wilayah persekutuan putrajaya': 'Putrajaya',
      'labuan': 'Labuan',
      'wilayah persekutuan labuan': 'Labuan',
      'selangor': 'Selangor',
      'johor': 'Johor',
      'perak': 'Perak',
      'pahang': 'Pahang',
      'sabah': 'Sabah',
      'sarawak': 'Sarawak',
      'kedah': 'Kedah',
      'terengganu': 'Terengganu',
      'kelantan': 'Kelantan',
      'negeri sembilan': 'Negeri Sembilan',
      'perlis': 'Perlis',
    };
    final components = (place['addressComponents'] as List? ?? [])
        .whereType<Map>();
    if (!components.any(
      (c) =>
          (c['types'] as List? ?? []).contains('country') &&
          c['shortText'] == 'MY',
    )) {
      return null;
    }
    for (final component in components) {
      if ((component['types'] as List? ?? []).contains(
        'administrative_area_level_1',
      )) {
        return aliases[component['longText']
            ?.toString()
            .toLowerCase()
            .replaceFirst(RegExp(r' darul.*$'), '')
            .trim()];
      }
    }
    return null;
  }

  AdminPlacesRepository({this.client});
  final SupabaseClient? client;
  SupabaseClient get _db =>
      client ??
      SupabaseConfig.client ??
      (throw StateError('Database unavailable'));

  Future<AdminPlacesPage> load(String state) async {
    final response = await _db
        .from('places')
        .select()
        .eq('state', state)
        .order('rating', ascending: false)
        .limit(500)
        .count(CountOption.exact);
    return AdminPlacesPage(rows: response.data, totalCount: response.count);
  }

  /// Preserve API values; reject incomplete responses before any database write.
  static Map<String, dynamic> importRow(
    String state,
    Map<String, dynamic> place,
  ) {
    final id = place['place_id'];
    final name = place['name'];
    final lat = place['latitude'];
    final lng = place['longitude'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        name == 'Saved Google place' ||
        name == 'Name unavailable' ||
        lat is! num ||
        lng is! num ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat < 1 ||
        lat > 7.5 ||
        lng < 99 ||
        lng > 120) {
      throw const FormatException(
        'Place is missing a real name or Malaysian coordinates',
      );
    }
    return {
      'place_id': id,
      'name': name,
      'state': state,
      'category': place['category'] ?? 'Category unavailable',
      'latitude': lat,
      'longitude': lng,
      'rating': place['rating'],
      'user_ratings_total': place['user_ratings_total'],
      'operating_hours': place['operating_hours'],
      // Photos are retrieved on demand through the authenticated service.
      'photo_url': null,
      'is_indoor': place['is_indoor'],
    };
  }

  Future<int> savePlaces(
    String state,
    Iterable<Map<String, dynamic>> places, {
    bool updateExisting = false,
  }) async {
    final unique = <String, Map<String, dynamic>>{};
    for (final place in places) {
      final row = importRow(state, place);
      unique[row['place_id'] as String] = row;
    }
    final values = unique.values.toList();
    var inserted = 0;
    for (var start = 0; start < values.length; start += 40) {
      final end = (start + 40).clamp(0, values.length);
      final rows = values.sublist(start, end);
      final added = await _db
          .from('places')
          .upsert(
            rows,
            onConflict: 'place_id',
            ignoreDuplicates: !updateExisting,
          )
          .select('place_id');
      // PostgREST returns only inserted rows when duplicates are ignored.
      inserted += added.length;
    }
    return inserted;
  }
}
