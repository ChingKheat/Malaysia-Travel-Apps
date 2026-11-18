import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/services/scheduling_engine.dart';
import 'package:smart_travel_planner/features/itinerary/services/travel_matrix_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_navigation.dart';
import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';

enum _TripAction { pause, skip, delay, end }

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
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
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

  Future<void> _endDay() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.todayPlanEndPrompt),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.todayPlanEnd),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _ended = true;
    await _save();
  }

  bool _showsTravel(TravelStop stop) =>
      stop.travelMinutes > 0 && !_skipped.contains(_id(stop));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final remaining = _remaining.toList();
    final current = remaining.firstOrNull;
    final canAct = _started && !_paused && !_ended;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.todayPlan),
        actions: [
          if (_started && !_ended)
            PopupMenuButton<_TripAction>(
              tooltip: l10n.todayPlanTripActions,
              enabled: !_busy,
              onSelected: (action) async {
                switch (action) {
                  case _TripAction.pause:
                    _paused = true;
                    await _save();
                  case _TripAction.skip:
                    if (current != null) await _replan(current, skip: true);
                  case _TripAction.delay:
                    if (current != null) await _replan(current, skip: false);
                  case _TripAction.end:
                    await _endDay();
                }
              },
              itemBuilder: (context) => [
                if (canAct && current != null) ...[
                  PopupMenuItem(
                    value: _TripAction.pause,
                    child: Text(l10n.todayPlanPause),
                  ),
                  PopupMenuItem(
                    value: _TripAction.skip,
                    child: Text(l10n.todayPlanSkip),
                  ),
                  PopupMenuItem(
                    value: _TripAction.delay,
                    child: Text(l10n.todayPlanDelay),
                  ),
                  const PopupMenuDivider(),
                ],
                PopupMenuItem(
                  value: _TripAction.end,
                  child: Text(l10n.todayPlanEnd),
                ),
              ],
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _busy
              ? LinearProgressIndicator(
                  minHeight: 4,
                  semanticsLabel: l10n.todayPlanUpdating,
                )
              : const SizedBox(height: 4),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _summary(remaining),
                if (_stops.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.todayPlanTimeline,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final (index, stop) in _stops.indexed) ...[
                    if (_showsTravel(stop)) _travelRow(index, stop),
                    _visitRow(
                      stop,
                      first: index == 0 && !_showsTravel(stop),
                      last: index == _stops.length - 1,
                      active: !_ended && stop == current,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: current != null && !_ended
          ? Material(
              color: colors.surface,
              child: SafeArea(
                top: false,
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            textStyle: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: _busy
                              ? null
                              : () {
                                  if (canAct) {
                                    _completed.add(_id(current));
                                  } else {
                                    _started = true;
                                    _paused = false;
                                  }
                                  _save();
                                },
                          icon: Icon(
                            canAct ? Icons.check : Icons.play_arrow_outlined,
                          ),
                          label: Text(
                            canAct
                                ? l10n.todayPlanMarkVisited
                                : _paused
                                ? l10n.todayPlanResume
                                : l10n.todayPlanStart,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  String _visitDetails(TravelStop stop, {String? status}) => [
    stop.time.replaceFirst(' - ', ' – '),
    context.l10n.todayPlanMinutes(stop.visitMinutes),
    ?status,
  ].join(' · ');

  Widget _summary(List<TravelStop> remaining) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final caption = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final current = remaining.firstOrNull;
    final next = remaining.skip(1).firstOrNull;
    final status = _ended
        ? l10n.todayPlanEnded
        : current == null
        ? l10n.todayPlanComplete
        : _paused
        ? l10n.todayPlanPaused
        : _started
        ? l10n.todayPlanCurrentStop
        : l10n.todayPlanFirstStop;
    final origin =
        _stops.where((stop) => _completed.contains(_id(stop))).lastOrNull ??
        widget.preferences.departurePoint;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            MaterialLocalizations.of(context).formatFullDate(widget.date),
            style: caption,
          ),
          const SizedBox(height: 12),
          if (current != null && !_ended) ...[
            Text(
              status,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              current != null && !_ended ? current.title : status,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (current != null && !_ended) ...[
            const SizedBox(height: 4),
            Text(
              _visitDetails(current),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          if (next != null && !_ended) ...[
            const SizedBox(height: 8),
            Text(
              l10n.todayPlanNext(next.title, next.time.split(' - ').first),
              style: caption,
            ),
          ],
          const SizedBox(height: 16),
          if (_stops.isNotEmpty) ...[
            ExcludeSemantics(
              child: LinearProgressIndicator(
                value: (_stops.length - remaining.length) / _stops.length,
                minHeight: 4,
                borderRadius: BorderRadius.circular(4),
                stopIndicatorRadius: 0,
                backgroundColor: colors.outline,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            l10n.todayPlanProgress(
              _completed.length,
              _skipped.length,
              remaining.length,
            ),
            style: caption,
          ),
          if (current != null && TripNavigation.hasCoordinates(current)) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: _busy ? null : () => _navigate(origin, current),
              icon: const Icon(Icons.directions_outlined),
              label: Text(l10n.todayPlanDirections),
            ),
          ],
        ],
      ),
    );
  }

  Widget _travelRow(int index, TravelStop stop) {
    final l10n = context.l10n;
    final start = TravelStop.formatMinutes(
      math.max(0, _start(stop) - stop.travelMinutes),
    );
    final end = TravelStop.formatMinutes(_start(stop));
    final estimate = stop.travelIsEstimated
        ? l10n.todayPlanPlanningEstimate
        : l10n.todayPlanRouteEstimate;
    return _TimelineRow(
      first: index == 0,
      icon: Icons.route_outlined,
      title: l10n.todayPlanTravel(stop.travelMinutes),
      detail: '$start – $end · $estimate',
      travel: true,
      actionLabel: l10n.todayPlanDirectionsTo(stop.title),
      onTap: _busy
          ? null
          : () => _navigate(
              index == 0
                  ? widget.preferences.departurePoint
                  : _stops
                        .take(index)
                        .where((s) => !_skipped.contains(_id(s)))
                        .lastOrNull,
              stop,
            ),
    );
  }

  Widget _visitRow(
    TravelStop stop, {
    required bool first,
    required bool last,
    required bool active,
  }) {
    final l10n = context.l10n;
    final visited = _completed.contains(_id(stop));
    final skipped = _skipped.contains(_id(stop));
    final state = visited
        ? l10n.todayPlanVisited
        : skipped
        ? l10n.todayPlanSkipped
        : null;
    return _TimelineRow(
      first: first,
      last: last,
      icon: visited
          ? Icons.check_circle_outline
          : skipped
          ? Icons.skip_next_outlined
          : Icons.place_outlined,
      title: stop.title,
      detail: _visitDetails(stop, status: state),
      active: active,
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.first,
    required this.icon,
    required this.title,
    required this.detail,
    this.last = false,
    this.active = false,
    this.travel = false,
    this.actionLabel,
    this.onTap,
  });

  final bool first;
  final bool last;
  final IconData icon;
  final String title;
  final String detail;
  final bool active;
  final bool travel;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final radius = BorderRadius.circular(12);

    return Stack(
      children: [
        if (!first || !last)
          PositionedDirectional(
            start: 15,
            top: first ? 28 : 0,
            bottom: last ? null : 0,
            height: last ? 28 : null,
            width: 2,
            child: ColoredBox(color: colors.outline),
          ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 44),
          child: MergeSemantics(
            child: Semantics(
              button: onTap != null ? true : null,
              label: onTap != null ? actionLabel : null,
              child: Material(
                color: active ? colors.surface : Colors.transparent,
                borderRadius: radius,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: radius,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: travel
                                    ? theme.textTheme.labelLarge?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      )
                                    : theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                detail,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (onTap != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.navigate_next,
                            size: 20,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          start: travel ? 4 : 0,
          top: travel ? 16 : 12,
          child: ExcludeSemantics(
            child: Container(
              width: travel ? 24 : 32,
              height: travel ? 24 : 32,
              decoration: BoxDecoration(
                color: active ? colors.primary : theme.scaffoldBackgroundColor,
                shape: BoxShape.circle,
                border: active || travel
                    ? null
                    : Border.all(color: colors.outline),
              ),
              child: Icon(
                icon,
                size: 16,
                color: active ? colors.onPrimary : colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
