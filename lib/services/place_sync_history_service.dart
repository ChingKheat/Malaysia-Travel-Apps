import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/supabase_config.dart';
import '../models/place_sync_record.dart';

abstract class PlaceSyncHistoryCloud {
  Future<PlaceSyncRecord?> load(String state);
  Future<PlaceSyncRecord> record(
    String state,
    int placeCount,
    int requestCount,
  );
}

class SupabasePlaceSyncHistoryCloud implements PlaceSyncHistoryCloud {
  @override
  Future<PlaceSyncRecord?> load(String state) async {
    final client = SupabaseConfig.client;
    if (client == null) throw StateError('Cloud unavailable');
    final row = await client
        .from('place_sync_status')
        .select()
        .eq('state', state)
        .maybeSingle();
    return row == null ? null : PlaceSyncRecord.fromJson(row);
  }

  @override
  Future<PlaceSyncRecord> record(
    String state,
    int placeCount,
    int requestCount,
  ) async {
    final client = SupabaseConfig.client;
    if (client == null) throw StateError('Cloud unavailable');
    final row = await client
        .rpc(
          'record_place_sync',
          params: {
            'p_state': state,
            'p_place_count': placeCount,
            'p_request_count': requestCount,
          },
        )
        .single();
    return PlaceSyncRecord.fromJson(Map<String, dynamic>.from(row));
  }
}

/// Only import metadata is cached here. Loading this service never calls Google.
class PlaceSyncHistoryService {
  PlaceSyncHistoryService({
    PlaceSyncHistoryCloud? cloud,
    DateTime Function()? now,
  }) : _cloud = cloud ?? SupabasePlaceSyncHistoryCloud(),
       _now = now ?? DateTime.now;
  final PlaceSyncHistoryCloud _cloud;
  final DateTime Function() _now;
  bool lastReadOffline = false;
  String? lastError;
  String _key(String state) =>
      'place_sync_v1:${SupabaseConfig.supabaseUrl}:$state';

  Future<PlaceSyncRecord?> _cached(String state) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        _key(state),
      );
      return raw == null
          ? null
          : PlaceSyncRecord.fromJson(
              Map<String, dynamic>.from(jsonDecode(raw) as Map),
            );
    } catch (_) {
      return null;
    }
  }

  Future<void> _cache(PlaceSyncRecord record) async {
    try {
      if (!await (await SharedPreferences.getInstance()).setString(
        _key(record.state),
        jsonEncode(record.toJson()),
      )) {
        lastError = 'Unable to save sync history on this device.';
      }
    } catch (_) {
      lastError = 'Unable to save sync history on this device.';
    }
  }

  Future<PlaceSyncRecord?> load(String state) async {
    final cached = await _cached(state);
    lastError = null;
    try {
      final remote = await _cloud
          .load(state)
          .timeout(const Duration(seconds: 8));
      lastReadOffline = false;
      // A completed import whose metadata upload failed is still useful locally.
      if (cached?.localOnly == true &&
          (remote == null ||
              cached!.lastSyncedAt.isAfter(remote.lastSyncedAt))) {
        return cached;
      }
      if (remote != null) {
        await _cache(remote);
      } else {
        try {
          await (await SharedPreferences.getInstance()).remove(_key(state));
        } catch (_) {}
      }
      return remote;
    } catch (_) {
      lastReadOffline = true;
      lastError = 'Cloud sync history unavailable.';
      return cached;
    }
  }

  /// Call only after every search and database batch in the import succeeded.
  Future<PlaceSyncRecord> recordSuccess({
    required String state,
    required int placeCount,
    required int requestCount,
  }) async {
    lastError = null;
    final completedAt = _now().toUtc();
    PlaceSyncRecord record;
    try {
      record = await _cloud
          .record(state, placeCount, requestCount)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      lastError = 'Sync completed; its timestamp is saved on this device only.';
      record = PlaceSyncRecord(
        state: state,
        lastSyncedAt: completedAt,
        placeCount: placeCount,
        requestCount: requestCount,
        localOnly: true,
      );
    }
    await _cache(record);
    return record;
  }
}
