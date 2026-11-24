import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/services/scheduling_engine.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';
import 'package:smart_travel_planner/shared/models/weather_forecast.dart';

TravelStop place(
  String name,
  double longitude, {
  String hours = 'Open 24 hours',
  bool? isIndoor,
}) => TravelStop.fromJson({
  'title': name,
  'place_id': name,
  'latitude': 1.5,
  'longitude': longitude,
  'visit_minutes': 60,
  'opening_hours': hours,
  'estimated_cost': 0,
  'is_indoor': isIndoor,
});

void main() {
  final date = DateTime(2026, 12, 7);
  test('can trade one suggested visit to fill an isolated storm day', () {
    final dates = [
      for (var day = 0; day < 3; day++) date.add(Duration(days: day)),
    ];
    final chosen = place(
      'Selected park',
      103.5,
      hours: 'Wed - Wed, 9:00 AM - 5:00 PM',
      isIndoor: false,
    );
    final days = SchedulingEngine.scheduleTrip(
      candidates: [
        for (var index = 0; index < 4; index++)
          place(
            'Monday visit $index',
            103.5 + index * 0.001,
            hours: 'Mon - Mon, 9:00 AM - 5:00 PM',
          ),
        place(
          'Mersing Museum',
          104.4,
          hours: 'Tue - Tue, 9:00 AM - 5:00 PM',
          isIndoor: true,
        ),
        for (var index = 0; index < 2; index++)
          place(
            'Indoor hall $index',
            103.5 + index * 0.001,
            hours: 'Tue - Wed, 9:00 AM - 5:00 PM',
            isIndoor: true,
          ),
        chosen,
        place(
          'Another park',
          103.503,
          hours: 'Wed - Wed, 9:00 AM - 5:00 PM',
          isIndoor: false,
        ),
      ],
      preferences: TripPreferences(
        selectedPlaces: [chosen],
        interests: const ['Culture'],
        paceCategory: PaceCategory.balanced,
      ),
      dates: dates,
      weather: [
        null,
        WeatherForecast(
          itineraryId: 'test',
          locationState: 'Johor',
          scheduleDate: dates[1],
          condition: 'Heavy thunderstorm',
          rainProbability: 95,
        ),
        null,
      ],
      dailyLegs: [{}, {}, {}],
    );

    expect(days.map((day) => day.length), orderedEquals([4, 2, 2]));
    expect(days[1].every((stop) => stop.isIndoor == true), isTrue);
    expect(days.last.map((stop) => stop.placeId), contains(chosen.placeId));
  });

  test('schedules an outdoor must-visit when every day has rain', () {
    final chosen = place('Selected park', 103.5, isIndoor: false);
    final days = SchedulingEngine.scheduleTrip(
      candidates: [chosen, place('Indoor museum', 103.501, isIndoor: true)],
      preferences: TripPreferences(mustVisitPlaces: [chosen]),
      dates: [date],
      weather: [WeatherForecast(
        itineraryId: 'test', locationState: 'Johor', scheduleDate: date,
        condition: 'Rain', rainProbability: 80,
      )],
      dailyLegs: [{}],
    );
    expect(days.single.map((stop) => stop.placeId), contains(chosen.placeId));
  });

  test('regeneration rotates suggestions and preserves chosen stops', () {
    final required = place('Must-visit museum', 103.5);
    final chosen = place('Selected gallery', 103.501);
    final candidates = [
      required,
      chosen,
      place('Park A', 103.502),
      place('Park B', 103.503),
    ];

    List<TravelStop> plan({Set<String> previousStopIds = const {}}) =>
        SchedulingEngine.scheduleTrip(
          candidates: candidates,
          preferences: TripPreferences(
            mustVisitPlaces: [required],
            selectedPlaces: [chosen],
            paceCategory: PaceCategory.relaxed,
          ),
          dates: [date],
          weather: [null],
          dailyLegs: [{}],
          previousStopIds: previousStopIds,
        ).single;

    final original = plan().map(SchedulingEngine.identity).toSet();
    final regenerated = plan(
      previousStopIds: original,
    ).map(SchedulingEngine.identity).toSet();
    expect(regenerated, containsAll([required.placeId, chosen.placeId]));
    expect(regenerated, hasLength(original.length));
    expect(regenerated.difference(original), hasLength(1));
  });

  test('replans an isolated storm day around a feasible indoor cluster', () {
    final stormDate = date.add(const Duration(days: 1));
    final days = SchedulingEngine.scheduleTrip(
      candidates: [
        for (var index = 0; index < 4; index++) ...[
          place('Museum $index', 103.5 + index * 0.001, isIndoor: true),
          place('Park $index', 103.5 + index * 0.001, isIndoor: false),
        ],
        place(
          'Remote gallery',
          104.4,
          hours: 'Tue - Tue, 9:00 AM - 5:00 PM',
          isIndoor: true,
        ),
      ],
      preferences: const TripPreferences(
        interests: ['Culture'],
        paceCategory: PaceCategory.balanced,
      ),
      dates: [date, stormDate],
      weather: [
        null,
        WeatherForecast(
          itineraryId: 'test',
          locationState: 'Johor',
          scheduleDate: stormDate,
          condition: 'Heavy thunderstorm',
          rainProbability: 95,
        ),
      ],
      dailyLegs: [{}, {}],
    );

    expect(days.map((stops) => stops.length), orderedEquals([4, 4]));
    expect(days.last.map((stop) => stop.isIndoor), everyElement(isTrue));
  });

  test('uses the selected visit when a suggested lunch would crowd it out', () {
    final chosen = place('Chosen gallery', 103.5, hours: '1:00 PM - 2:00 PM');
    final suggestion = place('Lunch spot', 103.51);

    final days = SchedulingEngine.scheduleTrip(
      candidates: [suggestion, chosen],
      preferences: TripPreferences(
        selectedPlaces: [chosen],
        dailyStartTime: const TimeOfDay(hour: 12, minute: 0),
        dailyEndTime: const TimeOfDay(hour: 14, minute: 0),
      ),
      dates: [date],
      weather: [null],
      dailyLegs: [{}],
    );

    expect(days.single.single.placeId, chosen.placeId);
    expect(days.single.single.time, '01:00 PM - 02:00 PM');
  });

  test('moves a nearby indoor visit to an underfilled storm day', () {
    final dates = [
      for (var day = 0; day < 3; day++) date.add(Duration(days: day)),
    ];
    final candidates = [
      for (var index = 0; index < 7; index++)
        place('Museum $index', 103.5 + index * 0.001, isIndoor: true),
    ];

    final days = SchedulingEngine.scheduleTrip(
      candidates: candidates,
      preferences: const TripPreferences(paceCategory: PaceCategory.relaxed),
      dates: dates,
      weather: [
        null,
        null,
        WeatherForecast(
          itineraryId: 'test',
          locationState: 'Johor',
          scheduleDate: dates.last,
          condition: 'Heavy thunderstorm',
          rainProbability: 95,
        ),
      ],
      dailyLegs: [{}, {}, {}],
    );

    expect(
      days.map((stops) => stops.length),
      everyElement(greaterThanOrEqualTo(2)),
    );
    expect(
      days.expand((stops) => stops).map((stop) => stop.placeId),
      unorderedEquals(candidates.map((stop) => stop.placeId)),
    );
    expect(days.last.map((stop) => stop.isIndoor), everyElement(isTrue));
  });

  test('keeps a one-stop storm day when only outdoor visits can move', () {
    final stormDate = date.add(const Duration(days: 1));
    final museum = place(
      'Fishermen Museum',
      103.5,
      hours: 'Tue - Tue, 9:00 AM - 5:00 PM',
      isIndoor: true,
    );
    final days = SchedulingEngine.scheduleTrip(
      candidates: [
        museum,
        for (var index = 0; index < 3; index++)
          place('Park $index', 103.5 + index * 0.001, isIndoor: false),
      ],
      preferences: const TripPreferences(paceCategory: PaceCategory.relaxed),
      dates: [date, stormDate],
      weather: [
        null,
        WeatherForecast(
          itineraryId: 'test',
          locationState: 'Johor',
          scheduleDate: stormDate,
          condition: 'Heavy thunderstorm',
          rainProbability: 95,
        ),
      ],
      dailyLegs: [{}, {}],
    );

    expect(days.first, hasLength(3));
    expect(days.last.single.placeId, museum.placeId);
  });

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

  test('estimate scales driving speed appropriately for short vs inter-district trips', () {
    final start = place('Start', 103.5);
    // Short city distance (~1.1 km)
    final nearby = TravelStop.fromJson({
      ...place('Nearby', 103.51).toJson(),
      'latitude': 1.5,
      'longitude': 103.51,
    });
    // Far inter-district distance (~130 km)
    final distant = TravelStop.fromJson({
      ...place('Distant', 103.75).toJson(),
      'latitude': 2.64,
      'longitude': 103.75,
    });

    final shortLeg = SchedulingEngine.estimate(start, nearby, 'Driving');
    final longLeg = SchedulingEngine.estimate(start, distant, 'Driving');

    // Short trip uses urban speed (28 km/h)
    expect(shortLeg.distanceKm, lessThan(5.0));
    expect(shortLeg.minutes, lessThan(15));

    // Long inter-district trip uses highway speed (70 km/h) instead of being bloated by 28 km/h
    expect(longLeg.distanceKm, greaterThan(100.0));
    // At 70 km/h with 1.28 factor, ~166 km takes ~145-160 min, NOT 359 min
    expect(longLeg.minutes, lessThan(180));
    expect(longLeg.minutes, greaterThan(100));
  });

  test('schedule penalizes distant stops to prioritize nearby clusters', () {
    final origin = place('Origin', 103.5);
    final closeCandidate = place('Close Place', 103.52);
    final farCandidate = TravelStop.fromJson({
      ...place('Far Place', 104.5).toJson(),
      'latitude': 2.5,
      'longitude': 104.5,
    });

    final prefs = TripPreferences(
      numberOfDays: 1,
      departurePoint: origin,
      dailyStartTime: const TimeOfDay(hour: 9, minute: 0),
      dailyEndTime: const TimeOfDay(hour: 18, minute: 0),
      paceCategory: PaceCategory.relaxed,
    );

    final scheduled = SchedulingEngine.schedule(
      candidates: [farCandidate, closeCandidate],
      preferences: prefs,
      date: date,
      visited: <String>{},
      routeAnchor: origin,
    );

    // The close place should be picked before the far place
    expect(scheduled.first.title, equals('Close Place'));
  });

  test('schedule skips cross-district stops exceeding max allowable leg transit for single day', () {
    final jbFirst = place('JB Mosque', 103.75);
    final jbSecond = place('JB Heritage Street', 103.76);
    final mersingStop = TravelStop.fromJson({
      ...place('Mersing Beach', 103.83).toJson(),
      'latitude': 2.43,
      'longitude': 103.83,
    });

    final prefs = TripPreferences(
      numberOfDays: 1,
      dailyStartTime: const TimeOfDay(hour: 9, minute: 0),
      dailyEndTime: const TimeOfDay(hour: 22, minute: 0),
      paceCategory: PaceCategory.balanced,
    );

    final scheduled = SchedulingEngine.schedule(
      candidates: [jbFirst, mersingStop, jbSecond],
      preferences: prefs,
      date: date,
      visited: <String>{},
      routeAnchor: jbFirst,
    );

    final titles = scheduled.map((s) => s.title).toList();
    expect(titles, contains('JB Mosque'));
    expect(titles, contains('JB Heritage Street'));
    expect(titles, isNot(contains('Mersing Beach')));
  });
}
