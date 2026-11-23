import 'package:flutter/material.dart' show DateUtils;
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';
import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';
import 'package:smart_travel_planner/shared/models/weather_forecast.dart';

class TravelLeg {
  final int minutes;
  final double distanceKm;
  final bool estimated;
  const TravelLeg(this.minutes, this.distanceKm, {this.estimated = true});
}

class SchedulingEngine {
  static String identity(TravelStop stop) => stop.placeId?.isNotEmpty == true
      ? stop.placeId!
      : stop.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  static double cost(List<TravelStop> stops) =>
      stops.fold(0, (sum, s) => sum + s.estimatedCost + s.travelCost);
  static TravelLeg estimate(TravelStop from, TravelStop to, String mode) {
    final km =
        const Distance().as(
          LengthUnit.Kilometer,
          LatLng(from.latitude, from.longitude),
          LatLng(to.latitude, to.longitude),
        ) *
        1.28;
    final walking = mode == 'Walking';
    final double speed;
    if (walking) {
      speed = 4.5;
    } else if (km > 50) {
      speed = 70.0;
    } else if (km > 15) {
      speed = 45.0;
    } else {
      speed = 28.0;
    }
    return TravelLeg(
      (km / speed * 60).ceil() + (walking ? 0 : 5),
      km,
    );
  }

  static double transportCost(TravelLeg leg, String mode) =>
      mode == 'Walking' ? 0 : leg.distanceKm * 1.2;
  static int parseClock(String text) {
    final m = RegExp(
      r'(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)?',
      caseSensitive: false,
    ).firstMatch(text);
    if (m == null) throw FormatException('Invalid time', text);
    var h = int.parse(m[1]!);
    final minute = int.parse(m[2]!);
    if (m[3] != null) {
      h %= 12;
      if (m[3]!.toUpperCase() == 'PM') {
        h += 12;
      }
    }
    return h * 60 + minute;
  }

  /// Intervals in minutes on the requested local calendar day. Null = unverified.
  static List<(int, int)>? intervals(TravelStop stop, DateTime date) {
    final hours = stop.operatingHours;
    if (hours.containsKey('periods')) {
      final result = <(int, int)>[];
      final day = date.weekday % 7;
      for (final raw in hours['periods'] as List? ?? []) {
        final p = Map<String, dynamic>.from(raw as Map);
        final open = p['open'] as Map?;
        final close = p['close'] as Map?;
        if (open == null) continue;
        if (close == null) {
          result.add((0, 1440));
          continue;
        }
        final od = (open['day'] as num).toInt(),
            cd = (close['day'] as num).toInt();
        final om =
            ((open['hour'] as num?)?.toInt() ?? 0) * 60 +
            ((open['minute'] as num?)?.toInt() ?? 0);
        final cm =
            ((close['hour'] as num?)?.toInt() ?? 0) * 60 +
            ((close['minute'] as num?)?.toInt() ?? 0);
        final length = ((cd - od + 7) % 7) * 1440 + cm - om;
        for (final shift in [-7, 0]) {
          final start = (od - day + shift) * 1440 + om;
          final end = start + (length <= 0 ? 7 * 1440 : length);
          if (end > 0 && start < 1440) {
            result.add((math.max(0, start), math.min(1440, end)));
          }
        }
      }
      return result;
    }
    if (hours['open'] is String && hours['close'] is String) {
      final a = parseClock(hours['open']), b = parseClock(hours['close']);
      return b > a ? [(a, b)] : [(0, b), (a, 1440)];
    }
    final text = stop.openingHours;
    if (text.toLowerCase().contains('24 hour')) return [(0, 1440)];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final range = RegExp(
      r'(Mon|Tue|Wed|Thu|Fri|Sat|Sun)\s*-\s*(Mon|Tue|Wed|Thu|Fri|Sat|Sun)',
    ).firstMatch(text);
    if (range != null) {
      final first = weekdays.indexOf(range[1]!),
          last = weekdays.indexOf(range[2]!);
      final index = date.weekday - 1;
      if (first <= last
          ? index < first || index > last
          : index > last && index < first) {
        return [];
      }
    }
    if (text.toLowerCase().contains('closed')) return [];
    final matches = RegExp(
      r'\d{1,2}:\d{2}\s*(?:AM|PM)?',
      caseSensitive: false,
    ).allMatches(text).toList();
    if (matches.length != 2) return null;
    final a = parseClock(matches[0][0]!), b = parseClock(matches[1][0]!);
    return b > a ? [(a, b)] : [(0, b), (a, 1440)];
  }

