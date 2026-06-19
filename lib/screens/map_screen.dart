import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_colors.dart';
import '../core/app_decorations.dart';
import '../models/attraction.dart';
import '../models/route_info.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({
    super.key,
    required this.attractions,
    required this.selectedStops,
    required this.route,
    required this.onAttractionTap,
    required this.onToggleStop,
  });

  final List<Attraction> attractions;
  final List<Attraction> selectedStops;
  final RouteInfo? route;
  final ValueChanged<Attraction> onAttractionTap;
  final ValueChanged<Attraction> onToggleStop;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(3.1496, 101.7077),
            initialZoom: 12.2,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.smart_travel_planner',
            ),
            if (route != null && route!.points.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: route!.points,
                    color: AppColors.primary,
                    strokeWidth: 5,
                  ),
                ],
              ),
            MarkerLayer(
              markers: attractions.map((attraction) {
                final selected = selectedStops.any(
                  (item) => item.xid == attraction.xid,
                );
                return Marker(
                  point: attraction.point,
                  width: 46,
                  height: 46,
                  child: GestureDetector(
                    onTap: () => onAttractionTap(attraction),
                    onLongPress: () => onToggleStop(attraction),
                    child: Icon(
                      selected ? Icons.location_on : Icons.location_on_outlined,
                      color: selected ? AppColors.primary : AppColors.warning,
                      size: selected ? 42 : 36,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: cardDecoration(),
            child: Row(
              children: [
                const Icon(Icons.route, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    route == null
                        ? 'Select 2-5 locations to draw a route'
                        : '${route!.distanceKm.toStringAsFixed(1)} km • ${route!.durationMinutes.round()} min${route!.isFallback ? ' • demo estimate' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
