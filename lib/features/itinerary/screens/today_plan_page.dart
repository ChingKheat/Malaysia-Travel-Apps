import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/services/scheduling_engine.dart';
import 'package:smart_travel_planner/features/itinerary/services/travel_matrix_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_navigation.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';

class TodayPlanPage extends StatefulWidget {
  const TodayPlanPage({
    super.key,
    required this.storageKey,
    required this.stops,
    required this.date,
    required this.preferences,
  });

  final String storageKey;
  final List<TravelStop> stops;
  final DateTime date;
  final TripPreferences preferences;

  @override
  State<TodayPlanPage> createState() => _TodayPlanPageState();
}

class _TodayPlanPageState extends State<TodayPlanPage> {
  late List<TravelStop> _stops = [...widget.stops];
  final _completed = <String>{};
  final _skipped = <String>{};
  bool _started = false;
  bool _paused = false;
  bool _ended = false;
  bool _busy = true;

  String get _key => 'trip-execution-v1:${widget.storageKey}';
  String _id(TravelStop stop) => SchedulingEngine.identity(stop);
  Iterable<TravelStop> get _remaining => _stops.where(
    (stop) => !_completed.contains(_id(stop)) && !_skipped.contains(_id(stop)),
  );

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (!mounted || raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final byId = {for (final stop in widget.stops) _id(stop): stop};
      _completed.addAll(
        (data['completed'] as List).cast<String>().where(byId.containsKey),
      );
      _skipped.addAll(
        (data['skipped'] as List).cast<String>().where(byId.containsKey),
      );
      final times = data['times'] as Map<String, dynamic>;
      _stops = widget.stops.map((stop) {
        final saved = times[_id(stop)] as List?;
        if (saved == null) return stop;
        return stop.scheduled(
          saved[0] as int,
          saved[1] as int,
          transit: saved[2] as int,
          estimated: saved[3] as bool,
          transportCost: stop.travelCost,
        );
      }).toList();
      _started = data['started'] == true;
      _paused = data['paused'] == true;
      _ended = data['ended'] == true;
    } on Exception {
      if (mounted) _message('Could not restore saved trip progress.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int _start(TravelStop stop) =>
      SchedulingEngine.parseClock(stop.time.split(' - ').first);
  int _end(TravelStop stop) => _start(stop) + stop.visitMinutes;

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString(
        _key,
        jsonEncode({
          'started': _started,
          'paused': _paused,
          'ended': _ended,
          'completed': _completed.toList(),
          'skipped': _skipped.toList(),
          'times': {
            for (final stop in _stops)
              if (stop.time.contains(' - '))
                _id(stop): [
                  _start(stop),
                  _end(stop),
                  stop.travelMinutes,
                  stop.travelIsEstimated,
                ],
          },
        }),
      );
      if (!saved && mounted) _message('Trip progress could not be saved.');
    } on Exception {
      if (mounted) _message('Trip progress could not be saved.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _navigate(TravelStop? origin, TravelStop destination) async {
    final option = await showModalBottomSheet<TripNavigationMode>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(destination.title),
              subtitle: Text(origin?.title ?? 'Current location'),
            ),
            for (final (mode, label, icon) in [
              (
                TripNavigationMode.waze,
                'Drive with Waze',
                Icons.directions_car,
              ),
              (
                TripNavigationMode.moovit,
                'Transit directions by Moovit',
                Icons.directions_transit,
              ),
              (
                TripNavigationMode.maps,
                'Google Maps directions',
                Icons.map_outlined,
              ),
              (
                TripNavigationMode.grab,
                'Open Grab ride options',
                Icons.local_taxi_outlined,
              ),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                subtitle: mode == TripNavigationMode.grab
                    ? const Text(
                        'Confirm pickup, destination and fare in Grab.',
                      )
                    : null,
                onTap: () => Navigator.pop(context, mode),
              ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy destination'),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: destination.title));
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
    if (!mounted || option == null) return;
    final opened = await TripNavigation.open(
      TripNavigation.links(
        option,
        origin,
        destination,
        widget.preferences.travelMode ?? 'Driving',
      ),
    );
    if (!opened && mounted) _message('Could not open directions.');
  }

  Future<void> _replan(TravelStop current, {required bool skip}) async {
    final pending = _remaining
        .where((stop) => !skip || stop != current)
        .toList();
    final completedOrigin = _stops
        .where((stop) => _completed.contains(_id(stop)))
        .lastOrNull;
    final origin = completedOrigin ?? widget.preferences.departurePoint;
    final mode = widget.preferences.travelMode ?? 'Driving';
    final earliestDeparture = completedOrigin == null
        ? 0
        : _end(completedOrigin);
    final start = math.max(
      earliestDeparture,
      _start(current) - current.travelMinutes + (skip ? 0 : 15),
    );
    setState(() => _busy = true);
    try {
      final legs = await TravelMatrixService().fetch([
        ?origin,
        ...pending,
      ], mode);
      if (!mounted) return;
      final startMinute = math.max(0, start);
      if (startMinute >= 1440) {
        _message('The remaining route does not fit today.');
        return;
      }
      final revised = SchedulingEngine.schedule(
        candidates: pending,
        preferences: widget.preferences.copyWith(
          dailyStartTime: TimeOfDay(
            hour: startMinute ~/ 60,
            minute: startMinute % 60,
          ),
          departurePoint: origin,
        ),
        date: widget.date,
        visited: {},
        legs: legs,
        preserveOrder: true,
      );
      if (revised.length != pending.length) {
        _message(
          'The remaining visits do not fit. Try shortening or reordering visits in Edit Day.',
        );
        return;
      }
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            skip ? 'Skip ${current.title}?' : 'Apply 15-minute delay?',
          ),
          content: SingleChildScrollView(
            child: Text(
              revised.isEmpty
                  ? 'No visits remain today.'
                  : revised
                        .map((stop) => '${stop.time} · ${stop.title}')
                        .join('\n'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (!mounted || confirm != true) return;
      final updates = {for (final stop in revised) _id(stop): stop};
      _stops = _stops.map((stop) => updates[_id(stop)] ?? stop).toList();
      if (skip) _skipped.add(_id(current));
      await _save();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _remaining.firstOrNull;
    final next = _remaining.skip(1).firstOrNull;
    final origin =
        _stops.where((stop) => _completed.contains(_id(stop))).lastOrNull ??
        widget.preferences.departurePoint;
    final canAct = !_busy && _started && !_paused && !_ended;
    return Scaffold(
      appBar: AppBar(title: const Text('Today’s Plan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _ended
                ? 'Day ended'
                : _paused
                ? 'Paused'
                : current == null
                ? 'Day complete'
                : current.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            '${_completed.length} visited · ${_skipped.length} skipped · ${_remaining.length} remaining',
          ),
          if (next != null)
            Text('Next · ${next.title} · ${next.time.split(' - ').first}'),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (current != null && !_ended)
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () {
                          _paused = _started && !_paused;
                          _started = true;
                          _save();
                        },
                  child: Text(
                    !_started
                        ? 'Start Trip'
                        : _paused
                        ? 'Resume'
                        : 'Pause',
                  ),
                ),
              if (current != null && TripNavigation.hasCoordinates(current))
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _navigate(origin, current),
                  icon: const Icon(Icons.directions_outlined),
                  label: const Text('Directions'),
                ),
              if (current != null && canAct) ...[
                OutlinedButton(
                  onPressed: () {
                    _completed.add(_id(current));
                    _save();
                  },
                  child: const Text('Mark visited'),
                ),
                TextButton(
                  onPressed: () => _replan(current, skip: true),
                  child: const Text('Skip'),
                ),
                TextButton(
                  onPressed: () => _replan(current, skip: false),
                  child: const Text('Delay 15 min'),
                ),
              ],
              if (_started && !_ended)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          final end = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('End today’s trip?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('End'),
                                ),
                              ],
                            ),
                          );
                          if (end == true && mounted) {
                            _ended = true;
                            _save();
                          }
                        },
                  child: const Text('End day'),
                ),
            ],
          ),
          const Divider(),
          for (var i = 0; i < _stops.length; i++) ...[
            if (_stops[i].travelMinutes > 0 &&
                !_skipped.contains(_id(_stops[i])))
              ListTile(
                leading: const Icon(Icons.route_outlined),
                title: Text('Travel to ${_stops[i].title}'),
                subtitle: Text(
                  '${TravelStop.formatMinutes(math.max(0, _start(_stops[i]) - _stops[i].travelMinutes))}'
                  ' – ${TravelStop.formatMinutes(_start(_stops[i]))}'
                  ' · ${_stops[i].travelMinutes} min'
                  ' · ${_stops[i].travelIsEstimated ? 'Planning estimate' : 'Route estimate'}',
                ),
                onTap: () => _navigate(
                  i > 0
                      ? _stops
                            .take(i)
                            .where((stop) => !_skipped.contains(_id(stop)))
                            .lastOrNull
                      : widget.preferences.departurePoint,
                  _stops[i],
                ),
              ),
            ListTile(
              leading: Icon(
                _completed.contains(_id(_stops[i]))
                    ? Icons.check_circle_outline
                    : _skipped.contains(_id(_stops[i]))
                    ? Icons.skip_next
                    : Icons.place_outlined,
              ),
              title: Text(_stops[i].title),
              subtitle: Text(
                '${_stops[i].time} · ${_stops[i].visitMinutes} min',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