  static int? fit(TravelStop stop, DateTime date, int arrival, int dayEnd) {
    final windows = intervals(stop, date);
    if (windows == null) return null;
    for (final window in windows..sort((a, b) => a.$1.compareTo(b.$1))) {
      final start = math.max(arrival, window.$1);
      if (start + stop.visitMinutes <= math.min(window.$2, dayEnd)) {
        return start;
      }
    }
    return null;
  }

  static bool _interestMatch(TravelStop stop, List<String> interests) {
    final text = '${stop.category} ${stop.title}'.toLowerCase();
    return interests.any((interest) {
      final key = interest.toLowerCase();
      final tokens = switch (key) {
        'culture' => [
          'cultur',
          'museum',
          'art',
          'gallery',
          'heritage',
          'architecture',
        ],
        'food' => [
          'food',
          'restaurant',
          'dining',
          'cafe',
          'hawker',
          'cuisine',
          'coffee',
          'lunch',
          'dinner',
        ],
        'nature' => [
          'nature',
          'park',
          'hill',
          'garden',
          'beach',
          'forest',
          'waterfall',
          'island',
          'scenic',
        ],
        'shopping' => ['shop', 'market', 'mall', 'store', 'bazaar', 'plaza'],
        'history' => [
          'history',
          'historic',
          'heritage',
          'fort',
          'monument',
          'memorial',
          'temple',
          'clan',
          'unesco',
        ],
        'adventure' => [
          'adventure',
          'hiking',
          'theme park',
          'escape',
          'climb',
          'trail',
          'water sport',
          'outdoor',
        ],
        'family' => [
          'family',
          'kid',
          'aquarium',
          'zoo',
          'butterfly',
          'science',
          'amusement',
          'child',
        ],
        'nightlife' => [
          'night',
          'pub',
          'bar',
          'lounge',
          'club',
          'bazaar',
          'night market',
          'evening',
        ],
        'sights' => ['sight', 'landmark', 'tower', 'attraction', 'viewpoint'],
        _ => [key],
      };
      return tokens.any(text.contains);
    });
  }

