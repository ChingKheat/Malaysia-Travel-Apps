import 'package:latlong2/latlong.dart';

class RouteInfo {
  const RouteInfo({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    required this.isFallback,
  });

  final List<LatLng> points;
  final double distanceKm;
  final double durationMinutes;
  final bool isFallback;
}
