import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'place_catalog_service.dart';
import 'package:smart_travel_planner/core/config/supabase_config.dart';

/// Loads displayable attraction records directly from the database.
class VerifiedCatalogService extends PlaceCatalogService {
  VerifiedCatalogService({super.client});
  DateTime? savedAt;
  String? loadError;
  bool setupRequired = false;

  static bool usable(Map<String, dynamic> row) =>
      PlaceCatalogService.hasLocationDetails(row);

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
              'place_id,name,state,category,latitude,longitude,rating,user_ratings_total,operating_hours,is_indoor,data_source,photo_url,cover_photo:google_photos->0,catalog_status,catalog_source_url,catalog_license,catalog_verified_at',
            );
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
          .map(PlaceCatalogService.databaseRow)
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
              'rows': [
                for (final row in usableRows)
                  Map.of(row)..remove('cover_photo'),
              ],
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
          ? 'Attraction catalog setup is incomplete. An administrator must finish the database setup.'
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
