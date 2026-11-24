import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:smart_travel_planner/features/itinerary/models/destination_leg.dart';
import 'package:smart_travel_planner/features/itinerary/models/transfer_event.dart';
import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/services/scheduling_engine.dart';
import 'package:smart_travel_planner/features/itinerary/services/transfer_manager.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';
import 'package:smart_travel_planner/shared/models/weather_forecast.dart';

class SegmentedScheduleResult {
  final Map<int, List<TravelStop>> days;
  final Map<int, String> warnings;
  final List<TransferEvent> resolvedTransfers;

  const SegmentedScheduleResult({
    required this.days,
    required this.warnings,
    required this.resolvedTransfers,
  });
}

/// Orchestrates multi-destination itinerary generation by partitioning the trip
/// into localized [DestinationLeg] segments and inserting structured
/// [TransferEvent] transition days between hubs.
class SegmentedItineraryScheduler {
  static const _distance = Distance();

  static Future<SegmentedScheduleResult> schedule({
    required TripPreferences preferences,
    required Future<List<TravelStop>> Function(DestinationLeg leg)
    fetchCandidates,
    Future<TravelStop> Function(TravelStop stop, DestinationLeg leg)?
    resolvePriority,
    List<WeatherForecast?>? weather,
  }) async {
    final rawLegs = preferences.effectiveLegs;
    if (rawLegs.isEmpty) {
      return const SegmentedScheduleResult(
        days: {},
        warnings: {},
        resolvedTransfers: [],
      );
    }

    final legs = preferences.autoOptimizeRouteOrder
        ? TransferManager.optimizeLegOrder(rawLegs)
        : rawLegs;

    final allDays = <int, List<TravelStop>>{};
    final warnings = <int, String>{};
    final transfers = <TransferEvent>[];
    final usedIds = <String>{};
    final priorities = {
      for (final stop in preferences.mustVisitPlaces)
        SchedulingEngine.identity(stop): stop,
    };
    final scheduledPriorities = <String>{};
    final prioritiesNearHubs = <String>{};
    final prioritiesWithHours = <String>{};

    final dailyStartMin =
        TripPreferences.minutesOf(preferences.dailyStartTime) ?? 540;
    final dailyEndMin =
        TripPreferences.minutesOf(preferences.dailyEndTime) ?? 1260;

    int currentDayOffset = 0;

    for (int i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final legDaysCount = leg.allocatedDays;
      final isTransitionFirstDay = i > 0;

      // 1. Retrieve candidates scoped strictly to this destination leg.
      final rawCandidates = await fetchCandidates(leg);
      final date = preferences.dateForDay(currentDayOffset);
      final localPriorities = <String, TravelStop>{};
      for (final entry in priorities.entries) {
        if (scheduledPriorities.contains(entry.key) ||
            !_isNearLeg(entry.value, leg)) {
          continue;
        }
        var stop = entry.value;
        prioritiesNearHubs.add(entry.key);
        if (SchedulingEngine.intervals(stop, date) == null) {
          for (final candidate in rawCandidates) {
            if (_isNearLeg(candidate, leg) &&
                (SchedulingEngine.identity(candidate) == entry.key ||
                    _titleKey(candidate) == _titleKey(stop)) &&
                SchedulingEngine.intervals(candidate, date) != null) {
              stop = candidate;
              break;
            }
          }
          if (SchedulingEngine.intervals(stop, date) == null &&
              resolvePriority != null) {
            stop = await resolvePriority(stop, leg);
          }
        }
        if (_isNearLeg(stop, leg)) {
          localPriorities[entry.key] = stop;
          if (SchedulingEngine.intervals(stop, date) != null) {
            prioritiesWithHours.add(entry.key);
          }
        }
      }
      final priorityIds = localPriorities.values
          .map(SchedulingEngine.identity)
          .toSet();
      final priorityTitles = localPriorities.values.map(_titleKey).toSet();
      final localCandidates = _filterCandidatesForLeg(
        rawCandidates: [
          ...localPriorities.values,
          for (final stop in rawCandidates)
            if (!priorityIds.contains(SchedulingEngine.identity(stop)) &&
                !priorityTitles.contains(_titleKey(stop)))
              stop,
        ],
        leg: leg,
        usedIds: usedIds,
      );

      // 2. Build leg-scoped preferences with local base accommodation/hub.
      final hubAnchor =
          leg.accommodation ??
          TravelStop(
            title: '${leg.hubName} City Centre',
            time: '',
            note: 'Base Hub',
            description: 'Base accommodation hub for ${leg.hubName}.',
            duration: '0 min',
            openingHours: '24 hours',
            tips: const [],
            icon: Icons.hotel_outlined,
            color: const Color(0xFFE5A645),
            latitude: leg.latitude,
            longitude: leg.longitude,
          );

      final legPrefs = preferences.copyWith(
        destination: leg.stateName,
        numberOfDays: legDaysCount,
        startDate: preferences.dateForDay(currentDayOffset),
        accommodationArea: hubAnchor,
        departurePoint: hubAnchor,
        planningMode: PlanningMode.singleDestination,
        legs: [leg],
        mustVisitPlaces: localPriorities.values.toList(),
      );

      int fullDaysStartOffset = 0;

      // 3. Schedule Transition Day if moving from previous leg.
      if (isTransitionFirstDay) {
        final prevLeg = legs[i - 1];
        final transferDate = preferences.dateForDay(currentDayOffset);
        final preferredMode = _preferredInterCityMode(preferences.travelMode);
        final transfer = TransferManager.estimateTransfer(
          prevLeg,
          leg,
          transferDate,
          preferredMode: preferredMode,
        );
        transfers.add(transfer);

        final transitionStops = _buildTransitionDayStops(
          transfer: transfer,
          destinationCandidates: localCandidates,
          priorityIds: priorityIds,
          arrivalAnchor: hubAnchor,
          travelMode: preferences.travelMode ?? 'Driving',
          dailyStartMin: dailyStartMin,
          dailyEndMin: dailyEndMin,
          usedIds: usedIds,
        );
        allDays[currentDayOffset] = transitionStops;

        final remainingSightseeing =
            (dailyEndMin - dailyStartMin) - transfer.totalTransferMinutes;
        if (remainingSightseeing < 0) {
          warnings[currentDayOffset] =
              'The transfer is estimated to finish after your planned end time. No sightseeing is scheduled.';
        } else if (legDaysCount == 1 && remainingSightseeing < 180) {
          warnings[currentDayOffset] =
              'Only ${(remainingSightseeing / 60).clamp(0, 24).toStringAsFixed(1)}h left in ${leg.hubName} after transit. Consider 2+ days.';
        } else if (transfer.totalTransferMinutes > 360) {
          warnings[currentDayOffset] =
              'Long transfer (${(transfer.totalTransferMinutes / 60).toStringAsFixed(1)}h). Evening kept light.';
        }

        fullDaysStartOffset = 1;
      }

      // 4. Schedule remaining full sightseeing days for this leg using SchedulingEngine.
      final remainingLegDays = legDaysCount - fullDaysStartOffset;
      if (remainingLegDays > 0) {
        final dates = List.generate(
          remainingLegDays,
          (d) => preferences.dateForDay(
            currentDayOffset + fullDaysStartOffset + d,
          ),
        );
        final legWeather = List.generate(remainingLegDays, (d) {
          final globalIdx = currentDayOffset + fullDaysStartOffset + d;
          if (weather != null && globalIdx < weather.length) {
            return weather[globalIdx];
          }
          return null;
        });

        final scheduled = SchedulingEngine.scheduleTrip(
          candidates: localCandidates
              .where(
                (stop) => !usedIds.contains(SchedulingEngine.identity(stop)),
              )
              .toList(),
          preferences: legPrefs,
          dates: dates,
          weather: legWeather,
          dailyLegs: List.filled(remainingLegDays, const {}),
        );

        for (int d = 0; d < remainingLegDays; d++) {
          final globalDay = currentDayOffset + fullDaysStartOffset + d;
          final dayStops = d < scheduled.length ? scheduled[d] : <TravelStop>[];
          for (final stop in dayStops) {
            usedIds.add(SchedulingEngine.identity(stop));
          }
          allDays[globalDay] = dayStops;
        }
      }

      scheduledPriorities.addAll(
        localPriorities.entries
            .where(
              (entry) =>
                  usedIds.contains(SchedulingEngine.identity(entry.value)),
            )
            .map((entry) => entry.key),
      );
      currentDayOffset += legDaysCount;
    }

    final missed = priorities.entries
        .where((entry) => !scheduledPriorities.contains(entry.key))
        .map((entry) {
          final reason = !prioritiesNearHubs.contains(entry.key)
              ? 'outside the selected destination areas or missing a location'
              : !prioritiesWithHours.contains(entry.key)
              ? 'opening hours unavailable'
              : 'no visit fit the available schedule';
          return '${entry.value.title} ($reason)';
        })
        .toList();
    if (missed.isNotEmpty) {
      final message =
          'Must-visit places that could not be scheduled: ${missed.join(', ')}.';
      warnings.update(
        0,
        (warning) => '$warning $message',
        ifAbsent: () => message,
      );
    }

    return SegmentedScheduleResult(
      days: allDays,
      warnings: warnings,
      resolvedTransfers: transfers,
    );
  }

