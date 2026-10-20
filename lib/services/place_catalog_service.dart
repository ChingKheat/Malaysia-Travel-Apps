import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';

/// Admin-synced catalog. Neither loading nor searching calls Google.
class PlaceCatalogService {
  PlaceCatalogService({this.client});
  final SupabaseClient? client;
  static final mealPattern = RegExp(
    r'restaurant|food|cafe|coffee|bakery|dining|hawker|eatery',
    caseSensitive: false,
  );
  Future<List<Map<String, dynamic>>> load({String? state}) async {
    final key =
        'place_catalog_v1:${SupabaseConfig.supabaseUrl}:${state ?? 'all'}';
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    try {
      final db = client ?? SupabaseConfig.client;
      if (db == null) throw StateError('Offline');
      final rows = <Map<String, dynamic>>[];
      for (
        var offset = 0;
        offset < (state == null ? 20000 : 5000);
        offset += 1000
      ) {
        var query = db
            .from('places')
            .select(
              'place_id,name,state,category,latitude,longitude,rating,user_ratings_total,operating_hours,is_indoor',
            );
        if (state != null) query = query.eq('state', state);
        final page = await query
            .order('place_id')
            .range(offset, offset + 999)
            .timeout(const Duration(seconds: 8));
        rows.addAll(page);
        if (page.length < 1000) break;
      }
      final usable = rows.where(valid).toList();
      try {
        await prefs?.setString(key, jsonEncode(usable));
      } catch (_) {}
      return usable;
    } catch (_) {
      try {
        final value = prefs?.getString(key);
        final all = prefs?.getString(
          'place_catalog_v1:${SupabaseConfig.supabaseUrl}:all',
        );
        // A saved itinerary may reopen offline after only its state's catalog
        // was loaded. Reuse those state copies when no all-states copy exists.
        final combined = <String, dynamic>{};
        if (value == null && all == null && prefs != null) {
          final prefix = 'place_catalog_v1:${SupabaseConfig.supabaseUrl}:';
          for (final savedKey in prefs.getKeys().where(
            (k) => k.startsWith(prefix),
          )) {
            try {
              for (final row
                  in jsonDecode(prefs.getString(savedKey) ?? '[]') as List) {
                if (row is Map && row['place_id'] is String) {
                  combined[row['place_id'] as String] = row;
                }
              }
            } catch (_) {
              /* A corrupt state's cache does not hide other states. */
            }
          }
        }
        final saved = value != null || all != null
            ? jsonDecode(value ?? all!) as List
            : combined.values.toList();
        return saved
            .whereType<Map>()
            .map((p) => Map<String, dynamic>.from(p))
            .where((r) => valid(r) && (state == null || r['state'] == state))
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  static bool valid(Map<String, dynamic> row) {
    final lat = row['latitude'], lng = row['longitude'];
    return row['place_id'] is String &&
        row['name'] is String &&
        row['name'] != 'Saved Google place' &&
        lat is num &&
        lng is num &&
        lat.isFinite &&
        lng.isFinite &&
        lat >= 1 &&
        lat <= 7.5 &&
        lng >= 99 &&
        lng <= 120;
  }

  static bool isMeal(Map<String, dynamic> row) =>
      mealPattern.hasMatch('${row['category']}');
  static Map<String, dynamic> asGoogleShape(Map<String, dynamic> row) => {
    'id': row['place_id'],
    'displayName': {'text': row['name']},
    'primaryTypeDisplayName': {'text': row['category']},
    'location': {'latitude': row['latitude'], 'longitude': row['longitude']},
    'rating': row['rating'],
    'userRatingCount': row['user_ratings_total'],
    'regularOpeningHours': row['operating_hours'] ?? <String, dynamic>{},
    'is_indoor': row['is_indoor'],
    'photo_url': row['photo_url'],
  };
}
