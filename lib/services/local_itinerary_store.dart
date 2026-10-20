import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Account-scoped journal, including pending writes and deletion tombstones.
class LocalItineraryStore {
  Future<Map<String, dynamic>> read(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('itinerary_journal_v1_$userId');
    if (raw == null) return {};
    // Do not silently overwrite unreadable data with an empty journal.
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> write(String userId, Map<String, dynamic> journal) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      'itinerary_journal_v1_$userId',
      jsonEncode(journal),
    )) {
      throw StateError('Unable to persist itinerary on this device');
    }
  }
}
