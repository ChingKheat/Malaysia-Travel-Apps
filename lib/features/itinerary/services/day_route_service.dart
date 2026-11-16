import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:smart_travel_planner/features/itinerary/services/scheduling_engine.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_navigation.dart';
import 'package:smart_travel_planner/shared/models/route_info.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';
import 'package:smart_travel_planner/shared/services/google_route_service.dart';

class DayRouteService {
  DayRouteService({GoogleRouteService? routes})
    : _routes = routes ?? GoogleRouteService();

  final GoogleRouteService _routes;
  final _cache = <(String, LatLng, LatLng), (DateTime, Future<RouteInfo?>)>{};

  static bool supports(String mode) =>
      const {'Driving', 'Walking', 'E-hailing'}.contains(mode);

  Future<List<RouteInfo?>> load(List<TravelStop> stops, String mode) =>
      Future.wait([
        for (var i = 1; i < stops.length; i++)
          _leg(stops[i - 1], stops[i], stops[i].inboundMode ?? mode),
      ]);

  Future<RouteInfo?> _leg(TravelStop from, TravelStop to, String mode) async {
    if (!supports(mode) ||
        !TripNavigation.hasCoordinates(from) ||
        !TripNavigation.hasCoordinates(to)) {
      return null;
    }
    final start = LatLng(from.latitude, from.longitude);
    final end = LatLng(to.latitude, to.longitude);
    final key = (mode, start, end);
    final now = DateTime.now();
    _cache.removeWhere((_, entry) => now.difference(entry.$1).inMinutes >= 5);
    final cached = _cache[key];
    if (cached != null) return cached.$2;
    if (_cache.length >= 64) _cache.remove(_cache.keys.first);
    final request = _routes.fetchRoadRoute([
      start,
      end,
    ], mode: mode == 'E-hailing' ? 'Driving' : mode);
    _cache[key] = (now, request);
    final route = await request;
    if (route == null && identical(_cache[key]?.$2, request)) {
      _cache.remove(key);
    }
    return route;
  }
}

class DayRouteTiming {
  DayRouteTiming._(this.departure, this.arrival, this.nextVisit);

  static DayRouteTiming? between(
    TravelStop from,
    TravelStop to,
    RouteInfo route,
  ) {
    try {
      final visit = from.time.split(' - ');
      final start = SchedulingEngine.parseClock(visit.first);
      final next = SchedulingEngine.parseClock(to.time.split(' - ').first);
      if (start >= 1440 || next >= 1440 || from.visitMinutes <= 0) return null;
      final departure = visit.length == 2
          ? SchedulingEngine.parseClock(visit.last)
          : start + from.visitMinutes;
      if (departure <= start) return null;
      return DayRouteTiming._(
        departure,
        departure + route.durationMinutes.ceil(),
        next,
      );
    } on FormatException {
      return null;
    }
  }

  final int departure;
  final int arrival;
  final int nextVisit;

  int get waiting => math.max(0, nextVisit - arrival);
  int get late => math.max(0, arrival - nextVisit);
}
