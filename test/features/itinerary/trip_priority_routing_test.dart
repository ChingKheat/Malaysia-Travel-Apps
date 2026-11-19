import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/services/scheduling_engine.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';

TravelStop place(
  String name,
  double longitude, {
  String hours = 'Open 24 hours',
}) => TravelStop.fromJson({
  'title': name,
  'place_id': name,
  'latitude': 1.5,
  'longitude': longitude,
  'visit_minutes': 60,
  'opening_hours': hours,
  'estimated_cost': 0,
});

void main() {
  final date = DateTime(2026, 12, 7);
  test(
    'distant selected places are grouped with nearby visits on different days',
    () {
      final west = place('West priority', 103.5),
          east = place('East priority', 103.9);
      final westNearby = place('West museum', 103.51),
          eastNearby = place('East museum', 103.91);
      final candidates = [west, east, westNearby, eastNearby];
      final legs = <String, TravelLeg>{};
      for (final a in candidates) {
        for (final b in candidates) {
          if (a == b) continue;
          final minutes = (a.longitude - b.longitude).abs() < 0.1 ? 5 : 90;
          legs['${SchedulingEngine.identity(a)}>${SchedulingEngine.identity(b)}'] =
              TravelLeg(minutes, 0, estimated: false);
        }
      }
      final preferences = TripPreferences(
        startDate: date,
        endDate: date.add(const Duration(days: 1)),
        numberOfDays: 2,
        dailyStartTime: const TimeOfDay(hour: 9, minute: 0),
        dailyEndTime: const TimeOfDay(hour: 18, minute: 0),
        paceCategory: PaceCategory.balanced,
        selectedPlaces: [west, east],
      );
      final days = SchedulingEngine.scheduleTrip(
        candidates: candidates,
        preferences: preferences,
        dates: [date, date.add(const Duration(days: 1))],
        weather: [null, null],
        dailyLegs: [legs, legs],
      );
      final first = days[0].map((s) => s.title).toSet();
      final second = days[1].map((s) => s.title).toSet();
      expect(
        first.contains('West priority') && second.contains('East priority') ||
            first.contains('East priority') && second.contains('West priority'),
        isTrue,
      );
      expect(
        days
            .expand((day) => day)
            .fold<int>(0, (sum, s) => sum + s.travelMinutes),
        lessThanOrEqualTo(10),
      );
    },
  );
  test(
    'nearby priorities can share a day and missing priorities are not forced',
    () {
      final first = place('First', 103.5), second = place('Second', 103.51);
      final closed = TravelStop.fromJson({
        ...place('Closed', 103.52).toJson(),
        'operating_hours': {'periods': <Object>[]},
      });
      final prefs = TripPreferences(
        numberOfDays: 1,
        selectedPlaces: [first, second, closed],
        dailyStartTime: const TimeOfDay(hour: 9, minute: 0),
        dailyEndTime: const TimeOfDay(hour: 18, minute: 0),
      );
      final days = SchedulingEngine.scheduleTrip(
        candidates: [first, second, closed],
        preferences: prefs,
        dates: [date],
        weather: [null],
        dailyLegs: [{}],
      );
      expect(days.single.map((s) => s.title), containsAll(['First', 'Second']));
      expect(days.single.map((s) => s.title), isNot(contains('Closed')));
    },
  );
}
