import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'place_catalog_service.dart';
import 'package:smart_travel_planner/core/config/supabase_config.dart';

/// Browse only reviewed, independently licensed records. Google references stay
/// in the existing catalog for explicit on-demand provider operations.
class VerifiedCatalogService extends PlaceCatalogService {
  VerifiedCatalogService({super.client});
  DateTime? savedAt;
  String? loadError;
  bool setupRequired = false;

  static bool usable(Map<String, dynamic> row) =>
      !PlaceCatalogService.isGoogleReference(row) &&
      PlaceCatalogService.valid(row) &&
      (row['name'] as String).trim().isNotEmpty &&
      (row['category']?.toString().trim().isNotEmpty ?? false) &&
      row['catalog_status'] == 'published' &&
      Uri.tryParse(row['catalog_source_url']?.toString() ?? '')?.scheme ==
          'https' &&
      (row['catalog_license']?.toString().trim().isNotEmpty ?? false) &&
      DateTime.tryParse(row['catalog_verified_at']?.toString() ?? '') != null;

  @override
  Future<List<Map<String, dynamic>>> load({String? state}) async {
    lastLoadOffline = false;
    loadError = null;
    setupRequired = false;
    final key =
        'verified_catalog_v1:${SupabaseConfig.supabaseUrl}:${state ?? 'all'}';
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    try {
      final db = client ?? SupabaseConfig.client;
      if (db == null) throw StateError('Catalog connection unavailable');
      final rows = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += 1000) {
        var query = db
            .from('places')
            .select(
              'place_id,name,state,category,latitude,longitude,rating,user_ratings_total,operating_hours,is_indoor,data_source,photo_url,catalog_status,catalog_source_url,catalog_license,catalog_verified_at',
            )
            .eq('catalog_status', 'published')
            .neq('data_source', 'google');
        if (state != null) query = query.eq('state', state);
        final page = await query
            .order('place_id')
            .range(offset, offset + 999)
            .timeout(const Duration(seconds: 8));
        rows.addAll(page);
        if (page.length < 1000) break;
      }
      final usableRows = rows
          .where(usable)
          .map(PlaceCatalogService.persistentRow)
          .toList();
      savedAt = DateTime.now().toUtc();
      // Keep the last nonempty snapshot for connection failures, not for a
      // successful empty query (which can represent publication withdrawal).
      if (usableRows.isNotEmpty) {
        try {
          await prefs?.setString(
            key,
            jsonEncode({
              'saved_at': savedAt!.toIso8601String(),
              'rows': usableRows,
            }),
          );
        } catch (_) {
          /* A local write failure does not hide valid remote data. */
        }
      }
      return usableRows;
    } catch (error) {
      lastLoadOffline = true;
      setupRequired =
          error is PostgrestException &&
          ['42703', '42P01', 'PGRST204', 'PGRST205'].contains(error.code);
      loadError = setupRequired
          ? 'Attraction catalog setup is incomplete. An administrator must finish the database setup and publish reviewed attraction records.'
          : error is PostgrestException
          ? 'The attraction catalog could not be loaded from the server. Please try again or contact an administrator.'
          : 'Connection unavailable. Saved attraction information will be shown when available.';
      try {
        final cached = jsonDecode(prefs?.getString(key) ?? '{}') as Map;
        savedAt = DateTime.tryParse(cached['saved_at']?.toString() ?? '');
        return (cached['rows'] as List? ?? [])
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .where(usable)
            .toList();
      } catch (_) {
        return [];
      }
    }
  }
}
