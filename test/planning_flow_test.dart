import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/models/itinerary_models.dart';
import 'package:smart_travel_planner/models/travel_stop.dart';
import 'package:smart_travel_planner/models/trip_preferences.dart';
import 'package:smart_travel_planner/models/weather_forecast.dart';
import 'package:smart_travel_planner/services/auth_service.dart';
import 'package:smart_travel_planner/services/local_itinerary_store.dart';
import 'package:smart_travel_planner/services/itinerary_cloud.dart';
import 'package:smart_travel_planner/services/scheduling_engine.dart';
import 'package:smart_travel_planner/services/smart_itinerary_service.dart';
import 'package:smart_travel_planner/services/supabase_itinerary_service.dart';
import 'package:smart_travel_planner/services/trip_preferences_service.dart';
import 'package:smart_travel_planner/services/weather_service.dart';
import 'package:smart_travel_planner/services/travel_matrix_service.dart';

TravelStop place(
  String id, {
  String category = 'Culture',
  double cost = 20,
  int visit = 60,
  double lat = 3.15,
  double lng = 101.71,
  bool? indoor,
  Map<String, dynamic> hours = const {'open': '09:00', 'close': '18:00'},
}) => TravelStop(
  title: id,
  time: '09:00 AM - 10:00 AM',
  note: 'Test venue',
  description: 'Venue',
  duration: '$visit min',
  openingHours: 'Hours unverified',
  tips: const [],
  icon: Icons.place,
  color: Colors.blue,
  placeId: id,
  category: category,
  estimatedCost: cost,
  visitMinutes: visit,
  latitude: lat,
  longitude: lng,
  isIndoor: indoor,
  operatingHours: hours,
);