  static List<TravelStop> schedule({
    required List<TravelStop> candidates,
    required TripPreferences preferences,
    required DateTime date,
    required Set<String> visited,
    WeatherForecast? weather,
    Map<String, TravelLeg> legs = const {},
    Map<String, TravelLeg> walkingLegs = const {},
    int seed = 0,
    bool preserveOrder = false,
    TravelStop? routeAnchor,
    Set<String> previousStopIds = const {},
  }) {
    var now = TripPreferences.minutesOf(preferences.dailyStartTime) ?? 510;
    var end = TripPreferences.minutesOf(preferences.dailyEndTime) ?? 1320;
    final arrival = TripPreferences.minutesOf(preferences.arrivalTime);
    final departure = TripPreferences.minutesOf(preferences.departureTime);
    if (arrival != null && DateUtils.isSameDay(date, preferences.startDate)) {
      now = math.max(now, arrival + 60);
    }
    if (departure != null && DateUtils.isSameDay(date, preferences.endDate)) {
      end = math.min(
        end,
        departure -
            preferences.departureBufferMinutes -
            preferences.departureTransferMinutes,
      );
    }
    final pace = switch (preferences.paceCategory) {
      PaceCategory.relaxed => 3,
      PaceCategory.balanced => 4,
      PaceCategory.packed => 6,
      null => candidates.length,
    };
    final primaryMode = preferences.travelMode ?? "Driving";
    final priorities = preferences.mustVisitPlaces.map(identity).toSet();
    final selectedPlaces = preferences.selectedPlaces.map(identity).toSet();
    final dayStart = now;
    final spreadLowBudgetVisits =
        preferences.budgetCategory == 'Low' &&
        !preserveOrder &&
        end - dayStart >= 10 * 60;
    var remaining = preferences.dailyBudget;
    final requiresIndoor =
        weather?.isAvailable == true && !weather!.isSuitableForOutdoor;
    final pool = [...candidates];
    final selected = <TravelStop>[];
    final random = math.Random(seed);
    final ties = {for (final s in pool) identity(s): random.nextDouble()};
    while (pool.isNotEmpty && (preserveOrder || selected.length < pace)) {
      TravelStop? best;
      int bestStart = 0;
      int bestTravelStart = 0;
      var bestMode = primaryMode;
      TravelLeg bestLeg = const TravelLeg(0, 0);
      var bestPriority = -1;
      var bestScore = -double.infinity;
      final hasIndoorRemaining = pool.any(
        (s) =>
            !visited.contains(identity(s)) &&
            s.isIndoor == true &&
            s.visitMinutes > 0,
      );
      final enforceIndoor =
          requiresIndoor && (hasIndoorRemaining || selected.isNotEmpty);
      for (final stop in pool) {
        final stopId = identity(stop);
        if (visited.contains(stopId) ||
            stop.visitMinutes <= 0 ||
            stop.estimatedCost < 0 ||
            !stop.estimatedCost.isFinite) {
          continue;
        }
        if (enforceIndoor && stop.isIndoor != true) {
          continue;
        }
        final origin = preferences.dailyOrigin;
        final previous =
            selected.lastOrNull ??
            (origin != null && origin.latitude != 0 && origin.longitude != 0
                ? origin
                : null);
        var leg = previous == null
            ? const TravelLeg(0, 0)
            : legFor(previous, stop, preferences, legs);
        final walking = previous == null
            ? null
            : walkingLegs['${identity(previous)}>${identity(stop)}'];
        var mode = primaryMode;
        if (!preserveOrder &&
            walking != null &&
            !walking.estimated &&
            walking.minutes > 0 &&
            walking.minutes <= 15 &&
            walking.minutes <= leg.minutes + 5) {
          leg = walking;
          mode = 'Walking';
        }
        final cost = stop.estimatedCost + transportCost(leg, mode);
        if (cost > remaining) continue;
        final earliest = fit(stop, date, now + leg.minutes, end);
        if (earliest == null) continue;
        // Keep the first visit early. Aim subsequent visits at late morning,
        // afternoon and early evening while honoring each opening window.
        const offsets = [0, 150, 390, 630];
        final target = spreadLowBudgetVisits && selected.length < offsets.length
            ? dayStart + offsets[selected.length]
            : now;
        final proposedDeparture = math.max(now, target - leg.minutes);
        final later = fit(stop, date, proposedDeparture + leg.minutes, end);
        final start = later ?? earliest;
        final travelStart = later == null ? now : proposedDeparture;
        final meal = RegExp(
          r'food|restaurant|dining|lunch|dinner|cafe',
          caseSensitive: false,
        ).hasMatch('${stop.category} ${stop.title}');
        final restricted =
            preferences.dietaryPreference == DietaryPreference.halalFriendly ||
            preferences.dietaryPreference == DietaryPreference.vegetarian;
        final priority = priorities.contains(stopId)
            ? 2
            : selectedPlaces.contains(stopId)
            ? 1
            : 0;
        final userChosen = priority > 0;
        if (meal && restricted && !userChosen) continue;

        // Regional clustering guard:
        // Prevent scheduling stops that are excessively distant from the day's cluster
        // anchor or previous stop (e.g. 170 km / 2.5 hrs away) within a single day.
        final dayAnchor = selected.firstOrNull ??
            routeAnchor ??
            (origin != null && origin.latitude != 0 && origin.longitude != 0
                ? origin
                : null);
        if (!preserveOrder && !userChosen && previous != null) {
          if (leg.minutes > 60 || leg.distanceKm > 50.0) {
            continue;
          }
        }
        if (!preserveOrder && !userChosen && dayAnchor != null && selected.isNotEmpty) {
          final anchorLeg = legFor(dayAnchor, stop, preferences, legs);
          if (anchorLeg.minutes > 75 || anchorLeg.distanceKm > 55.0) {
            continue;
          }
        }

        final lunchTime = now >= 690 && now <= 840;
        final double travelPenalty = leg.minutes <= 30
            ? leg.minutes.toDouble()
            : 30.0 + (leg.minutes - 30) * 2.5;
        final score =
            (requiresIndoor && stop.isIndoor == true ? 200 : 0) +
            (routeAnchor != null && identity(stop) == identity(routeAnchor)
                ? 250
                : 0) -
            (routeAnchor != null && identity(stop) != identity(routeAnchor)
                ? math.min(
                        120,
                        legFor(routeAnchor, stop, preferences, legs).minutes,
                      ) *
                      0.6
                : 0) +
            (preferences.travelerType == TravelerType.family &&
                    _interestMatch(stop, const ['Family'])
                ? 30
                : 0) +
            (preferences.dietaryPreference == DietaryPreference.streetFood &&
                    stop.title.toLowerCase().contains('market')
                ? 40
                : 0) +
            (_interestMatch(stop, preferences.interests) ? 100.0 : 0.0) +
            (meal &&
                    lunchTime &&
                    !selected.any(
                      (s) => RegExp(
                        'food|restaurant|lunch',
                        caseSensitive: false,
                      ).hasMatch('${s.category} ${s.title}'),
                    )
                ? 150
                : 0) -
            travelPenalty -
            (!userChosen && previousStopIds.contains(stopId) ? 120 : 0) -
            (start - travelStart - leg.minutes) * 0.5 -
            (spreadLowBudgetVisits && later == null ? 120 : 0) -
            cost * (preferences.budgetCategory == 'Low' ? 3.0 : 0.15) -
            stop.visitMinutes * 0.02 +
            ties[stopId]! * 0.001;
        if (priority > bestPriority ||
            (priority == bestPriority && score > bestScore)) {
          best = stop;
          bestStart = start;
          bestTravelStart = travelStart;
          bestLeg = leg;
          bestMode = mode;
          bestPriority = priority;
          bestScore = score;
        }
        if (preserveOrder) break;
      }
      if (best == null) break;
      final travelCost = transportCost(bestLeg, bestMode);
      selected.add(
        best.scheduled(
          bestStart,
          bestStart + best.visitMinutes,
          transit: math.min(bestLeg.minutes, bestStart - bestTravelStart),
          transportCost: travelCost,
          estimated: bestLeg.estimated,
          inboundMode: bestLeg.minutes > 0 ? bestMode : null,
        ),
      );
      visited.add(identity(best));
      pool.remove(best);
      final restMinutes = preserveOrder
          ? 0
          : switch (preferences.paceCategory) {
              PaceCategory.relaxed => 15,
              PaceCategory.balanced => 10,
              PaceCategory.packed => 5,
              null => 0,
            };
      now = bestStart + best.visitMinutes + restMinutes;
      remaining -= best.estimatedCost + travelCost;
    }
    return selected;
  }

