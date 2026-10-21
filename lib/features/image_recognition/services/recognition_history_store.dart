import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:smart_travel_planner/features/image_recognition/models/recognition_result.dart';

/// Stores result text only, scoped to the current account. Photos are not saved.
class RecognitionHistoryStore {
  RecognitionHistoryStore({required String userId})
    : _key = 'recognition_history_v1:$userId';

  final String _key;
  List<RecognitionResult> _memory = [];
  static const maxEntries = 30;

  Future<List<RecognitionResult>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(prefs.getString(_key) ?? '[]') as List;
      final items = <RecognitionResult>[];
      for (final value in saved.take(maxEntries)) {
        try {
          items.add(RecognitionResult.fromJson(Map<String, dynamic>.from(value)));
        } catch (_) {
          // One corrupt entry must not hide the remaining local history.
        }
      }
      _memory = items;
    } catch (_) {
      // Keep session history usable if persistent storage is unavailable.
    }
    return List.unmodifiable(_memory);
  }

  /// Returns whether the result was persisted beyond this app session.
  Future<bool> save(List<RecognitionResult> entries) async {
    _memory = entries.take(maxEntries).toList();
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(
        _key,
        jsonEncode(_memory.map((item) => item.toJson()).toList()),
      );
    } catch (_) {
      return false;
    }
  }
}
