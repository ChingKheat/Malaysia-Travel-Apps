import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import '../services/map_bootstrap.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_colors.dart';
import '../core/app_decorations.dart';
import '../models/attraction.dart';
import '../models/route_info.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.attractions,
    required this.selectedStops,
    required this.route,
    required this.onAttractionTap,
    required this.onToggleStop,
    this.center,
  });

  final List<Attraction> attractions;
  final List<Attraction> selectedStops;
  final RouteInfo? route;
  final ValueChanged<Attraction> onAttractionTap;
  final ValueChanged<Attraction> onToggleStop;
  final LatLng? center;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final Future<bool> _ready = ensureGoogleMapReady();
  @override
  Widget build(BuildContext context) {
    final attractions = widget.attractions;
    final selectedStops = widget.selectedStops;
    final route = widget.route;
    final center = widget.center;
    final onAttractionTap = widget.onAttractionTap;
    final onToggleStop = widget.onToggleStop;
    final mapCenter =
        center ??
        (attractions.isNotEmpty
            ? attractions.first.point
            : const LatLng(3.1496, 101.7077));

    return Stack(
      children: [
        FutureBuilder<bool>(
          future: _ready,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data != true) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Google Maps is not configured for this platform yet. Your saved places remain available in the list.',
                  ),
                ),
              );
            }
            return gm.GoogleMap(
              key: ValueKey('${mapCenter.latitude}_${mapCenter.longitude}'),
              initialCameraPosition: gm.CameraPosition(
                target: gm.LatLng(mapCenter.latitude, mapCenter.longitude),
                zoom: 12.2,
              ),
              padding: const EdgeInsets.only(bottom: 100),
              markers: attractions.map((attraction) {
                final selected = selectedStops.any(
                  (s) => s.xid == attraction.xid,
                );
                return gm.Marker(
                  markerId: gm.MarkerId(attraction.xid),
                  position: gm.LatLng(
                    attraction.latitude,
                    attraction.longitude,
                  ),
                  icon: gm.BitmapDescriptor.defaultMarkerWithHue(
                    selected
                        ? gm.BitmapDescriptor.hueViolet
                        : gm.BitmapDescriptor.hueOrange,
                  ),
                  onTap: () => onToggleStop(attraction),
                  infoWindow: gm.InfoWindow(
                    title: attraction.name,
                    snippet: 'View place details',
                    onTap: () => onAttractionTap(attraction),
                  ),
                );
              }).toSet(),
              polylines: {
                if (route != null && route.points.length > 1)
                  gm.Polyline(
                    polylineId: const gm.PolylineId('trip'),
                    points: route.points
                        .map((p) => gm.LatLng(p.latitude, p.longitude))
                        .toList(),
                    color: AppColors.primary,
                    width: 5,
                  ),
              },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
            );
          },
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
                        : '${route.distanceKm.toStringAsFixed(1)} km • ${route.durationMinutes.round()} min${route.isFallback ? ' • distance estimate' : ''}',
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