  /// Compare the usual greedy schedule with routes anchored around selected
  /// places on different days. Selected places remain preferences, not locks.
  static List<List<TravelStop>> scheduleTrip({
    required List<TravelStop> candidates,
    required TripPreferences preferences,
    required List<DateTime> dates,
    required List<WeatherForecast?> weather,
    required List<Map<String, TravelLeg>> dailyLegs,
    Map<String, TravelLeg> walkingLegs = const {},
    int seed = 0,
    Set<String> previousStopIds = const {},
  }) {
    final byId = {for (final stop in candidates) identity(stop): stop};
    final anchors = <TravelStop>[];
    final seen = <String>{};
    for (final selected in [
      ...preferences.mustVisitPlaces,
      ...preferences.selectedPlaces,
    ]) {
      final id = identity(selected);
      final candidate = byId[id];
      if (candidate != null && seen.add(id)) anchors.add(candidate);
    }

    List<List<TravelStop>> build(
      List<TravelStop> order, {
      int? firstDay,
      String? excludedSuggestion,
      Set<String> avoidRepeating = const {},
    }) {
      final visited = <String>{};
      final days = List<List<TravelStop>>.filled(dates.length, const []);
      final dayOrder = [
        ?firstDay,
        for (var day = 0; day < dates.length; day++)
          if (day != firstDay) day,
      ];
      for (final day in dayOrder) {
        final remainingAnchors = order
            .where((stop) => !visited.contains(identity(stop)))
            .toList();
        final anchor = remainingAnchors.isEmpty ? null : remainingAnchors.first;
        final deferred = <String>{};
        if (anchor != null && day != dayOrder.last) {
          for (final other in remainingAnchors.skip(1)) {
            final outbound = legFor(anchor, other, preferences, dailyLegs[day]);
            final inbound = legFor(other, anchor, preferences, dailyLegs[day]);
            if (math.min(outbound.minutes, inbound.minutes) > 30) {
              deferred.add(identity(other));
            }
          }
          final futureAnchors = remainingAnchors
              .where((stop) => deferred.contains(identity(stop)))
              .toList();
          for (final stop in candidates) {
            if (identity(stop) == identity(anchor)) continue;
            final here = legFor(
              anchor,
              stop,
              preferences,
              dailyLegs[day],
            ).minutes;
            if (futureAnchors.any(
              (future) =>
                  legFor(future, stop, preferences, dailyLegs[day]).minutes +
                      30 <
                  here,
            )) {
              deferred.add(identity(stop));
            }
          }
        }
        days[day] = schedule(
          candidates: candidates
              .where((stop) {
                final id = identity(stop);
                return id != excludedSuggestion && !deferred.contains(id);
              })
              .toList(),
          preferences: preferences,
          date: dates[day],
          visited: visited,
          weather: weather[day],
          legs: dailyLegs[day],
          walkingLegs: walkingLegs,
          seed: seed + day,
          routeAnchor: anchor,
          previousStopIds: avoidRepeating,
        );
      }
      return days;
    }

    List<TravelStop> refitDay(int day, List<TravelStop> stops) => schedule(
      candidates: stops,
      preferences: preferences,
      date: dates[day],
      visited: <String>{},
      weather: weather[day],
      legs: dailyLegs[day],
      walkingLegs: walkingLegs,
      seed: seed + day,
    );

    int travelMinutes(List<TravelStop> stops) =>
        stops.fold(0, (sum, stop) => sum + stop.travelMinutes);

    // Refit both routes before moving a visit. Keep every scheduled place and
    // leave the day it came from with at least two visits.
    void balanceSingleVisitDays(List<List<TravelStop>> days) {
      for (var day = 0; day < days.length; day++) {
        if (days[day].length != 1) continue;
        ({
          int donor,
          List<TravelStop> filledDay,
          List<TravelStop> remaining,
          int extraTravel,
        })?
        bestMove;
        for (var donor = 0; donor < days.length; donor++) {
          final donorStops = days[donor];
          if (donorStops.length < 3) continue;
          for (final stop in donorStops) {
            final filledDay = refitDay(day, [...days[day], stop]);
            if (filledDay.length != 2) continue;
            final remaining = refitDay(donor, [
              for (final other in donorStops)
                if (other != stop) other,
            ]);
            if (remaining.length != donorStops.length - 1) continue;
            final extraTravel =
                travelMinutes(filledDay) +
                travelMinutes(remaining) -
                travelMinutes(days[day]) -
                travelMinutes(donorStops);
            if (bestMove == null || extraTravel < bestMove.extraTravel) {
              bestMove = (
                donor: donor,
                filledDay: filledDay,
                remaining: remaining,
                extraTravel: extraTravel,
              );
            }
          }
        }
        if (bestMove != null) {
          days[day] = bestMove.filledDay;
          days[bestMove.donor] = bestMove.remaining;
        }
      }
    }

    var best = build(const []);
    var bestOrder = <TravelStop>[];
    int covered(List<List<TravelStop>> days) => days
        .expand((day) => day)
        .map(identity)
        .where(seen.contains)
        .toSet()
        .length;
    final mustVisit = preferences.mustVisitPlaces.map(identity).toSet();
    int coveredMustVisits(List<List<TravelStop>> days) => days
        .expand((day) => day)
        .map(identity)
        .where(mustVisit.contains)
        .toSet()
        .length;
    int routeCost(List<List<TravelStop>> days) {
      final stops = days.expand((day) => day).toList();
      // Keep useful visits while preferring shorter trips between stops.
      return travelMinutes(stops) - stops.length * 25;
    }

    final limit = dates.length < 2 || anchors.length < 2
        ? 0
        : math.min(anchors.length, 6);
    for (var start = 0; start < limit; start++) {
      final order = [...anchors.skip(start), ...anchors.take(start)];
      for (final option in [order, order.reversed.toList()]) {
        final candidate = build(option);
        if (coveredMustVisits(candidate) > coveredMustVisits(best) ||
            (coveredMustVisits(candidate) == coveredMustVisits(best) &&
                (covered(candidate) > covered(best) ||
                    (covered(candidate) == covered(best) &&
                        routeCost(candidate) < routeCost(best))))) {
          best = candidate;
          bestOrder = option;
        }
      }
    }
    balanceSingleVisitDays(best);

    Set<String> stopIds(List<List<TravelStop>> days) =>
        days.expand((day) => day).map(identity).toSet();
    int sparseDays(List<List<TravelStop>> days) =>
        days.where((day) => day.length < 2).length;
    int emptyDays(List<List<TravelStop>> days) =>
        days.where((day) => day.isEmpty).length;
    bool preservesCoverage(
      List<List<TravelStop>> candidate, {
      int allowedVisitLoss = 0,
    }) {
      final current = stopIds(best);
      final replacement = stopIds(candidate);
      return replacement.length >= current.length - allowedVisitLoss &&
          replacement.containsAll(current.intersection(seen)) &&
          emptyDays(candidate) <= emptyDays(best);
    }

    // Give a constrained day first choice of the candidate pool if moving an
    // individual visit could not fill it. If a suggested stop isolates that
    // day, try a nearby cluster even if the trip loses one optional visit.
    int? priorityDay;
    String? excludedSuggestion;
    for (var day = 0; day < dates.length; day++) {
      if (best[day].length != 1) continue;
      final isolatedStopId = identity(best[day].single);
      for (final excluded in [
        if (day > 0) null,
        if (!seen.contains(isolatedStopId)) isolatedStopId,
      ]) {
        final candidate = build(
          bestOrder,
          firstDay: day,
          excludedSuggestion: excluded,
        );
        balanceSingleVisitDays(candidate);
        if (candidate[day].length >= 2 &&
            sparseDays(candidate) < sparseDays(best) &&
            preservesCoverage(
              candidate,
              allowedVisitLoss: excluded == null ? 0 : 1,
            )) {
          best = candidate;
          priorityDay = day;
          excludedSuggestion = excluded;
          break;
        }
      }
    }

    if (previousStopIds.isNotEmpty) {
      final alternative = build(
        bestOrder,
        firstDay: priorityDay,
        excludedSuggestion: excludedSuggestion,
        avoidRepeating: previousStopIds,
      );
      balanceSingleVisitDays(alternative);
      final earlierSuggestions = previousStopIds.difference(seen);
      if (preservesCoverage(alternative) &&
          sparseDays(alternative) <= sparseDays(best) &&
          stopIds(alternative).intersection(earlierSuggestions).length <
              stopIds(best).intersection(earlierSuggestions).length) {
        best = alternative;
      }
    }
    return best;
  }

  static TravelLeg legFor(
    TravelStop from,
    TravelStop to,
    TripPreferences preferences,
    Map<String, TravelLeg> legs,
  ) {
    final mode = preferences.travelMode ?? 'Driving';
    final known = legs['${identity(from)}>${identity(to)}'];
    if (known != null) return known;
    if (from.latitude == to.latitude && from.longitude == to.longitude) {
      return const TravelLeg(0, 0, estimated: false);
    }
    if (mode == 'Public Transport') {
      return TravelLeg(preferences.transitPlanningMinutes ?? 1440, 0);
    }
    return estimate(from, to, mode);
  }
}
