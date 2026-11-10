import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_travel_planner/core/config/supabase_config.dart';
import 'package:smart_travel_planner/features/places/services/place_catalog_service.dart';

class AdminPlacesPage {
  const AdminPlacesPage({required this.rows, required this.totalCount});
  final List<Map<String, dynamic>> rows;
  final int totalCount;
}

/// Database-only operations; these never request Google data.
class AdminPlacesRepository {
  static const supportedStates = [
    'Penang',
    'Kuala Lumpur',
    'Melaka',
    'Selangor',
    'Johor',
    'Perak',
    'Pahang',
    'Sabah',
    'Sarawak',
    'Kedah',
    'Terengganu',
    'Kelantan',
    'Negeri Sembilan',
    'Perlis',
    'Putrajaya',
    'Labuan',
  ];
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
      'federal territory of putrajaya': 'Putrajaya',
      'wilayah persekutuan putrajaya': 'Putrajaya',
      'labuan': 'Labuan',
      'federal territory of labuan': 'Labuan',
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

  Future<AdminPlacesPage> load(String state, {int offset = 0}) async {
    final response = await _db
        .from('places')
        .select()
        .eq('state', state)
        .order('place_id')
        .range(offset, offset + 19)
        .count(CountOption.exact);
    return AdminPlacesPage(rows: response.data, totalCount: response.count);
  }

  /// Validate live discovery, then keep only the ID and app-owned grouping.
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
      'data_source': 'google',
      'name': 'Saved Google place',
      'state': state,
      'category':
          PlaceCatalogService.appCategories.contains(place['app_category'])
          ? place['app_category']
          : 'Attraction',
      'latitude': 0.0,
      'longitude': 0.0,
      'rating': null,
      'user_ratings_total': null,
      'operating_hours': null,
      // Photos are retrieved on demand through the authenticated service.
      'photo_url': null,
    };
  }

  Future<int> savePlaces(
    String state,
    Iterable<Map<String, dynamic>> places,
  ) async {
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
      try {
        final added = await _db
            .from('places')
            .upsert(rows, onConflict: 'place_id', ignoreDuplicates: true)
            .select('place_id');
        // PostgREST returns only inserted rows when duplicates are ignored.
        inserted += added.length;
      } catch (_) {
        throw StateError(
          'Import interrupted: $inserted inserts confirmed; ${values.length - start} records unconfirmed. Earlier batches remain saved. Retry safely; existing IDs are preserved.',
        );
      }
    }
    return inserted;
  }

  Future<void> saveReview(
    Map<String, dynamic> original,
    String category,
    bool? indoor,
  ) async {
    if (!PlaceCatalogService.appCategories.contains(category)) {
      throw const FormatException('Invalid app category');
    }
    var query = _db
        .from('places')
        .update({'category': category, 'is_indoor': indoor})
        .eq('place_id', original['place_id'])
        .eq('state', original['state'])
        .eq('category', original['category']);
    query = original['is_indoor'] == null
        ? query.isFilter('is_indoor', null)
        : query.eq('is_indoor', original['is_indoor']);
    final rows = await query.select('place_id');
    if (rows.length != 1) {
      throw StateError(
        'Record changed or permission denied. Refresh before reviewing again.',
      );
    }
  }
}
