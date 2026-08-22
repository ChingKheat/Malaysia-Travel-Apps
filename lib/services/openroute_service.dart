import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/api_keys.dart';
import '../models/attraction.dart';
import '../models/route_info.dart';

class OpenRouteService {
  OpenRouteService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<RouteInfo> fetchRoute(List<Attraction> stops) async {
    if (stops.length < 2) {
      return const RouteInfo(
        points: [],
        distanceKm: 0,
        durationMinutes: 0,
        isFallback: true,
      );
    }

    if (!ApiKeys.hasOpenRouteServiceKey) {
      return const RouteInfo(
        points: [],
        distanceKm: 0,
        durationMinutes: 0,
        isFallback: false,
      );
    }

    final uri = Uri.parse(
      'https://api.openrouteservice.org/v2/directions/driving-car/geojson',
    );
    final body = jsonEncode({
      'coordinates': stops
          .map((stop) => [stop.longitude, stop.latitude])
          .toList(),
    });

    final response = await _client
        .post(
          uri,
          headers: {
            'Authorization': ApiKeys.openRouteService,
            'Content-Type': 'application/json',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) return _fallbackRoute(stops);

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final features = decoded['features'] as List<dynamic>? ?? [];
    if (features.isEmpty) return _fallbackRoute(stops);

    final feature = features.first as Map<String, dynamic>;
    final properties = feature['properties'] as Map<String, dynamic>? ?? {};
    final summary = properties['summary'] as Map<String, dynamic>? ?? {};
    final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
    final coordinates = geometry['coordinates'] as List<dynamic>? ?? [];

    final points = coordinates
        .whereType<List<dynamic>>()
        .map(
          (coord) => LatLng(
            (coord[1] as num).toDouble(),
            (coord[0] as num).toDouble(),
          ),
        )
        .toList();

    return RouteInfo(
      points: points,
      distanceKm: ((summary['distance'] as num?)?.toDouble() ?? 0) / 1000,
      durationMinutes: ((summary['duration'] as num?)?.toDouble() ?? 0) / 60,
      isFallback: false,
    );
  }

  RouteInfo _fallbackRoute(List<Attraction> stops) {
    final distance = const Distance();
    var totalKm = 0.0;

    for (var i = 0; i < stops.length - 1; i++) {
      totalKm += distance.as(
        LengthUnit.Kilometer,
        stops[i].point,
        stops[i + 1].point,
      );
    }

    return RouteInfo(
      points: stops.map((stop) => stop.point).toList(),
      distanceKm: totalKm,
      durationMinutes: totalKm / 28 * 60,
      isFallback: true,
    );
  }
}
