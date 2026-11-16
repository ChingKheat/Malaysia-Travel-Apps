import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Account-scoped journal, including pending writes and deletion tombstones.
class LocalItineraryStore {
  Future<Map<String, dynamic>> read(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('itinerary_journal_v1_$userId');
    if (raw == null) return {};
    // Do not silently overwrite unreadable data with an empty journal.
    final cleaned = _sanitize(jsonDecode(raw)) as Map<String, dynamic>;
    final encoded = jsonEncode(cleaned);
    if (encoded != raw) {
      await prefs.setString('itinerary_journal_v1_$userId', encoded);
    }
    return cleaned;
  }

  Future<void> write(String userId, Map<String, dynamic> journal) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      'itinerary_journal_v1_$userId',
      jsonEncode(_sanitize(journal)),
    )) {
      throw StateError('Unable to persist itinerary on this device');
    }
  }

  static const _ownStopKeys = {
    'place_id',
    'id',
    'schedule_id',
    'stop_order',
    'arrival_time',
    'departure_time',
    'is_visited',
    'place_state',
    'time',
    'duration',
    'estimated_cost',
    'visit_minutes',
    'is_indoor',
    'travel_minutes',
    'inbound_mode',
    'travel_cost',
    'travel_is_estimated',
    'data_source',
    'snapshot',
    'stop_data',
    'user_note',
    'title',
    'place_name',
  };

  static dynamic _sanitize(dynamic value) {
    if (value is List) return value.map(_sanitize).toList();
    if (value is! Map) return value;
    final map = Map<String, dynamic>.from(value);
    final nested = map['stop_data'];
    final snapshot =
        map['snapshot'] ?? (nested is Map ? nested['snapshot'] : null);
    final google =
        map['data_source'] == 'google' ||
        (snapshot is Map && snapshot['data_source'] == 'google') ||
        (map['place_id']?.toString().startsWith('ChI') ?? false);
    return <String, dynamic>{
      for (final entry in map.entries)
        // The user-facing place name is stable itinerary data. Keep it in
        // local snapshots while continuing to discard provider metadata.
        if (!google || _ownStopKeys.contains(entry.key) || entry.key == 'title')
          entry.key: _sanitize(entry.value),
      if (google) ...{
        'data_source': 'google',
        if (map['title'] == null || map['title'] == 'Saved Google place')
          'title': map['place_name'] ?? map['title'] ?? 'Saved Google place',
        if (map['place_name'] == null) 'place_name': 'Saved Google place',
        'category': 'Attraction',
        'latitude': 0.0,
        'longitude': 0.0,
        'description': 'Place details require an internet connection.',
        'opening_hours': 'Hours unverified',
        'operating_hours': <String, dynamic>{},
        'photo_urls': <String>[],
        'photo_url': null,
        'tips': <String>[],
      },
    };
  }
}
