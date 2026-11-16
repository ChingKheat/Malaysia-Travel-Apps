import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/core/theme/app_decorations.dart';
import 'package:smart_travel_planner/features/itinerary/services/day_route_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_navigation.dart';
import 'package:smart_travel_planner/shared/models/route_info.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';
import 'package:smart_travel_planner/shared/services/map_bootstrap.dart';

class DayRouteMap extends StatefulWidget {
  const DayRouteMap({
    super.key,
    required this.stops,
    required this.mode,
    required this.service,
  });

  final List<TravelStop> stops;
  final String mode;
  final DayRouteService service;

  @override
  State<DayRouteMap> createState() => _DayRouteMapState();
}

class _DayRouteMapState extends State<DayRouteMap> {
  late Future<List<RouteInfo?>> _routes = _load();

  Future<List<RouteInfo?>> _load() =>
      widget.service.load(widget.stops, widget.mode);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(12),
      child: Material(
        type: MaterialType.transparency,
        child: _RouteView(
          stops: widget.stops,
          mode: widget.mode,
          routes: _routes,
          onRetry: () {
            setState(() => _routes = _load());
            return _routes;
          },
        ),
      ),
    );
  }
}

class _RouteView extends StatefulWidget {
  const _RouteView({
    required this.stops,
    required this.mode,
    required this.routes,
    required this.onRetry,
    this.fullscreen = false,
    this.initialLeg,
    this.initialStop,
  });

  final List<TravelStop> stops;
  final String mode;
  final Future<List<RouteInfo?>> routes;
  final Future<List<RouteInfo?>> Function() onRetry;
  final bool fullscreen;
  final int? initialLeg;
  final int? initialStop;

  @override
  State<_RouteView> createState() => _RouteViewState();
}

class _RouteViewState extends State<_RouteView> {
  late final Future<bool> _mapReady = ensureGoogleMapReady();
  late final Future<List<gm.BitmapDescriptor?>> _pins = Future.wait([
    for (var i = 0; i < widget.stops.length; i++)
      if (TripNavigation.hasCoordinates(widget.stops[i]))
        _numberedPin(i + 1, i == 0 || i == widget.stops.length - 1)
      else
        Future<gm.BitmapDescriptor?>.value(),
  ]);
  late int? _leg = widget.initialLeg;
  late int? _stop = widget.initialStop;
  bool _showStops = false;
  bool _panEnabled = false;
  gm.GoogleMapController? _map;
  List<RouteInfo?>? _fittedRoutes;

  List<TravelStop> get _stops => widget.stops;

  gm.LatLng _point(TravelStop stop) => gm.LatLng(stop.latitude, stop.longitude);

  Iterable<gm.LatLng> _places() =>
      _stops.where(TripNavigation.hasCoordinates).map(_point);

  Future<void> _fit(List<RouteInfo?>? routes) async {
    final map = _map;
    if (!mounted || map == null) return;
    final selected = _leg;
    final indices = selected == null
        ? List.generate(_stops.length, (index) => index)
        : [selected, selected + 1];
    final geometry = selected == null
        ? routes?.whereType<RouteInfo>() ?? const <RouteInfo>[]
        : [?routes?.elementAtOrNull(selected)];
    final points = {
      for (final index in indices)
        if (TripNavigation.hasCoordinates(_stops[index])) _point(_stops[index]),
      for (final route in geometry)
        for (final point in route.points)
          gm.LatLng(point.latitude, point.longitude),
    };
    if (points.isEmpty) points.addAll(_places());
    if (points.isEmpty) return;
    final update = points.length == 1
        ? gm.CameraUpdate.newLatLngZoom(points.first, 15)
        : gm.CameraUpdate.newLatLngBounds(
            gm.LatLngBounds(
              southwest: gm.LatLng(
                points.map((p) => p.latitude).reduce(math.min),
                points.map((p) => p.longitude).reduce(math.min),
              ),
              northeast: gm.LatLng(
                points.map((p) => p.latitude).reduce(math.max),
                points.map((p) => p.longitude).reduce(math.max),
              ),
            ),
            44,
          );
    await _move(update);
  }