TripPreferences prefs({
  String interest = 'Culture',
  String mode = 'Walking',
  String budget = 'Low',
  int end = 18,
}) => TripPreferences(
  destination: 'Kuala Lumpur',
  startDate: DateTime(2026, 10, 20),
  endDate: DateTime(2026, 10, 22),
  dailyStartTime: const TimeOfDay(hour: 9, minute: 0),
  dailyEndTime: TimeOfDay(hour: end, minute: 0),
  interests: [interest],
  travelMode: mode,
  budgetCategory: budget,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SmartItineraryService.clearLiveCache();
  });
  test(
    'Offline retry after a lost cloud response keeps one trip; deletion survives restart',
    () async {
      await AuthService().login('tourist@example.com', 'SafeP@ss123!');
      final cloud = _FakeCloud();
      final service = SupabaseItineraryService.withStore(
        LocalItineraryStore(),
        cloud: cloud,
      );
      final result = await service.saveItinerary(
        title: 'Retry trip',
        destinationState: 'Kuala Lumpur',
        totalCost: 0,
        dailySchedules: [],
      );
      expect(result.synced, isFalse);
      cloud.online = true;
      cloud.loseNextResponse = true;
      await service.syncPending();
      var journal = await LocalItineraryStore().read(
        AuthService().currentUser!.uid,
      );
      expect(journal[result.itineraryId]['pending'], isTrue);
      await service.syncPending();
      journal = await LocalItineraryStore().read(
        AuthService().currentUser!.uid,
      );
      expect(journal[result.itineraryId]['pending'], isFalse);
      expect(cloud.rows.length, 1);
      expect(cloud.saves, 2);
      cloud.online = false;
      expect(await service.deleteItinerary(result.itineraryId!), isTrue);
      final restarted = SupabaseItineraryService.withStore(
        LocalItineraryStore(),
        cloud: cloud,
      );
      expect(await restarted.getSavedItineraries(refresh: false), isEmpty);
      cloud.online = true;
      await restarted.syncPending();
      expect(cloud.rows, isEmpty);
      expect(
        await LocalItineraryStore().read(AuthService().currentUser!.uid),
        isEmpty,
      );
    },
  );
  test('Concurrent saves do not overwrite another local trip', () async {
    await AuthService().login('tourist@example.com', 'SafeP@ss123!');
    final service = SupabaseItineraryService.withStore(LocalItineraryStore());
    await Future.wait([
      for (var i = 0; i < 3; i++)
        service.saveItinerary(
          title: 'Trip $i',
          destinationState: 'Kuala Lumpur',
          totalCost: 0,
          dailySchedules: [],
        ),
    ]);
    expect((await service.getSavedItineraries(refresh: false)).length, 3);
  });
  test(
    'Cloud nested rows retain complete stop payloads when another day is edited',
    () async {
      await AuthService().login('tourist@example.com', 'SafeP@ss123!');
      final uid = AuthService().currentUser!.uid;
      final cloud = _FakeCloud()..online = true;
      cloud.rows['remote'] = {
        'itinerary_id': 'remote',
        'user_id': uid,
        'title': 'Cloud trip',
        'destination_state': 'Kuala Lumpur',
        'created_at': '2026-10-18',
        'total_cost': 80,
        'daily_schedules': [
          for (var i = 1; i <= 2; i++)
            {
              'schedule_id': 'day$i',
              'itinerary_id': 'remote',
              'day_number': i,
              'schedule_date': '2026-11-0$i',
              'itinerary_stops': [
                {
                  'id': 'stop$i',
                  'place_id': 'venue$i',
                  'stop_order': 1,
                  'arrival_time': '09:00:00',
                  'departure_time': '10:00:00',
                  'places': {
                    'name': 'Museum $i',
                    'category': 'Culture',
                    'latitude': 3.15,
                    'longitude': 101.71,
                  },
                },
              ],
            },
        ],
      };
      final service = SupabaseItineraryService.withStore(
        LocalItineraryStore(),
        cloud: cloud,
      );
      await service.syncPending();
      expect(
        await service.updateDailyScheduleStops(
          scheduleId: 'day1',
          totalDistanceKm: 0,
          stops: [],
        ),
        isTrue,
      );
      final second = (cloud.rows['remote']!['daily_schedules'] as List)[1];
      final stop = (second['itinerary_stops'] as List).single;
      expect(stop['place_name'], 'Museum 2');
      expect(stop['latitude'], 3.15);
      expect(stop['snapshot']['estimated_cost'], 40);
    },
  );
  test(
    'Route matrix parses directed durations, preserves unreachable routes, and falls back on failure',
    () async {
      final candidates = [place('a'), place('b')];
      final matrix = TravelMatrixService(
        accessToken: 'test',
        client: MockClient((request) async {
          expect(request.url.host, 'yavslytukzgphvaqspcq.supabase.co');
          expect(jsonDecode(request.body)['operation'], 'matrix');
          expect(jsonDecode(request.body)['mode'], 'Walking');
          expect(request.headers.containsKey('X-Goog-Api-Key'), false);
          return http.Response(
            jsonEncode([
              {
                'originIndex': 0,
                'destinationIndex': 1,
                'condition': 'ROUTE_EXISTS',
                'duration': '125s',
                'distanceMeters': 1000,
              },
              {
                'originIndex': 1,
                'destinationIndex': 0,
                'condition': 'ROUTE_NOT_FOUND',
              },
            ]),
            200,
          );
        }),
      );
      final legs = await matrix.fetch(candidates, 'Walking');
      expect(legs['a>b']!.minutes, 3);
      expect(legs['a>b']!.estimated, isFalse);
      expect(legs['b>a']!.minutes, greaterThan(1440));
      final offline = TravelMatrixService(
        accessToken: 'test',
        client: MockClient((_) async => throw StateError('Offline')),
      );
      expect(await offline.fetch(candidates, 'Driving'), isEmpty);
    },
  );
  test(
    'Unsupported offline destinations never receive Kuala Lumpur attractions',
    () {
      final stops = SmartItineraryService.generateDailyStops(
        preferences: prefs().copyWith(destination: 'Perlis'),
        dayIndex: 0,
      );
      expect(stops, isEmpty);
    },
  );
  test(
    'Calendar dates survive serialization, month boundary, leap day, and one-day trips',
    () {
      final p = prefs().copyWith(
        startDate: DateTime(2028, 2, 28),
        endDate: DateTime(2028, 3, 1),
      );
      expect(p.numberOfDays, 3);
      expect(p.dateForDay(1), DateTime(2028, 2, 29));
      expect(
        TripPreferences.fromJson(
          jsonDecode(jsonEncode(p.toJson())),
        ).dateForDay(2),
        DateTime(2028, 3, 1),
      );
      expect(p.copyWith(endDate: DateTime(2028, 2, 28)).numberOfDays, 1);
      expect(
        TripPreferencesService.validatePreferences(
          p.copyWith(endDate: DateTime(2028, 2, 27)),
        ).success,
        isFalse,
      );
    },
  );
  test('Interest choice changes the first selected place', () {
    final candidates = [place('museum'), place('mall', category: 'Shopping')];
    final a = SchedulingEngine.schedule(
      candidates: candidates,
      preferences: prefs(),
      date: DateTime(2026, 10, 20),
      visited: {},
    );
    final b = SchedulingEngine.schedule(
      candidates: candidates,
      preferences: prefs(interest: 'Shopping'),
      date: DateTime(2026, 10, 20),
      visited: {},
    );
    expect(a.first.title, 'museum');
    expect(b.first.title, 'mall');
  });
  test('Waits until opening and excludes visits ending after closure', () {
    final result = SchedulingEngine.schedule(
      candidates: [
        place('late', hours: {'open': '10:00', 'close': '12:00'}),
        place('too-short', hours: {'open': '10:00', 'close': '10:30'}),
      ],
      preferences: prefs(),
      date: DateTime(2026, 10, 20),
      visited: {},
    );
    expect(result.map((s) => s.title), ['late']);
    expect(result.first.time.startsWith('10:00 AM'), isTrue);
  });
  test(
    'Weekly closure, split hours, and overnight spill use the selected date',
    () {
      final s = place(
        'weekly',
        hours: {
          'periods': [
            {
              'open': {'day': 2, 'hour': 22},
              'close': {'day': 3, 'hour': 2},
            },
            {
              'open': {'day': 3, 'hour': 10},
              'close': {'day': 3, 'hour': 12},
            },
            {
              'open': {'day': 3, 'hour': 14},
              'close': {'day': 3, 'hour': 18},
            },
          ],
        },
      );
      expect(
        SchedulingEngine.intervals(s, DateTime(2026, 10, 21)),
        containsAll([(0, 120), (600, 720), (840, 1080)]),
      );
      expect(SchedulingEngine.intervals(s, DateTime(2026, 10, 22)), isEmpty);
    },
  );
  test('Budget includes travel estimates and daily end time is enforced', () {
    final stops = SchedulingEngine.schedule(
      candidates: [place('a', cost: 90), place('b', cost: 90)],
      preferences: prefs(mode: 'Driving', end: 11),
      date: DateTime(2026, 10, 20),
      visited: {},
    );
    expect(stops.length, 1);
    expect(SchedulingEngine.cost(stops), lessThanOrEqualTo(120));
    expect(
      SchedulingEngine.parseClock(stops.last.time.split('-').last),
      lessThanOrEqualTo(660),
    );
  });
  test('Long walking travel excludes an infeasible next stop', () {
    final stops = SchedulingEngine.schedule(
      candidates: [place('a'), place('b', lat: 3.8)],
      preferences: prefs(end: 12),
      date: DateTime(2026, 10, 20),
      visited: {},
      preserveOrder: true,
    );
    expect(stops.length, 1);
  });
  test('Uses provided route durations rather than a fixed transit buffer', () {
    final stops = SchedulingEngine.schedule(
      candidates: [place('a'), place('b')],
      preferences: prefs(),
      date: DateTime(2026, 10, 20),
      visited: {},
      preserveOrder: true,
      legs: {'a>b': const TravelLeg(47, 2, estimated: false)},
    );
    expect(stops.last.travelMinutes, 47);
    expect(stops.last.travelIsEstimated, isFalse);
    expect(stops.last.time.startsWith('10:47 AM'), isTrue);
  });
  test(
    'Heavy rain excludes outdoor places and retains indoor alternatives',
    () {
      final stops = SchedulingEngine.schedule(
        candidates: [
          place('park', indoor: false),
          place('museum', indoor: true),
        ],
        preferences: prefs(),
        date: DateTime(2026, 10, 20),
        visited: {},
        weather: WeatherForecast(
          itineraryId: '',
          locationState: 'Kuala Lumpur',
          scheduleDate: DateTime(2026, 10, 20),
          condition: 'Thunderstorm',
          rainProbability: 90,
        ),
      );
      expect(stops.map((s) => s.title), ['museum']);
    },
  );
  test(
    'Visited set excludes duplicates across days without reusing exhausted places',
    () {
      final visited = <String>{};
      final candidates = [place('a'), place('b')];
      final first = SchedulingEngine.schedule(
        candidates: candidates,
        preferences: prefs(),
        date: DateTime(2026, 10, 20),
        visited: visited,
      );
      final second = SchedulingEngine.schedule(
        candidates: candidates,
        preferences: prefs(),
        date: DateTime(2026, 10, 21),
        visited: visited,
      );
      expect(first.length, 2);
      expect(second, isEmpty);
    },
  );
  test('Changing destination cannot reuse another trip cache', () {
    final kl = SmartItineraryService.generateDailyStops(
      preferences: prefs(),
      dayIndex: 0,
    );
    final penang = SmartItineraryService.generateDailyStops(
      preferences: prefs().copyWith(destination: 'Penang'),
      dayIndex: 0,
    );
    expect(kl, isNotEmpty);
    expect(penang, isNotEmpty);
    expect(penang.every((s) => s.latitude > 5), isTrue);
  });
  test(
    'Weather never substitutes a different date and converts UTC slots to Malaysia',
    () async {
      final service = WeatherService.withClient(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'list': [
                {
                  'dt_txt': '2026-10-19 18:00:00',
                  'weather': [
                    {'main': 'Rain'},
                  ],
                  'pop': 0.8,
                  'main': {'temp': 28},
                },
              ],
            }),
            200,
          ),
        ),
      );
      final matching = await service.getForecastForDate(
        state: 'Kuala Lumpur',
        date: DateTime(2026, 10, 20),
      );
      expect(matching.isAvailable, isTrue);
      expect(matching.rainProbability, 80);
      final other = await service.getForecastForDate(
        state: 'Kuala Lumpur',
        date: DateTime(2026, 11, 20),
      );
      expect(other.isAvailable, isFalse);
      expect(other.suitabilityBadge, 'Forecast unavailable');
    },
  );
  test(
    'Offline trip, dates, snapshot, edit, deletion and account isolation survive new repositories',
    () async {
      await AuthService().login('tourist@example.com', 'SafeP@ss123!');
      final repository = SupabaseItineraryService.withStore(
        LocalItineraryStore(),
      );
      final snapshot = place('museum');
      final result = await repository.saveItinerary(
        title: 'Persistent trip',
        destinationState: 'Kuala Lumpur',
        totalCost: 20,
        preferences: prefs(),
        dailySchedules: [
          DailySchedule(
            scheduleId: '',
            itineraryId: '',
            dayNumber: 1,
            scheduleDate: DateTime(2026, 10, 20),
            stops: [
              ItineraryStop(
                id: '',
                scheduleId: '',
                placeId: 'museum',
                placeName: 'Museum',
                stopOrder: 1,
                arrivalTime: '09:00 AM',
                departureTime: '10:00 AM',
                snapshot: snapshot,
              ),
            ],
          ),
        ],
      );
      expect(result.success, isTrue);
      expect(result.synced, isFalse);
      final restarted = SupabaseItineraryService.withStore(
        LocalItineraryStore(),
      );
      final loaded = (await restarted.getSavedItineraries()).single;
      expect(loaded.itineraryId, result.itineraryId);
      expect(loaded.dailySchedules.single.scheduleDate, DateTime(2026, 10, 20));
      expect(loaded.preferences!.endDate, prefs().endDate);
      expect(
        loaded.dailySchedules.single.stops.single.toTravelStop().operatingHours,
        snapshot.operatingHours,
      );
      expect(
        await restarted.updateDailyScheduleStops(
          scheduleId: loaded.dailySchedules.single.scheduleId,
          totalDistanceKm: 0,
          stops: [],
        ),
        isTrue,
      );
      expect(
        (await repository.getSavedItineraries())
            .single
            .dailySchedules
            .single
            .stops,
        isEmpty,
      );
      await AuthService().login('chingkheat@example.com', 'SafeP@ss123!');
      expect(await restarted.getSavedItineraries(), isEmpty);
      expect(await restarted.deleteItinerary(loaded.itineraryId), isFalse);
      await AuthService().login('tourist@example.com', 'SafeP@ss123!');
      expect(await restarted.deleteItinerary(loaded.itineraryId), isTrue);
      expect(await repository.getSavedItineraries(), isEmpty);
      final journal = await LocalItineraryStore().read(loaded.userId);
      expect(journal[loaded.itineraryId]['deleted'], isTrue);
      expect(journal[loaded.itineraryId]['pending'], isTrue);
    },
  );
  test('Storage failure never claims a successful save', () async {
    await AuthService().login('tourist@example.com', 'SafeP@ss123!');
    final service = SupabaseItineraryService.withStore(_FailingStore());
    final result = await service.saveItinerary(
      title: 'Fail',
      destinationState: 'Kuala Lumpur',
      totalCost: 0,
      dailySchedules: [],
    );
    expect(result.success, isFalse);
    expect(
      await service.updateDailyScheduleStops(
        scheduleId: 'missing',
        totalDistanceKm: 0,
        stops: [],
      ),
      isFalse,
    );
  });
}

class _FailingStore extends LocalItineraryStore {
  @override
  Future<void> write(String userId, Map<String, dynamic> journal) async =>
      throw StateError('Disk full');
}

class _FakeCloud implements ItineraryCloud {
  bool online = false, loseNextResponse = false;
  int saves = 0;
  final rows = <String, Map<String, dynamic>>{};
  @override
  bool isAuthenticated(String userId) => online;
  @override
  Future<void> save(Map<String, dynamic> trip) async {
    saves++;
    rows[trip['itinerary_id'] as String] =
        jsonDecode(jsonEncode(trip)) as Map<String, dynamic>;
    if (loseNextResponse) {
      loseNextResponse = false;
      throw StateError('Response lost after commit');
    }
  }

  @override
  Future<void> delete(String userId, String itineraryId) async {
    rows.remove(itineraryId);
  }

  @override
  Future<List<Map<String, dynamic>>> load(String userId) async =>
      rows.values.where((r) => r['user_id'] == userId).toList();
}
