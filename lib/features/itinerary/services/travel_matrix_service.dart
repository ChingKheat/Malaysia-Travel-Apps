import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';
import 'scheduling_engine.dart';

class TravelMatrixService {
  TravelMatrixService({
    http.Client? client,
    String? accessToken,
    GooglePlacesService? service,
  }) : _service =
           service ??
           GooglePlacesService(client: client, accessToken: accessToken);
  final GooglePlacesService _service;
  static final _cache =
      <String, ({DateTime at, Map<String, TravelLeg> legs})>{};

  /// Looks up pairs among the first ten points (up to 100 elements).
  /// The scheduler falls back to planning estimates for missing legs.
  Future<Map<String, TravelLeg>> fetch(
    List<TravelStop> stops,
    String mode, {
    DateTime? departureTime,
  }) async {
    if (stops.length < 2 ||
        (mode == 'Public Transport' && departureTime == null)) {
      return {};
    }
    final pool = stops.take(10).toList();
    final key =
        '$mode:${departureTime?.toIso8601String()}:${pool.map((s) => '${SchedulingEngine.identity(s)}:${s.latitude}:${s.longitude}').join('|')}';
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.at) < const Duration(minutes: 10)) {
      return cached.legs;
    }
    try {
      final response = await _service.requestOperation({
        'operation': 'matrix',
        'mode': mode,
        if (departureTime != null)
          'departureTime': departureTime.toUtc().toIso8601String(),
        'points': pool
            .map((s) => {'latitude': s.latitude, 'longitude': s.longitude})
            .toList(),
      });
      if (response?.statusCode != 200) return {};
      final result = <String, TravelLeg>{};
      for (final row in jsonDecode(response!.body) as List) {
        final from = (row['originIndex'] as num?)?.toInt() ?? 0;
        final to = (row['destinationIndex'] as num?)?.toInt() ?? 0;
        if (from < 0 || to < 0 || from >= pool.length || to >= pool.length) {
          continue;
        }
        final key =
            '${SchedulingEngine.identity(pool[from])}>${SchedulingEngine.identity(pool[to])}';
        if (row['condition'] == 'ROUTE_NOT_FOUND' &&
            mode == 'Public Transport') {
          continue;
        }
        if (row['condition'] == 'ROUTE_NOT_FOUND') {
          result[key] = const TravelLeg(1 << 30, 0, estimated: false);
          continue;
        }
        if (row['condition'] != 'ROUTE_EXISTS' ||
            ((row['status'] as Map?)?['code'] ?? 0) != 0) {
          continue;
        }
        final seconds = double.tryParse(
          row['duration']?.toString().replaceAll('s', '') ?? '',
        );
        if (seconds == null) continue;
        result[key] = TravelLeg(
          (seconds / 60).ceil(),
          ((row['distanceMeters'] as num?)?.toDouble() ?? 0) / 1000,
          estimated: mode == 'Public Transport',
        );
      }
      if (result.isNotEmpty) {
        if (_cache.length > 20) _cache.clear();
        _cache[key] = (at: DateTime.now(), legs: result);
      }
      return result;
    } catch (_) {
      return {};
    }
  }
}