  Future<void> _move(gm.CameraUpdate update) async {
    try {
      await _map?.animateCamera(update);
    } on Exception {
      // The platform view can detach while a camera update is in flight.
    } on StateError {
      // The controller can be disposed when leaving this map.
    }
  }

  void _selectLeg(int? index, List<RouteInfo?>? routes) {
    setState(() {
      _leg = index;
      _stop = null;
    });
    _fit(routes);
  }

  void _selectStop(int index, List<RouteInfo?>? routes, {required bool focus}) {
    final stop = _stops[index];
    setState(() {
      _stop = index;
      _leg = _stops.length < 2 ? null : math.min(index, _stops.length - 2);
    });
    if (!focus) {
      _fit(routes);
    } else if (TripNavigation.hasCoordinates(stop)) {
      _move(gm.CameraUpdate.newLatLngZoom(_point(stop), 15));
    }
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullscreenDayRoute(
          stops: _stops,
          mode: widget.mode,
          routes: widget.routes,
          serviceRetry: widget.onRetry,
          initialLeg: _leg,
          initialStop: _stop,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RouteInfo?>>(
      future: widget.routes,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        final routes = loading ? null : snapshot.data;
        final map = _buildMap(routes);
        final info = _information(routes, loading);
        if (widget.fullscreen) {
          return Column(
            children: [
              Expanded(flex: _showStops ? 3 : 4, child: map),
              ListTile(
                title: Text('Itinerary · ${_stops.length} stops'),
                trailing: Icon(
                  _showStops ? Icons.expand_more : Icons.expand_less,
                ),
                onTap: () => setState(() => _showStops = !_showStops),
              ),
              Expanded(
                flex: _showStops ? 3 : 2,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    info,
                    if (_showStops)
                      ..._orderedStops(
                        routes,
                        includeStops: true,
                        loading: loading,
                      ),
                  ],
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.route_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Day Route Map',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: _places().isEmpty ? null : _openFullscreen,
                  tooltip: 'Open fullscreen map',
                  icon: const Icon(Icons.fullscreen),
                ),
              ],
            ),
            if (_places().isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(height: 280, child: map),
              ),
            info,
            if (_stops.length > 1)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                leading: const Icon(Icons.route_outlined),
                title: const Text('Journey segments'),
                children: _orderedStops(
                  routes,
                  includeStops: false,
                  loading: loading,
                ).toList(),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMap(List<RouteInfo?>? routes) {
    final center = _places().firstOrNull;
    if (center == null) return const SizedBox.shrink();
    return FutureBuilder<bool>(
      future: _mapReady,
      builder: (context, ready) {
        if (ready.connectionState != ConnectionState.done) {
          return const Center(child: Text('Loading map...'));
        }
        if (ready.data != true) {
          return const Center(child: Text('Google Maps is unavailable.'));
        }
        return FutureBuilder<List<gm.BitmapDescriptor?>>(
          future: _pins,
          builder: (context, pins) {
            if (pins.connectionState != ConnectionState.done) {
              return const Center(child: Text('Loading map...'));
            }
            if (!identical(_fittedRoutes, routes)) {
              _fittedRoutes = routes;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted &&
                    identical(_fittedRoutes, routes) &&
                    _stop == null) {
                  _fit(routes);
                }
              });
            }
            return Stack(
              children: [
                gm.GoogleMap(
                  initialCameraPosition: gm.CameraPosition(
                    target: center,
                    zoom: 14,
                  ),
                  onMapCreated: (controller) {
                    _map = controller;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _fit(_fittedRoutes);
                    });
                  },
                  gestureRecognizers: widget.fullscreen || _panEnabled
                      ? {
                          Factory<OneSequenceGestureRecognizer>(
                            EagerGestureRecognizer.new,
                          ),
                        }
                      : const {},
                  scrollGesturesEnabled: widget.fullscreen || _panEnabled,
                  padding: const EdgeInsets.only(top: 48),
                  mapToolbarEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  markers: {
                    for (var i = 0; i < _stops.length; i++)
                      if (TripNavigation.hasCoordinates(_stops[i]))
                        gm.Marker(
                          markerId: gm.MarkerId('stop-$i'),
                          position: _point(_stops[i]),
                          anchor: const Offset(0.5, 0.5),
                          icon:
                              pins.data?[i] ??
                              gm.BitmapDescriptor.defaultMarker,
                          alpha: _leg == null || i == _leg || i == _leg! + 1
                              ? 1
                              : 0.55,
                          consumeTapEvents: true,
                          onTap: () => _selectStop(i, routes, focus: false),
                        ),
                  },
                  polylines: {
                    if (routes != null)
                      for (var i = 0; i < routes.length; i++)
                        if (routes[i] case final route?)
                          gm.Polyline(
                            polylineId: gm.PolylineId('leg-$i'),
                            points: [
                              for (final p in route.points)
                                gm.LatLng(p.latitude, p.longitude),
                            ],
                            color: _leg == null || _leg == i
                                ? AppColors.primary
                                : const Color(
                                    0xFF5C6270,
                                  ).withValues(alpha: 0.55),
                            width: _leg == i ? 8 : 5,
                            zIndex: _leg == i ? 1 : 0,
                            consumeTapEvents: true,
                            onTap: () => _selectLeg(i, routes),
                          ),
                  },
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!widget.fullscreen)
                          IconButton(
                            tooltip: _panEnabled
                                ? 'Resume page scrolling'
                                : 'Enable map panning',
                            isSelected: _panEnabled,
                            selectedIcon: const Icon(Icons.pan_tool),
                            icon: const Icon(Icons.pan_tool_outlined),
                            onPressed: () =>
                                setState(() => _panEnabled = !_panEnabled),
                          ),
                        IconButton(
                          tooltip: 'Recenter route',
                          icon: const Icon(Icons.center_focus_strong),
                          onPressed: () => _fit(routes),
                        ),
                        IconButton(
                          tooltip: 'Zoom in',
                          icon: const Icon(Icons.add),
                          onPressed: () => _move(gm.CameraUpdate.zoomIn()),
                        ),
                        IconButton(
                          tooltip: 'Zoom out',
                          icon: const Icon(Icons.remove),
                          onPressed: () => _move(gm.CameraUpdate.zoomOut()),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _information(List<RouteInfo?>? routes, bool loading) {
    final available = routes?.whereType<RouteInfo>().toList() ?? [];
    final km = available.fold(0.0, (sum, route) => sum + route.distanceKm);
    final minutes = available.fold(
      0.0,
      (sum, route) => sum + route.durationMinutes,
    );
    final missing = _stops.length - _places().length;
    final incomplete = available.length < _stops.length - 1;
    final supported = DayRouteService.supports(widget.mode);
    final conflicts = [
      if (routes != null)
        for (var i = 0; i < routes.length; i++)
          if (routes[i] case final route?)
            if ((DayRouteTiming.between(
                      _stops[i],
                      _stops[i + 1],
                      route,
                    )?.late ??
                    0) >
                0)
              i,
    ];
    final selected = _leg;
    final focused = _stop;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('${_stops.length} stops · ${widget.mode}'),
        if (_stops.isEmpty)
          const Text('No destinations planned for this day.')
        else if (missing > 0)
          Text('$missing of ${_stops.length} stops have no map coordinates.'),
        if (loading) ...[
          const LinearProgressIndicator(),
          const Text('Loading routes…'),
        ],
        if (_stops.length > 1 && !loading) ...[
          if (available.isNotEmpty)
            Text(
              '${km.toStringAsFixed(1)} km · ${minutes.ceil()} min'
              '${incomplete ? ' · ${available.length} of ${_stops.length - 1} journeys' : ' total'}',
            ),
          if (!supported)
            const Text(
              'Public transport routes are unavailable. Open Google Maps for transit directions.',
            )
          else if (incomplete)
            Row(
              children: [
                Expanded(
                  child: Text(
                    available.isEmpty
                        ? 'Routes unavailable.'
                        : 'Some routes are unavailable.',
                  ),
                ),
                if (_stops.asMap().entries.any(
                  (entry) =>
                      entry.key > 0 &&
                      TripNavigation.hasCoordinates(entry.value) &&
                      TripNavigation.hasCoordinates(_stops[entry.key - 1]) &&
                      routes?.elementAtOrNull(entry.key - 1) == null,
                ))
                  TextButton(
                    onPressed: widget.onRetry,
                    child: const Text('Retry'),
                  ),
              ],
            ),
        ],
        if (conflicts.isNotEmpty)
          Text(
            conflicts.length == 1
                ? '1 schedule conflict'
                : '${conflicts.length} schedule conflicts',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (selected != null || focused != null)
          TextButton.icon(
            onPressed: () => _selectLeg(null, routes),
            icon: const Icon(Icons.route),
            label: const Text('Full Route'),
          ),
        if (focused != null)
          Text(
            '${focused + 1}. ${_stops[focused].title}\n${_visit(_stops[focused])}',
          ),
        if (selected != null) ...[
          const SizedBox(height: 6),
          Text(
            '${_stops[selected].title} → ${_stops[selected + 1].title}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(_journey(selected, routes, loading: loading)),
          _navigation(_stops[selected], _stops[selected + 1]),
        ],
        if (focused != null && (selected == null || focused != selected + 1))
          _navigation(null, _stops[focused]),
      ],
    );
  }

  String _visit(TravelStop stop) =>
      '${stop.time} · Visit ${stop.visitMinutes} min';

  String _journey(int index, List<RouteInfo?>? routes, {bool loading = false}) {
    final route = routes?.elementAtOrNull(index);
    if (route == null) {
      if (!TripNavigation.hasCoordinates(_stops[index]) ||
          !TripNavigation.hasCoordinates(_stops[index + 1])) {
        return 'Route unavailable · Missing coordinates';
      }
      return loading ? 'Loading route…' : 'Route unavailable';
    }
    final timing = DayRouteTiming.between(
      _stops[index],
      _stops[index + 1],
      route,
    );
    final travel =
        '${route.distanceKm.toStringAsFixed(1)} km · ${route.durationMinutes.ceil()} min';
    if (timing == null) return travel;
    return [
      travel,
      'Depart ${_clock(timing.departure)} · Arrive ${_clock(timing.arrival)}',
      if (timing.waiting > 0)
        '${timing.waiting} min free before the next visit',
      if (timing.late > 0)
        'Schedule conflict · ${timing.late} min after the next visit starts',
    ].join('\n');
  }

  String _clock(int minutes) =>
      '${TravelStop.formatMinutes(minutes)}${minutes >= 1440 ? ' (+${minutes ~/ 1440} day)' : ''}';

  Widget _segmentTile(int index, List<RouteInfo?>? routes, bool loading) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final route = routes?.elementAtOrNull(index);
    final timing = route == null
        ? null
        : DayRouteTiming.between(_stops[index], _stops[index + 1], route);
    final late = timing?.late ?? 0;
    final waiting = timing?.waiting ?? 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      selected: _leg == index,
      selectedTileColor: colors.secondaryContainer,
      selectedColor: colors.onSecondaryContainer,
      onTap: () => _selectLeg(index, routes),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('From ${index + 1}. ${_stops[index].title}'),
          const SizedBox(height: 4),
          Text('To ${index + 2}. ${_stops[index + 1].title}'),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (timing != null)
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text('Depart ${_clock(timing.departure)}'),
                  Text('Arrive ${_clock(timing.arrival)}'),
                ],
              ),
            Text(
              route == null
                  ? _journey(index, routes, loading: loading)
                  : '${route.distanceKm.toStringAsFixed(1)} km · ${route.durationMinutes.ceil()} min',
            ),
            if (waiting > 0) Text('$waiting min free before the next visit'),
            if (late > 0) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: colors.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Arrives $late min after the next visit starts',
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Iterable<Widget> _orderedStops(
    List<RouteInfo?>? routes, {
    required bool includeStops,
    required bool loading,
  }) sync* {
    for (var i = 0; i < _stops.length; i++) {
      final index = i;
      if (includeStops) {
        yield ListTile(
          leading: CircleAvatar(child: Text('${i + 1}')),
          title: Text(_stops[i].title),
          subtitle: Text(_visit(_stops[i])),
          selected: _stop == i,
          onTap: () => _selectStop(index, routes, focus: true),
        );
      }
      if (i + 1 < _stops.length) {
        if (includeStops) {
          yield ListTile(
            leading: const Icon(Icons.route_outlined),
            title: Text('Travel to ${_stops[i + 1].title}'),
            subtitle: Text(_journey(i, routes, loading: loading)),
            selected: _leg == i,
            onTap: () => _selectLeg(index, routes),
          );
        } else {
          if (i > 0) yield const Divider(height: 1);
          yield _segmentTile(i, routes, loading);
        }
      }
    }
  }

  Widget _navigation(TravelStop? origin, TravelStop destination) {
    if (!TripNavigation.hasCoordinates(destination)) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      children: [
        TextButton(
          onPressed: () =>
              _navigate(TripNavigationMode.maps, origin, destination),
          child: Text(
            origin == null
                ? 'Directions to ${destination.title}'
                : 'Open in Google Maps',
          ),
        ),
        if (widget.mode == 'Driving')
          TextButton(
            onPressed: () =>
                _navigate(TripNavigationMode.waze, origin, destination),
            child: const Text('Open in Waze'),
          ),
      ],
    );
  }

  Future<void> _navigate(
    TripNavigationMode option,
    TravelStop? origin,
    TravelStop destination,
  ) async {
    final opened = await TripNavigation.open(
      TripNavigation.links(option, origin, destination, widget.mode),
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open directions.')),
      );
    }
  }

  static Future<gm.BitmapDescriptor> _numberedPin(
    int number,
    bool endpoint,
  ) async {
    const size = 96.0;
    const center = Offset(size / 2, size / 2);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawCircle(center, 43, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      37,
      Paint()..color = endpoint ? AppColors.primary : const Color(0xFF283041),
    );
    final label = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          color: endpoint ? Colors.black : Colors.white,
          fontSize: 40,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, center.translate(-label.width / 2, -label.height / 2));
    label.dispose();
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data == null
        ? gm.BitmapDescriptor.defaultMarker
        : gm.BitmapDescriptor.bytes(
            data.buffer.asUint8List(),
            width: 42,
            height: 42,
          );
  }
}

class _FullscreenDayRoute extends StatefulWidget {
  const _FullscreenDayRoute({
    required this.stops,
    required this.mode,
    required this.routes,
    required this.serviceRetry,
    required this.initialLeg,
    required this.initialStop,
  });

  final List<TravelStop> stops;
  final String mode;
  final Future<List<RouteInfo?>> routes;
  final Future<List<RouteInfo?>> Function() serviceRetry;
  final int? initialLeg;
  final int? initialStop;

  @override
  State<_FullscreenDayRoute> createState() => _FullscreenDayRouteState();
}

class _FullscreenDayRouteState extends State<_FullscreenDayRoute> {
  late var _routes = widget.routes;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Day Route Map')),
    body: SafeArea(
      child: _RouteView(
        stops: widget.stops,
        mode: widget.mode,
        routes: _routes,
        onRetry: () {
          setState(() => _routes = widget.serviceRetry());
          return _routes;
        },
        fullscreen: true,
        initialLeg: widget.initialLeg,
        initialStop: widget.initialStop,
      ),
    ),
  );
}