  static List<TravelStop> _filterCandidatesForLeg({
    required List<TravelStop> rawCandidates,
    required DestinationLeg leg,
    required Set<String> usedIds,
  }) {
    final seen = {...usedIds};
    return rawCandidates
        .where(
          (stop) =>
              _isNearLeg(stop, leg) &&
              seen.add(SchedulingEngine.identity(stop)),
        )
        .toList();
  }

  static String _titleKey(TravelStop stop) => stop.title.trim().toLowerCase();

  static bool _isNearLeg(TravelStop stop, DestinationLeg leg) =>
      stop.latitude.isFinite &&
      stop.longitude.isFinite &&
      stop.latitude != 0 &&
      stop.longitude != 0 &&
      _distance.as(
            LengthUnit.Kilometer,
            LatLng(leg.latitude, leg.longitude),
            LatLng(stop.latitude, stop.longitude),
          ) <=
          leg.searchRadiusKm;

  static InterCityTransportMode? _preferredInterCityMode(String? travelMode) {
    final m = (travelMode ?? '').toLowerCase();
    if (m.contains('train') || m.contains('transit') || m.contains('public')) {
      return InterCityTransportMode.etsTrain;
    }
    if (m.contains('bus')) return InterCityTransportMode.expressBus;
    return InterCityTransportMode.privateCar;
  }

