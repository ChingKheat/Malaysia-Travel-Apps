import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'itinerary_cloud.dart';
import 'package:smart_travel_planner/features/itinerary/models/itinerary_models.dart';
import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'local_itinerary_store.dart';
import 'trip_preferences_service.dart';
import 'smart_itinerary_service.dart';

class ItinerarySaveResult {
  final bool success;
  final bool synced;
  final String message;
  final String? itineraryId;
  const ItinerarySaveResult({
    required this.success,
    required this.message,
    this.itineraryId,
    this.synced = false,
  });
}

/// Local-first repository. Cloud replacement is a single SQL transaction.
class SupabaseItineraryService extends ChangeNotifier {
  static final _instance = SupabaseItineraryService._internal();
  factory SupabaseItineraryService() => _instance;
  SupabaseItineraryService._internal() {
    _lastUserId = AuthService().currentUser?.uid;
    AuthService().addListener(_onAuthChanged);
  }
  @visibleForTesting
  SupabaseItineraryService.withStore(this._store, {ItineraryCloud? cloud})
    : _cloud = cloud ?? SupabaseItineraryCloud();
  LocalItineraryStore _store = LocalItineraryStore();
  ItineraryCloud _cloud = SupabaseItineraryCloud();
  Future<void> _operations = Future.value();
  String? _lastUserId;
  String? lastError;
  String lastOperationMessage = '';
  static const m1SaveSuccess = 'Itinerary saved successfully to your profile!';
  static const m1SaveLocal = 'Saved on this device. Cloud sync is pending.';
  static const m2SaveError =
      'Unable to save itinerary on this device. Please try again.';
  static const m1LoadSuccess = 'Saved itinerary loaded successfully.';
  static const m2NoSavedTrips =
      'You have no saved trips yet. Tap "Plan a Trip" to generate your first itinerary!';
  static const m3LoadError = 'Unable to load saved trips. Please try again.';

  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _operations.then((_) => action());
    _operations = next.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return next;
  }

  bool _hasCloudSession(String uid) =>
      !AuthService().isGuest &&
      _cloud.isAuthenticated(uid) &&
      AuthService().currentUser?.uid == uid;
  void _onAuthChanged() {
    final uid = AuthService().currentUser?.uid;
    if (uid != _lastUserId) {
      TripPreferencesService.clearPreferences();
      SmartItineraryService.clearLiveCache();
      _lastUserId = uid;
    }
    if (uid != null && _hasCloudSession(uid)) unawaited(syncPending());
    notifyListeners();
  }

  Future<ItinerarySaveResult> saveItinerary({
    required String title,
    required String destinationState,
    required double totalCost,
    required List<DailySchedule> dailySchedules,
    bool isPublic = false,
    TripPreferences? preferences,
    String? itineraryId,
  }) => _serial(() async {
    final user = AuthService().currentUser;
    if (user == null) {
      return const ItinerarySaveResult(
        success: false,
        message:
            'Authentication required. Please log in to save your itinerary.',
      );
    }
    try {
      final journal = await _store.read(user.uid);
      final id = itineraryId ?? const Uuid().v4();
      final existing = journal[id] as Map?;
      final old = existing?['trip'] as Map?;
      if (itineraryId != null && old == null) {
        return const ItinerarySaveResult(
          success: false,
          message: 'Saved trip could not be found.',
        );
      }
      final trip = <String, dynamic>{
        'itinerary_id': id,
        'user_id': user.uid,
        'title': title,
        'destination_state': destinationState,
        'total_cost': totalCost,
        'is_public': isPublic,
        'preferences': preferences?.toJson() ?? old?['preferences'] ?? {},
        'created_at': old?['created_at'] ?? DateTime.now().toIso8601String(),
        'daily_schedules': dailySchedules.map((day) {
          final sid = day.scheduleId.isEmpty
              ? const Uuid().v4()
              : day.scheduleId;
          return {
            ...day.toSupabaseMap(),
            'schedule_id': sid,
            'itinerary_id': id,
            'itinerary_stops': day.stops
                .map((stop) => _stopJson(stop, sid))
                .toList(),
          };
        }).toList(),
      };
      journal[id] = {'trip': trip, 'pending': true, 'deleted': false};
      await _store.write(user.uid, journal);
      await _sync(user.uid, journal);
      final synced = (journal[id] as Map)['pending'] != true;
      notifyListeners();
      return ItinerarySaveResult(
        success: true,
        synced: synced,
        message: synced ? m1SaveSuccess : m1SaveLocal,
        itineraryId: id,
      );
    } catch (e) {
      lastError = '$e';
      return const ItinerarySaveResult(success: false, message: m2SaveError);
    }
  });

  static Map<String, dynamic> _stopJson(ItineraryStop stop, String scheduleId) {
    final snapshot = stop.toTravelStop().toJson();
    return {
      ...stop.toSupabaseMap(),
      'id': stop.id.isEmpty ? const Uuid().v4() : stop.id,
      'schedule_id': scheduleId,
      'place_name': snapshot['title'],
      'category': snapshot['category'],
      'latitude': snapshot['latitude'],
      'longitude': snapshot['longitude'],
      'photo_url': (snapshot['photo_urls'] as List).join('|'),
      'arrival_time': _dbTime(stop.arrivalTime),
      'departure_time': _dbTime(stop.departureTime),
      'snapshot': snapshot,
    };
  }

  static Map<String, dynamic> _tripJson(Itinerary trip) => {
    ...trip.toSupabaseMap(),
    'daily_schedules': [
      for (final day in trip.dailySchedules)
        {
          ...day.toSupabaseMap(),
          'itinerary_stops': [
            for (final stop in day.stops) _stopJson(stop, day.scheduleId),
          ],
        },
    ],
  };

  Future<List<Itinerary>> getSavedItineraries({bool refresh = true}) =>
      _serial(() async {
        final uid = AuthService().currentUser?.uid;
        if (uid == null) return [];
        try {
          final journal = await _store.read(uid);
          final trips =
              journal.values
                  .cast<Map>()
                  .where((r) => r['deleted'] != true)
                  .map(
                    (r) => Itinerary.fromSupabase(
                      Map<String, dynamic>.from(r['trip'] as Map),
                    ),
                  )
                  .where((t) => t.userId == uid)
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (refresh && _hasCloudSession(uid)) unawaited(syncPending());
          return trips;
        } catch (e) {
          lastError = '$e';
          return [];
        }
      });

  Future<void> syncPending() => _serial(() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null || !_hasCloudSession(uid)) return;
    try {
      final journal = await _store.read(uid);
      await _sync(uid, journal);
      if (!_hasCloudSession(uid)) return;
      final rows = await _cloud.load(uid);
      final remoteIds = <String>{};
      for (final row in rows) {
        final id = row['itinerary_id'].toString();
        remoteIds.add(id);
        if ((journal[id] as Map?)?['pending'] == true) continue;
        journal[id] = {
          'trip': _tripJson(Itinerary.fromSupabase(row)),
          'pending': false,
          'deleted': false,
        };
      }
      journal.removeWhere(
        (id, record) =>
            (record as Map)['pending'] != true && !remoteIds.contains(id),
      );
      await _store.write(uid, journal);
      notifyListeners();
    } catch (e) {
      lastError = 'Cloud unavailable; local changes retained: $e';
    }
  });

  Future<void> _sync(String uid, Map<String, dynamic> journal) async {
    if (!_hasCloudSession(uid)) return;
    for (final id in journal.keys.toList()) {
      if (!_hasCloudSession(uid)) return;
      final record = Map<String, dynamic>.from(journal[id] as Map);
      if (record['pending'] != true) continue;
      try {
        if (record['deleted'] == true) {
          await _cloud.delete(uid, id);
          journal.remove(id);
        } else {
          await _cloud.save(Map<String, dynamic>.from(record['trip'] as Map));
          record['pending'] = false;
          journal[id] = record;
        }
        await _store.write(uid, journal);
      } catch (e) {
        lastError = 'Cloud sync pending: $e';
        break;
      }
    }
  }

  Future<bool> deleteItinerary(String itineraryId) => _serial(() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return false;
    try {
      final journal = await _store.read(uid);
      final record = journal[itineraryId] as Map?;
      if (record == null || (record['trip'] as Map)['user_id'] != uid) {
        return false;
      }
      journal[itineraryId] = {...record, 'deleted': true, 'pending': true};
      await _store.write(uid, journal);
      await _sync(uid, journal);
      lastOperationMessage = journal.containsKey(itineraryId)
          ? 'Deleted on this device. Cloud sync is pending.'
          : 'Itinerary deleted.';
      notifyListeners();
      return true;
    } catch (e) {
      lastError = '$e';
      return false;
    }
  });

  Future<bool> updateDailyScheduleStops({
    required String scheduleId,
    required double totalDistanceKm,
    required List<ItineraryStop> stops,
  }) => _serial(() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return false;
    try {
      final journal = await _store.read(uid);
      for (final id in journal.keys) {
        final record = Map<String, dynamic>.from(journal[id] as Map);
        if (record['deleted'] == true) continue;
        final trip = Map<String, dynamic>.from(record['trip'] as Map);
        final days = trip['daily_schedules'] as List;
        for (var i = 0; i < days.length; i++) {
          final day = Map<String, dynamic>.from(days[i] as Map);
          if (day['schedule_id'] != scheduleId) continue;
          day['itinerary_stops'] = stops
              .map((s) => _stopJson(s, scheduleId))
              .toList();
          day['total_distance_km'] = totalDistanceKm;
          days[i] = day;
          trip['total_cost'] = days.fold<double>(
            0,
            (sum, d) =>
                sum +
                ((d as Map)['itinerary_stops'] as List).fold<double>(0, (
                  cost,
                  s,
                ) {
                  final snapshot =
                      (s as Map)['snapshot'] as Map? ??
                      (s['stop_data'] as Map?)?['snapshot'] as Map?;
                  return cost +
                      ((snapshot?['estimated_cost'] as num?)?.toDouble() ?? 0) +
                      ((snapshot?['travel_cost'] as num?)?.toDouble() ?? 0);
                }),
          );
          journal[id] = {...record, 'trip': trip, 'pending': true};
          await _store.write(uid, journal);
          await _sync(uid, journal);
          lastOperationMessage = (journal[id] as Map)['pending'] == true
              ? m1SaveLocal
              : 'Itinerary updated and synced.';
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      lastError = '$e';
      return false;
    }
  });

  static String _dbTime(String value) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)?$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) throw FormatException('Invalid schedule time', value);
    var h = int.parse(match[1]!);
    final m = int.parse(match[2]!);
    if (match[3] != null) {
      h %= 12;
      if (match[3]!.toUpperCase() == 'PM') {
        h += 12;
      }
    }
    if (h > 23 || m > 59) throw FormatException('Invalid schedule time', value);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:00';
  }
}
