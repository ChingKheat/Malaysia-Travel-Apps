import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';
import 'package:smart_travel_planner/shared/models/route_info.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';

class GoogleRouteService {
  GoogleRouteService({GooglePlacesService? service})
    : _service = service ?? GooglePlacesService();
  final GooglePlacesService _service;
  String? lastError;
  Future<RouteInfo> fetchRoute(List<Attraction> stops) async {
    if (stops.length < 2) return estimate(stops);
    try {
      final selected = stops.take(5).toList();
      final response = await _service.requestOperation({
        'operation': 'route',
        'mode': 'Driving',
        'points': selected
            .map((s) => {'latitude': s.latitude, 'longitude': s.longitude})
            .toList(),
      });
      if (response?.statusCode != 200) throw StateError('Routes unavailable');
      final routes =
          (jsonDecode(response!.body) as Map)['routes'] as List? ?? [];
      if (routes.isEmpty) throw StateError('No route');
      final route = routes.first as Map;
      final points = decodePolyline(
        (route['polyline'] as Map?)?['encodedPolyline'] as String? ?? '',
      );
      final seconds = double.tryParse(
        '${route['duration']}'.replaceAll('s', ''),
      );
      if (points.length < 2 ||
          seconds == null ||
          route['distanceMeters'] is! num) {
        throw StateError('Invalid route');
      }
      lastError = null;
      return RouteInfo(
        points: points,
        distanceKm: (route['distanceMeters'] as num) / 1000,
        durationMinutes: seconds / 60,
        isFallback: false,
      );
    } catch (_) {
      lastError = 'Google route unavailable. Showing a distance estimate.';
      return estimate(stops);
    }
  }

  RouteInfo estimate(List<Attraction> stops) {
    var km = 0.0;
    for (var i = 1; i < stops.length; i++) {
      km += const Distance().as(
        LengthUnit.Kilometer,
        stops[i - 1].point,
        stops[i].point,
      );
    }
    return RouteInfo(
      points: stops.map((s) => s.point).toList(),
      distanceKm: km,
      durationMinutes: km / 28 * 60,
      isFallback: true,
    );
  }

  static List<LatLng> decodePolyline(String value) {
    var index = 0, lat = 0, lng = 0;
    int component() {
      var result = 0, shift = 0;
      while (true) {
        if (index >= value.length || shift > 30) {
          throw const FormatException('Invalid polyline');
        }
        final byte = value.codeUnitAt(index++) - 63;
        if (byte < 0 || byte > 63) {
          throw const FormatException('Invalid polyline');
        }
        result |= (byte & 31) << shift;
        if (byte < 32) return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
        shift += 5;
      }
    }

    final points = <LatLng>[];
    while (index < value.length) {
      lat += component();
      lng += component();
      if (lat.abs() > 9000000 || lng.abs() > 18000000) {
        throw const FormatException('Invalid coordinates');
      }
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
