import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_travel_planner/core/config/supabase_config.dart';

/// Persistent app data and Google references only. Loading never calls Google.
class PlaceCatalogService {
  PlaceCatalogService({this.client});
  final SupabaseClient? client;
  bool lastLoadOffline = false;
  static final mealPattern = RegExp(
    r'restaurant|food|cafe|coffee|bakery|dining|hawker|eatery',
    caseSensitive: false,
  );
  Future<List<Map<String, dynamic>>> load({String? state}) async {
    lastLoadOffline = false;
    final key =
        'place_catalog_v2:${SupabaseConfig.supabaseUrl}:${state ?? 'all'}';
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final oldPrefix = 'place_catalog_v1:${SupabaseConfig.supabaseUrl}:';
      for (final oldKey
          in prefs.getKeys().where((k) => k.startsWith(oldPrefix)).toList()) {
        try {
          final old = (jsonDecode(prefs.getString(oldKey) ?? '[]') as List)
              .whereType<Map>()
              .map((r) => persistentRow(Map<String, dynamic>.from(r)))
              .toList();
          await prefs.setString(
            oldKey.replaceFirst('place_catalog_v1:', 'place_catalog_v2:'),
            jsonEncode(old),
          );
        } catch (_) {
          /* A corrupt legacy cache must not retain provider data. */
        }
        await prefs.remove(oldKey);
      }
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
              'place_id,name,state,category,latitude,longitude,rating,user_ratings_total,operating_hours,is_indoor,data_source',
            );
        if (state != null) query = query.eq('state', state);
        final page = await query
            .order('place_id')
            .range(offset, offset + 999)
            .timeout(const Duration(seconds: 8));
        rows.addAll(page);
        if (page.length < 1000) break;
      }
      final usable = rows.map(persistentRow).where(valid).toList();
      try {
        await prefs?.setString(key, jsonEncode(usable));
      } catch (_) {}
      return usable;
    } catch (_) {
      lastLoadOffline = true;
      try {
        final value = prefs?.getString(key);
        final all = prefs?.getString(
          'place_catalog_v2:${SupabaseConfig.supabaseUrl}:all',
        );
        // A saved itinerary may reopen offline after only its state's catalog
        // was loaded. Reuse those state copies when no all-states copy exists.
        final combined = <String, dynamic>{};
        if (value == null && all == null && prefs != null) {
          final prefix = 'place_catalog_v2:${SupabaseConfig.supabaseUrl}:';
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
            .map(persistentRow)
            .where((r) => valid(r) && (state == null || r['state'] == state))
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  static bool valid(Map<String, dynamic> row) {
    if (isGoogleReference(row)) {
      return row['place_id'] is String &&
          (row['place_id'] as String).isNotEmpty &&
          row['state'] is String;
    }
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

  static bool isGoogleReference(Map<String, dynamic> row) =>
      row['data_source'] == 'google' ||
      (row['place_id']?.toString().startsWith('ChI') ?? false) ||
      row['name'] == 'Saved Google place';

  static const appCategories = [
    'Attraction',
    'Culture',
    'Food',
    'Nature',
    'Shopping',
    'History',
    'Adventure',
    'Family',
    'Nightlife',
  ];

  static Map<String, dynamic> persistentRow(Map<String, dynamic> row) {
    if (!isGoogleReference(row)) return {...row}..remove('photo_url');
    return {
      'place_id': row['place_id'],
      'state': row['state'],
      'data_source': 'google',
      'name': 'Saved Google place',
      'category': appCategories.contains(row['category'])
          ? row['category']
          : 'Attraction',
      'latitude': 0.0,
      'longitude': 0.0,
      'is_indoor': row['is_indoor'],
      'rating': null,
      'user_ratings_total': null,
      'operating_hours': null,
    };
  }

  static bool isMeal(Map<String, dynamic> row) =>
      mealPattern.hasMatch('${row['category']}');
  static Map<String, dynamic> asGoogleShape(Map<String, dynamic> row) => {
    '_data_source': isGoogleReference(row) ? 'google' : 'local',
    'id': row['place_id'],
    'displayName': {'text': row['name']},
    'primaryTypeDisplayName': {'text': row['category']},
    'location': {'latitude': row['latitude'], 'longitude': row['longitude']},
    'rating': row['rating'],
    'userRatingCount': row['user_ratings_total'],
    'regularOpeningHours': row['operating_hours'] ?? <String, dynamic>{},
    'attributions': row['attributions'] ?? const [],
    'is_indoor': row['is_indoor'],
    'photo_url': row['photo_url'],
  };
}
