import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';
import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';
import 'package:smart_travel_planner/shared/models/weather_forecast.dart';
import 'package:smart_travel_planner/features/places/services/place_classifier.dart';

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
    return TravelLeg(
      (km / (walking ? 4.5 : 28) * 60).ceil() + (walking ? 0 : 5),
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
    final windows = intervals(stop, date) ?? [(0, 1440)];
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
    int seed = 0,
    bool preserveOrder = false,
  }) {
    var now =
        (preferences.dailyStartTime?.hour ?? 8) * 60 +
        (preferences.dailyStartTime?.minute ?? 30);
    final end =
        (preferences.dailyEndTime?.hour ?? 22) * 60 +
        (preferences.dailyEndTime?.minute ?? 0);
    final dayStart = now;
    final spreadLowBudgetVisits =
        preferences.budgetCategory == 'Low' &&
        !preserveOrder &&
        end - dayStart >= 10 * 60;
    var remaining = preferences.dailyBudget;
    final pool = [...candidates];
    final selected = <TravelStop>[];
    final random = math.Random(seed);
    final ties = {for (final s in pool) identity(s): random.nextDouble()};
    while (pool.isNotEmpty) {
      TravelStop? best;
      int bestStart = 0;
      int bestTravelStart = 0;
      TravelLeg bestLeg = const TravelLeg(0, 0);
      var bestScore = -double.infinity;
      for (final stop in pool) {
        if (visited.contains(identity(stop)) ||
            stop.visitMinutes <= 0 ||
            stop.estimatedCost < 0 ||
            !stop.estimatedCost.isFinite) {
          continue;
        }
        final indoor =
            stop.isIndoor ??
            PlaceClassifier.classify(category: stop.category, name: stop.title);
        if (weather?.isAvailable == true &&
            !weather!.isSuitableForOutdoor &&
            indoor == false) {
          continue;
        }
        final previous = selected.lastOrNull ?? preferences.departurePoint;
        final leg = previous == null
            ? const TravelLeg(0, 0)
            : legFor(previous, stop, preferences, legs);
        final cost =
            stop.estimatedCost +
            transportCost(leg, preferences.travelMode ?? 'Driving');
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
        final lunchTime = now >= 690 && now <= 840;
        final score =
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
                : 0) +
            (weather?.isAvailable == true &&
                    !weather!.isSuitableForOutdoor &&
                    indoor == true
                ? 100
                : 0) -
            leg.minutes -
            (start - travelStart - leg.minutes) * 0.5 -
            (spreadLowBudgetVisits && later == null ? 120 : 0) -
            cost * (preferences.budgetCategory == 'Low' ? 3.0 : 0.15) -
            stop.visitMinutes * 0.02 +
            ties[identity(stop)]! * 0.001;
        if (score > bestScore) {
          best = stop;
          bestStart = start;
          bestTravelStart = travelStart;
          bestLeg = leg;
          bestScore = score;
        }
        if (preserveOrder) break;
      }
      if (best == null) break;
      final travelCost = transportCost(
        bestLeg,
        preferences.travelMode ?? 'Driving',
      );
      selected.add(
        best.scheduled(
          bestStart,
          bestStart + best.visitMinutes,
          transit: math.min(bestLeg.minutes, bestStart - bestTravelStart),
          transportCost: travelCost,
          estimated: bestLeg.estimated,
        ),
      );
      visited.add(identity(best));
      pool.remove(best);
      now = bestStart + best.visitMinutes;
      remaining -= best.estimatedCost + travelCost;
    }
    return selected;
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
