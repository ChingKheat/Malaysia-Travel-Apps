import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/image_recognition/services/recognition_history_store.dart';
import 'package:smart_travel_planner/features/image_recognition/services/recognition_clues.dart';
import 'package:smart_travel_planner/features/image_recognition/data/visual_scan_results.dart';
import 'package:smart_travel_planner/features/places/data/curated_attractions.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';

/// Local, account-scoped wishlist for places saved from Scan.
class PlaceWishlistStore {
  PlaceWishlistStore(this.userId);

  final String userId;
  String get _key => 'place_wishlist:$userId';
  String get _migrationKey => 'place_wishlist_migrated:$userId';
  String get _legacyKey => 'visual_scan_saved_spots:$userId';
  String get _notesKey => 'place_wishlist_notes:$userId';

  Future<Map<String, String>> loadNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonDecode(prefs.getString(_notesKey) ?? '{}') as Map;
      return data.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> saveNote(String placeId, String note) async {
    final prefs = await SharedPreferences.getInstance();
    final notes = await loadNotes();
    if (note.trim().isEmpty) {
      notes.remove(placeId);
    } else {
      notes[placeId] = note.trim();
    }
    if (!await prefs.setString(_notesKey, jsonEncode(notes))) {
      throw StateError('Could not save wishlist note');
    }
  }

  Future<List<Attraction>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rows = jsonDecode(prefs.getString(_key) ?? '[]') as List;
      final places = rows.whereType<Map>().map((row) {
        final data = Map<String, dynamic>.from(row);
        return Attraction(
          xid: data['id'] as String,
          name: data['name'] as String,
          latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
          longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
          category: data['category'] as String? ?? '',
          description: data['description'] as String?,
        );
      }).toList();
      if (prefs.getBool(_migrationKey) == true) return places;
      final oldIds = prefs.getStringList(_legacyKey) ?? const <String>[];
      if (oldIds.isEmpty) {
        await prefs.setBool(_migrationKey, true);
        return places;
      }
      final history = await RecognitionHistoryStore(userId: userId).load();
      for (final id in oldIds) {
        if (places.any((place) => place.xid == id)) continue;
        final curated = curatedMalaysianAttractions
            .where((place) => place.xid == id)
            .firstOrNull;
        if (curated != null) {
          places.add(curated);
          continue;
        }
        final entry = history.where((item) {
          final result = item.result;
          return id == 'google_${result.placeId}' ||
              id == 'scan_${scanNameKey(result.name)}' ||
              scanLandmarkByName(result.name)?.xid == id;
        }).firstOrNull;
        if (entry != null) {
          final result = entry.result;
          final known = scanLandmarkByName(result.name);
          places.add(
            Attraction(
              xid: id,
              name: result.name,
              latitude: known?.latitude ?? 0,
              longitude: known?.longitude ?? 0,
              category: known?.category ?? 'Landmark',
              description: result.description,
            ),
          );
        } else {
          places.add(
            Attraction(
              xid: id,
              name: 'Saved place',
              latitude: 0,
              longitude: 0,
              category: 'Place',
            ),
          );
        }
      }
      await _write(prefs, places);
      await prefs.setBool(_migrationKey, true);
      return places;
    } catch (_) {
      return [];
    }
  }

  Future<List<Attraction>> toggle(Attraction place) async {
    final places = await load();
    if (places.any((item) => item.xid == place.xid)) {
      places.removeWhere((item) => item.xid == place.xid);
      await saveNote(place.xid, '');
    } else {
      places.add(place);
    }
    final prefs = await SharedPreferences.getInstance();
    await _write(prefs, places);
    return places;
  }

  Future<bool> add(Attraction place) async {
    final places = await load();
    if (places.any(
      (item) =>
          item.xid == place.xid ||
          (item.name.isNotEmpty &&
              item.name.trim().toLowerCase() == place.name.trim().toLowerCase()),
    )) {
      return false;
    }
    places.add(place);
    final prefs = await SharedPreferences.getInstance();
    await _write(prefs, places);
    return true;
  }

  Future<bool> remove(String id) async {
    final places = await load();
    final before = places.length;
    places.removeWhere((item) => item.xid == id);
    if (places.length == before) return false;
    final prefs = await SharedPreferences.getInstance();
    await _write(prefs, places);
    return true;
  }

  Future<void> updatePlace(Attraction place) async {
    final places = await load();
    final index = places.indexWhere((item) => item.xid == place.xid);
    if (index < 0) return;
    places[index] = place;
    final prefs = await SharedPreferences.getInstance();
    await _write(prefs, places);
  }

  Future<void> _write(SharedPreferences prefs, List<Attraction> places) async {
    final saved = await prefs.setString(
      _key,
      jsonEncode([
        for (final item in places)
          {
            'id': item.xid,
            'name': item.name,
            'latitude': item.latitude,
            'longitude': item.longitude,
            'category': item.category,
            'description': item.description,
          },
      ]),
    );
    if (!saved) throw StateError('Could not save wishlist');
  }
}
