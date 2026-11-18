import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';

/// Account-scoped places selected from Scan for the next generated plan.
class ScanPlanPlacesStore extends ChangeNotifier {
  ScanPlanPlacesStore._(this.userId);

  static final Map<String, ScanPlanPlacesStore> _instances = {};

  static void resetForTesting() {
    _instances.clear();
  }

  factory ScanPlanPlacesStore(String userId) =>
      _instances.putIfAbsent(userId, () => ScanPlanPlacesStore._(userId));

  final String userId;
  final List<Attraction> _places = [];
  Future<void>? _loading;

  List<Attraction> get places => List.unmodifiable(_places);
  String get _key => 'scan_plan_places:$userId';

  Future<void> load() => _loading ??= _read();

  Future<void> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rows = jsonDecode(prefs.getString(_key) ?? '[]') as List;
      _places
        ..clear()
        ..addAll(
          rows.whereType<Map>().map((row) {
            final data = Map<String, dynamic>.from(row);
            return Attraction(
              xid: data['id'] as String,
              name: data['name'] as String,
              latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
              longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
              category: data['category'] as String? ?? 'Attraction',
              description: data['description'] as String?,
            );
          }),
        );
      notifyListeners();
    } catch (_) {
      // Keep the in-memory selection usable if local storage is unavailable.
    }
  }

  Future<bool> add(Attraction place) async {
    await load();
    if (_places.any(
      (item) =>
          item.xid == place.xid ||
          item.name.trim().toLowerCase() == place.name.trim().toLowerCase(),
    )) {
      return false;
    }
    _places.add(place);
    notifyListeners();
    await _write();
    return true;
  }

  Future<void> remove(String id) async {
    await load();
    _places.removeWhere((place) => place.xid == id);
    notifyListeners();
    await _write();
  }

  Future<void> clear() async {
    _places.clear();
    notifyListeners();
    await _write();
  }

  Future<void> _write() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode([
          for (final place in _places)
            {
              'id': place.xid,
              'name': place.name,
              'latitude': place.latitude,
              'longitude': place.longitude,
              'category': place.category,
              'description': place.description,
            },
        ]),
      );
    } catch (_) {
      // The current selection remains visible for this session.
    }
  }
}
