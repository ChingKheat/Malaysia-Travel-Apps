import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/itinerary/models/itinerary_models.dart';
import 'package:smart_travel_planner/features/itinerary/services/supabase_itinerary_service.dart';
import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';
import 'package:smart_travel_planner/shared/utils/demo_feedback.dart';

Future<void> showAssistantStopPreview(
  BuildContext context,
  Map<String, dynamic> proposal, {
  SupabaseItineraryService? repository,
}) async {
  final service = repository ?? SupabaseItineraryService();
  final uid = AuthService().currentUser?.uid;
  final trips = await service.getSavedItineraries(refresh: false);
  if (!context.mounted) return;
  if (uid == null) {
    showDemoSnackBar(context, context.l10n.assistantNoTrips);
    return;
  }
  final result = await showDialog<StopConfirmation>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _StopPreview(
      userId: uid,
      trips: trips,
      proposal: proposal,
      repository: service,
    ),
  );
  if (!context.mounted || result == null) return;
  showDemoSnackBar(
    context,
    result == StopConfirmation.synced
        ? context.l10n.assistantSynced
        : context.l10n.assistantPendingSync,
  );
}

class _StopPreview extends StatefulWidget {
  const _StopPreview({
    required this.userId,
    required this.trips,
    required this.proposal,
    required this.repository,
  });

  final String userId;
  final List<Itinerary> trips;
  final Map<String, dynamic> proposal;
  final SupabaseItineraryService repository;

  @override
  State<_StopPreview> createState() => _StopPreviewState();
}

class _StopPreviewState extends State<_StopPreview> {
  late final _id =
      widget.proposal['proposal_id']?.toString() ?? const Uuid().v4();
  Itinerary? _trip;
  DailySchedule? _day;
  TimeOfDay? _arrival;
  TimeOfDay? _departure;
  StopConfirmation? _error;
  bool _saving = false;

  T? _unique<T>(Iterable<T> choices) =>
      choices.length == 1 ? choices.first : null;

  @override
  void initState() {
    super.initState();
    final details = widget.proposal;
    final name = details['trip_title']?.toString().trim().toLowerCase();
    _trip = _unique(
      widget.trips.where((trip) => trip.title.trim().toLowerCase() == name),
    );
    _prefillDay();
    _arrival = _parseTime(details['arrival_time']);
    _departure = _parseTime(details['departure_time']);
  }

  void _prefillDay() {
    final date = widget.proposal['date']?.toString();
    final number = widget.proposal['day_number'];
    _day = date == null && number == null
        ? null
        : _unique(
            (_trip?.dailySchedules ?? const <DailySchedule>[]).where(
              (day) =>
                  (number == null || day.dayNumber == number) &&
                  (date == null ||
                      day.scheduleDate.toIso8601String().split('T').first ==
                          date),
            ),
          );
  }

  TimeOfDay? _parseTime(Object? input) {
    final match = RegExp(
      r'^([01]\d|2[0-3]):([0-5]\d)$',
    ).firstMatch(input?.toString() ?? '');
    return match == null
        ? null
        : TimeOfDay(hour: int.parse(match[1]!), minute: int.parse(match[2]!));
  }

  int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;
  String _clock(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  bool get _validTimes =>
      _arrival != null &&
      _departure != null &&
      _minutes(_arrival!) < _minutes(_departure!);

  Future<void> _pickTime(bool arrival) async {
    final time = await showTimePicker(
      context: context,
      initialTime: (arrival ? _arrival : _departure) ?? TimeOfDay.now(),
    );
    if (!mounted || time == null) return;
    setState(() {
      if (arrival) {
        _arrival = time;
      } else {
        _departure = time;
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving || _trip == null || _day == null || !_validTimes) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final data = widget.proposal;
    final start = _clock(_arrival!);
    final end = _clock(_departure!);
    final duration = _minutes(_departure!) - _minutes(_arrival!);
    final snapshot = TravelStop.fromJson({
      'title': data['place_name'],
      'place_id': data['place_id'],
      'time': '$start - $end',
      'duration': '$duration min',
      'visit_minutes': duration,
      'category': data['category'],
      'latitude': data['latitude'],
      'longitude': data['longitude'],
    });
    final result = await widget.repository.confirmStop(
      widget.userId,
      _trip!.itineraryId,
      ItineraryStop(
        id: _id,
        scheduleId: _day!.scheduleId,
        placeId: data['place_id'].toString(),
        placeName: snapshot.title,
        stopOrder: 0,
        arrivalTime: start,
        departureTime: end,
        category: snapshot.category,
        snapshot: snapshot,
        placeState: data['state']?.toString(),
      ),
    );
    if (!mounted) return;
    if (result == StopConfirmation.pending ||
        result == StopConfirmation.synced) {
      Navigator.pop(context, result);
    } else {
      setState(() {
        _saving = false;
        _error = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final error = switch (_error) {
      null when widget.trips.isEmpty => l.assistantNoTrips,
      StopConfirmation.conflict => l.assistantStopConflict,
      StopConfirmation.unavailable => l.assistantTripUnavailable,
      StopConfirmation.failed => l.assistantSaveFailed,
      _ =>
        _arrival != null && _departure != null && !_validTimes
            ? l.assistantInvalidTimes
            : null,
    };
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(l.assistantPreviewStop),
        scrollable: true,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.proposal['place_name'].toString(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: InputDecoration(labelText: l.assistantTrip),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Itinerary>(
                  isExpanded: true,
                  value: _trip,
                  hint: Text(l.assistantChoose),
                  items: [
                    for (final trip in widget.trips)
                      DropdownMenuItem(
                        value: trip,
                        child: Text(
                          trip.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _saving || widget.trips.isEmpty
                      ? null
                      : (trip) => setState(() {
                          _trip = trip;
                          _prefillDay();
                          _error = null;
                        }),
                ),
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: InputDecoration(labelText: l.assistantDay),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<DailySchedule>(
                  isExpanded: true,
                  value: _day,
                  hint: Text(l.assistantChoose),
                  items: [
                    for (final day
                        in _trip?.dailySchedules ?? const <DailySchedule>[])
                      DropdownMenuItem(
                        value: day,
                        child: Text(
                          context.localDate(day.scheduleDate),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _saving || _trip == null
                      ? null
                      : (day) => setState(() {
                          _day = day;
                          _error = null;
                        }),
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final arrival in [true, false])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  arrival ? l.assistantArrival : l.assistantDeparture,
                ),
                subtitle: Text(
                  (arrival ? _arrival : _departure)?.format(context) ??
                      l.assistantChoose,
                ),
                trailing: const Icon(Icons.schedule),
                onTap: _saving ? null : () => _pickTime(arrival),
              ),
            if (error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_saving) const LinearProgressIndicator(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: !_saving && _trip != null && _day != null && _validTimes
                ? _save
                : null,
            child: Text(l.assistantConfirmStop),
          ),
        ],
      ),
    );
  }
}