  static List<TravelStop> _buildTransitionDayStops({
    required TransferEvent transfer,
    required List<TravelStop> destinationCandidates,
    required Set<String> priorityIds,
    required TravelStop arrivalAnchor,
    required String travelMode,
    required int dailyStartMin,
    required int dailyEndMin,
    required Set<String> usedIds,
  }) {
    final stops = <TravelStop>[];
    int cursor = dailyStartMin;

    // 1. Hotel Check-out & Terminal Access
    stops.add(
      TravelStop(
        title: 'Check-out from ${transfer.fromLabel}',
        time: '${_fmt(cursor)} - ${_fmt(cursor + transfer.accessMinutes)}',
        note: 'Hotel Check-out & Departure Prep',
        description:
            'Complete check-out and travel to the departure point in ${transfer.fromLabel}.',
        duration: '${transfer.accessMinutes} min',
        openingHours: '24 hours',
        tips: const ['Prepare luggage and confirm check-out'],
        icon: Icons.luggage_outlined,
        color: const Color(0xFFB9BBC3),
        category: 'Transit',
        visitMinutes: transfer.accessMinutes,
      ),
    );
    cursor += transfer.accessMinutes;

    // 2. Main Inter-City Journey + Buffer
    final journeyMinutes = transfer.mainTransitMinutes + transfer.bufferMinutes;
    stops.add(
      TravelStop(
        title: 'Travel: ${transfer.fromLabel} → ${transfer.toLabel}',
        time: '${_fmt(cursor)} - ${_fmt(cursor + journeyMinutes)}',
        note:
            '${transfer.transportMode.label}${transfer.isEstimated ? " (Est.)" : ""}',
        description:
            'Inter-city transfer (${transfer.distanceKm.round()} km) including contingency buffer.',
        duration: '$journeyMinutes min',
        openingHours: 'Scheduled',
        tips: [
          if (transfer.transportMode == InterCityTransportMode.domesticFlight)
            'Arrive at airport 2 hours prior for check-in and security'
          else
            'Keep e-wallet / ticket ready for inter-city travel',
        ],
        icon: transfer.transportMode == InterCityTransportMode.domesticFlight
            ? Icons.flight_takeoff_outlined
            : Icons.directions_transit_outlined,
        color: const Color(0xFFE5A645),
        category: 'Transit',
        visitMinutes: transfer.bufferMinutes,
        travelMinutes: transfer.mainTransitMinutes,
        travelIsEstimated: transfer.isEstimated,
      ),
    );
    cursor += journeyMinutes;

    // 3. Arrival & Check-in
    stops.add(
      TravelStop(
        title: 'Arrive & Check-in at ${transfer.toLabel}',
        time: '${_fmt(cursor)} - ${_fmt(cursor + transfer.arrivalMinutes)}',
        note: 'Accommodation Check-in / Luggage Drop',
        description: 'Settle into your ${transfer.toLabel} accommodation.',
        duration: '${transfer.arrivalMinutes} min',
        openingHours: '14:00+',
        tips: const ['If arriving early, request luggage storage at reception'],
        icon: Icons.hotel_outlined,
        color: const Color(0xFFB9BBC3),
        category: 'Transit',
        visitMinutes: transfer.arrivalMinutes,
      ),
    );
    cursor += transfer.arrivalMinutes;

    if (cursor >= dailyEndMin) return stops;

    bool isEveningActivity(TravelStop stop) {
      final category = stop.category.toLowerCase();
      return category.contains('food') ||
          category.contains('dining') ||
          category.contains('night');
    }

    bool isPriority(TravelStop stop) =>
        priorityIds.contains(SchedulingEngine.identity(stop));
    final suggestions = destinationCandidates.where(
      (stop) => !isPriority(stop),
    );
    var origin = arrivalAnchor;
    var addedPriority = false;
    for (final candidate in [
      ...destinationCandidates.where(isPriority),
      ...suggestions.where(isEveningActivity),
      ...suggestions.where((stop) => !isEveningActivity(stop)),
    ]) {
      final priority = isPriority(candidate);
      if (addedPriority && !priority) break;
      final travel = SchedulingEngine.estimate(origin, candidate, travelMode);
      final start = SchedulingEngine.fit(
        candidate,
        transfer.travelDate,
        cursor + travel.minutes,
        dailyEndMin,
      );
      if (start == null) continue;
      stops.add(
        candidate.scheduled(
          start,
          start + candidate.visitMinutes,
          transit: travel.minutes,
          transportCost: SchedulingEngine.transportCost(travel, travelMode),
          inboundMode: travelMode,
        ),
      );
      usedIds.add(SchedulingEngine.identity(candidate));
      if (!priority) break;
      addedPriority = true;
      origin = candidate;
      cursor = start + candidate.visitMinutes;
    }

    return stops;
  }

  static String _fmt(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    final time =
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    return minutes >= 1440 ? '$time (+1 day)' : time;
  }
}
