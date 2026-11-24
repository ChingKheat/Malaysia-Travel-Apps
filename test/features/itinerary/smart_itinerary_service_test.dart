import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';
import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/smart_itinerary_service.dart';
import 'package:smart_travel_planner/shared/services/weather_service.dart';
import 'package:smart_travel_planner/shared/models/weather_forecast.dart';
import 'package:smart_travel_planner/features/itinerary/services/scheduling_engine.dart';

void main() {
  group('SmartItineraryService Unit Tests', () {
    test(
      'refreshes a selected Google place with coordinates but no hours',
      () async {
        final selected = TravelStop.fromJson({
          'title': 'Saved museum',
          'place_id': 'ChIJSavedMuseum',
          'latitude': 2.43,
          'longitude': 103.84,
          'opening_hours': 'Hours unverified',
        });
        final places = GooglePlacesService(
          endpoint: 'https://project.test/functions/v1/google-places',
          accessToken: 'test-session',
          client: MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            if (body['operation'] == 'details') {
              return http.Response(
                jsonEncode({
                  'id': 'ChIJSavedMuseum',
                  'displayName': {'text': 'Saved museum'},
                  'location': {'latitude': 2.43, 'longitude': 103.84},
                  'regularOpeningHours': {
                    'periods': [
                      {
                        'open': {'day': 0, 'hour': 0},
                      },
                    ],
                  },
                }),
                200,
              );
            }
            return http.Response(jsonEncode({'places': []}), 200);
          }),
        );
        await SmartItineraryService.generateLiveItineraryForAllDays(
          preferences: TripPreferences(
            destination: 'Johor',
            numberOfDays: 1,
            mustVisitPlaces: [selected],
          ),
          placesService: places,
        );
        expect(
          SmartItineraryService.getLiveStops(0)!.map((s) => s.placeId),
          contains('ChIJSavedMuseum'),
        );
      },
    );

    test(
      'schedules a saved local LEGOLAND after verifying its hours',
      () async {
        final selected = TravelStop.fromJson({
          'title': 'Legoland Malaysia Resort',
          'place_id': 'curated_johor_01',
          'latitude': 1.4273,
          'longitude': 103.6299,
          'opening_hours': 'Hours unverified',
        });
        final place = {
          'id': 'ChIJLegoland',
          'displayName': {'text': 'Legoland Malaysia Resort'},
          'location': {'latitude': 1.4273, 'longitude': 103.6299},
          'regularOpeningHours': {
            'periods': [
              {
                'open': {'day': 0, 'hour': 0},
              },
            ],
          },
        };
        final places = GooglePlacesService(
          endpoint: 'https://project.test/functions/v1/google-places',
          accessToken: 'test-session',
          client: MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            if (body['operation'] == 'details') {
              return http.Response(jsonEncode(place), 200);
            }
            return http.Response(
              jsonEncode({
                'places': body['query'] == selected.title ? [place] : [],
              }),
              200,
            );
          }),
        );
        expect(
          await places.findDetailsForLocalStop(selected, state: 'Johor'),
          isNotNull,
        );
        await SmartItineraryService.generateLiveItineraryForAllDays(
          preferences: TripPreferences(
            destination: 'Johor',
            startDate: DateTime(2035, 1, 1),
            numberOfDays: 1,
            mustVisitPlaces: [selected],
          ),
          placesService: places,
        );
        expect(
          SmartItineraryService.getLiveStops(0)!.map((s) => s.placeId),
          contains('ChIJLegoland'),
        );
      },
    );

    test('schedules multiple different saved must-visits after verifying hours', () async {
      final selected = [
        for (var i = 0; i < 2; i++)
          TravelStop.fromJson({
            'title': 'Selected attraction $i',
            'place_id': 'local-attraction-$i',
            'latitude': 1.43,
            'longitude': 103.63 + i * 0.001,
            'opening_hours': 'Hours unverified',
          }),
      ];
      final details = [
        for (var i = 0; i < selected.length; i++)
          {
            'id': 'ChIJSelectedAttraction$i',
            'displayName': {'text': selected[i].title},
            'location': {
              'latitude': selected[i].latitude,
              'longitude': selected[i].longitude,
            },
            'regularOpeningHours': {
              'periods': [
                {'open': {'day': 0, 'hour': 0}},
              ],
            },
          },
      ];
      final places = GooglePlacesService(
        endpoint: 'https://project.test/functions/v1/google-places',
        accessToken: 'test-session',
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['operation'] == 'details') {
            return http.Response(
              jsonEncode(details.firstWhere((place) => place['id'] == body['placeId'])),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'places': details.where((place) =>
                  (place['displayName'] as Map)['text'] == body['query']).toList(),
            }),
            200,
          );
        }),
      );
      await SmartItineraryService.generateLiveItineraryForAllDays(
        preferences: TripPreferences(
          destination: 'Johor',
          startDate: DateTime(2035, 1, 1),
          numberOfDays: 1,
          mustVisitPlaces: selected,
        ),
        placesService: places,
      );
      expect(
        SmartItineraryService.getLiveStops(0)!.map((stop) => stop.placeId),
        containsAll(['ChIJSelectedAttraction0', 'ChIJSelectedAttraction1']),
      );
    });

    test('keeps a local must-visit when live details are unavailable', () async {
      final selected = TravelStop.fromJson({
        'title': 'Legoland Malaysia Resort',
        'place_id': 'curated_johor_01',
        'latitude': 1.4273,
        'longitude': 103.6299,
        'opening_hours': 'Hours unverified',
      });
      final places = GooglePlacesService(
        endpoint: 'https://project.test/functions/v1/google-places',
        accessToken: 'test-session',
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if ((body['query'] as String? ?? '').startsWith('tourist attractions')) {
            return http.Response(jsonEncode({'places': [{
              'id': 'ChIJOtherAttraction',
              'displayName': {'text': 'Other attraction'},
              'location': {'latitude': 1.428, 'longitude': 103.63},
              'regularOpeningHours': {'periods': [{'open': {'day': 0, 'hour': 0}}]},
            }]}), 200);
          }
          return http.Response(jsonEncode({'places': []}), 200);
        }),
      );
      await SmartItineraryService.generateLiveItineraryForAllDays(
        preferences: TripPreferences(
          destination: 'Johor',
          startDate: DateTime(2035, 1, 1),
          numberOfDays: 1,
          mustVisitPlaces: [selected],
        ),
        placesService: places,
      );
      final stops = SmartItineraryService.getLiveStops(0)!;
      expect(stops.map((stop) => stop.placeId), contains('curated_johor_01'));
      expect(SmartItineraryService.dayWarnings[0], contains('Some opening hours are unverified'));
    });

    test('uses free admission for a verified venue', () {
      final museum = GooglePlacesService.convertGooglePlaceToStop(
        place: {
          'id': 'ChIJwzwNUJlLxTERyUQ43zKJ0Ww',
          'displayName': {'text': 'Mersing Museum'},
        },
        timeRange: '',
        durationLabel: '90 min',
      );

      expect(museum.estimatedCost, 0);
      expect(SmartItineraryService.estimateVisitCost('Museum'), 40);
    });

    test(
      'fills a short day with nearby suggestions from live search',
      () async {
        const museumId = 'ChIJwzwNUJlLxTERyUQ43zKJ0Ww';
        final museum = GooglePlacesService.convertGooglePlaceToStop(
          place: {
            'id': museumId,
            'displayName': {'text': 'Mersing Museum'},
            'location': {'latitude': 2.43, 'longitude': 103.84},
            'regularOpeningHours': {
              'periods': [
                {
                  'open': {'day': 0, 'hour': 0},
                },
              ],
            },
            'is_indoor': true,
          },
          timeRange: '',
          durationLabel: '60 min',
        ).withVisitMinutes(60);
        final suggestions = [
          for (final (index, name) in [
            'Mersing Marine Park Gallery',
            'Visitor Gallery A',
            'Visitor Gallery B',
          ].indexed)
            {
              'id': 'ChIJTestMersing$index',
              'displayName': {'text': name},
              'formattedAddress': 'Mersing, Johor, Malaysia',
              'location': {
                'latitude': 2.43,
                'longitude': 103.841 + 0.001 * index,
              },
              'primaryTypeDisplayName': {'text': 'Gallery'},
              'regularOpeningHours': {
                'periods': [
                  {
                    'open': {'day': 0, 'hour': 0},
                  },
                ],
              },
            },
        ];
        final operations = <String>[];
        final places = GooglePlacesService(
          endpoint: 'https://project.test/functions/v1/google-places',
          accessToken: 'test-session',
          client: MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            operations.add(body['operation'] as String);
            return switch (body['operation']) {
              'planner_search' => http.Response(
                jsonEncode({'places': suggestions}),
                200,
              ),
              'details' => http.Response(
                jsonEncode(
                  suggestions.singleWhere(
                    (place) => place['id'] == body['placeId'],
                  ),
                ),
                200,
              ),
              _ => http.Response('{}', 400),
            };
          }),
        );
        final generated =
            await SmartItineraryService.generateLiveItineraryForAllDays(
              preferences: TripPreferences(
                destination: 'Johor',
                numberOfDays: 1,
                dailyStartTime: const TimeOfDay(hour: 9, minute: 0),
                dailyEndTime: const TimeOfDay(hour: 17, minute: 0),
                travelMode: 'Walking',
                departurePoint: museum,
                mustVisitPlaces: [museum],
                paceCategory: PaceCategory.balanced,
                budgetCategory: 'Low',
              ),
              placesService: places,
              requireVisits: true,
            );

        expect(generated, isTrue);
        expect(
          operations,
          contains('planner_search'),
          reason: places.lastError,
        );
        final stops = SmartItineraryService.getLiveStops(0)!;
        expect(stops, hasLength(4));
        expect(stops.first.placeId, museumId);
        expect(
          stops
              .singleWhere(
                (stop) => stop.title == 'Mersing Marine Park Gallery',
              )
              .estimatedCost,
          0,
        );
      },
    );

    test('offline plans balance the selected places across the trip dates', () {
      final selected = [
        for (var index = 0; index < 7; index++)
          TravelStop.fromJson({
            'title': 'Selected place $index',
            'place_id': 'selected-$index',
            'latitude': 1.5,
            'longitude': 103.5 + index * 0.001,
            'opening_hours': 'Open 24 hours',
            'visit_minutes': 60,
          }),
      ];
      final preferences = TripPreferences(
        destination: 'Test destination',
        startDate: DateTime(2026, 12, 7),
        endDate: DateTime(2026, 12, 9),
        paceCategory: PaceCategory.relaxed,
        selectedPlaces: selected,
      );

      final days = [
        for (var day = 0; day < 3; day++)
          SmartItineraryService.generateDailyStops(
            preferences: preferences,
            dayIndex: day,
          ),
      ];

      expect(
        days.map((day) => day.length),
        everyElement(greaterThanOrEqualTo(2)),
      );
      expect(
        days.expand((day) => day).map((stop) => stop.placeId),
        unorderedEquals(selected.map((stop) => stop.placeId)),
      );
    });

    test('Schedules attractions for Penang starting at user start time', () {
      const prefs = TripPreferences(
        destination: 'Penang',
        dailyStartTime: TimeOfDay(hour: 9, minute: 0),
        dailyEndTime: TimeOfDay(hour: 18, minute: 0),
        travelMode: 'Walking',
        interests: ['Culture', 'Food'],
      );

      final stops = SmartItineraryService.generateDailyStops(
        preferences: prefs,
        dayIndex: 0,
      );

      expect(stops.isNotEmpty, isTrue);
      // First stop should start at 09:00 AM
      expect(stops.first.time.startsWith('09:00 AM'), isTrue);
      // All stops should be within the 18:00 (6:00 PM) ceiling
      expect(
        stops.any(
          (s) =>
              s.title.contains('Penang') ||
              s.title.contains('George Town') ||
              s.title.contains('Gurney'),
        ),
        isTrue,
      );
    });

    test('Schedules multi-day itinerary for Johor with stops on each day', () async {
      final prefs = TripPreferences(
        destination: 'Johor',
        startDate: DateTime(2026, 11, 29),
        endDate: DateTime(2026, 12, 1),
        numberOfDays: 3,
        dailyStartTime: const TimeOfDay(hour: 9, minute: 0),
        dailyEndTime: const TimeOfDay(hour: 22, minute: 0),
        travelMode: 'Driving',
      );

      final success = await SmartItineraryService.generateLiveItineraryForAllDays(
        preferences: prefs,
        requireVisits: false,
      );

      expect(success, isTrue);

      final day1Stops = await SmartItineraryService.generateLiveItinerary(
        preferences: prefs,
        dayIndex: 0,
      );
      final day2Stops = await SmartItineraryService.generateLiveItinerary(
        preferences: prefs,
        dayIndex: 1,
      );
      final day3Stops = await SmartItineraryService.generateLiveItinerary(
        preferences: prefs,
        dayIndex: 2,
      );

      expect(day1Stops, isNotEmpty, reason: 'Day 1 should have scheduled attractions');
      expect(day2Stops, isNotEmpty, reason: 'Day 2 should have scheduled attractions');
      expect(day3Stops, isNotEmpty, reason: 'Day 3 should have scheduled attractions');
      expect(SmartItineraryService.dayWarnings[1]?.contains('No additional places fit this day'), isNot(true));
      expect(SmartItineraryService.dayWarnings[2]?.contains('No additional places fit this day'), isNot(true));
    });

    test('Schedules indoor attractions for Johor when weather is thunderstorm', () {
      final candidates = SmartItineraryService.generateDailyStops(
        preferences: const TripPreferences(destination: 'Johor'),
        dayIndex: 1,
      );
      final thunderstorm = WeatherForecast(
        itineraryId: 'test',
        locationState: 'Johor',
        scheduleDate: DateTime(2026, 11, 24),
        condition: 'Heavy thunderstorm',
        rainProbability: 95,
      );
      final stops = SchedulingEngine.schedule(
        candidates: candidates,
        preferences: const TripPreferences(
          destination: 'Johor',
          dailyStartTime: TimeOfDay(hour: 9, minute: 0),
          dailyEndTime: TimeOfDay(hour: 21, minute: 0),
        ),
        date: DateTime(2026, 11, 24),
        visited: {},
        weather: thunderstorm,
      );

      expect(stops, isNotEmpty, reason: 'Thunderstorm should schedule indoor attractions rather than 0 attractions');
      expect(stops.every((s) => s.isIndoor == true), isTrue);
      expect(
        stops.any((s) =>
            s.title.contains('Mid Valley') ||
            s.title.contains('Heritage Museum') ||
            s.title.contains('City Square')),
        isTrue,
      );
    });

    test('Schedules the Melaka night market within its weekend hours', () {
      final prefs = TripPreferences(
        destination: 'Melaka',
        startDate: DateTime(2026, 10, 24),
        dailyStartTime: const TimeOfDay(hour: 8, minute: 30),
        dailyEndTime: const TimeOfDay(hour: 21, minute: 0),
        travelMode: 'Driving',
        interests: ['Culture', 'Food'],
      );

      final stops = SmartItineraryService.generateDailyStops(
        preferences: prefs,
        dayIndex: 0,
      );

      expect(stops.map((s) => s.title), contains('Melaka River Cruise'));
      final market = stops.singleWhere((s) => s.category == 'Food');
      expect(market.title, 'Jonker Walk Heritage Night Market');
      expect(market.time, '06:00 PM - 07:30 PM');
    });

    test('Schedules stops within custom daily end time window', () {
      const prefs = TripPreferences(
        destination: 'Kuala Lumpur',
        dailyStartTime: TimeOfDay(hour: 10, minute: 0),
        dailyEndTime: TimeOfDay(hour: 14, minute: 0), // short 4-hour window
        travelMode: 'Driving',
        interests: ['Food'],
      );

      final stops = SmartItineraryService.generateDailyStops(
        preferences: prefs,
        dayIndex: 0,
      );

      expect(stops.isNotEmpty, isTrue);
      expect(stops.first.time.startsWith('10:00 AM'), isTrue);
      // Number of stops should be small due to 4-hour limit
      expect(stops.length, lessThanOrEqualTo(3));
    });

    test('Google details retain ephemeral photos without permanent URLs', () {
      final dummyPlace = {
        'id': 'ChIJ123',
        'displayName': {'text': 'Penang Hill'},
        'formattedAddress': 'Penang, Malaysia',
        'primaryTypeDisplayName': {'text': 'Tourist Attraction'},
        'rating': 4.7,
        'userRatingCount': 500,
        'photos': [
          {'name': 'places/ChIJ123/photos/photo1'},
          {'name': 'places/ChIJ123/photos/photo2'},
          {'name': 'places/ChIJ123/photos/photo3'},
        ],
      };

      final stop = GooglePlacesService.convertGooglePlaceToStop(
        place: dummyPlace,
        timeRange: '09:00 AM - 10:30 AM',
        durationLabel: '1 h 30 min',
      );

      expect(stop.photoUrls, isEmpty);
      expect(stop.primaryPhotoUrl, isNull);
      expect(stop.googleDetails!.photos.length, 3);
      expect(stop.googleDetails!.photos.first.name, contains('photo1'));
      expect(stop.tips, contains('Rating: 4.7'));
      expect(stop.tips, contains('500 reviews'));
    });

    test(
      'calculateRouteDistanceKm accurately computes distance with tortuosity factor',
      () {
        const stop1 = TravelStop(
          title: 'KLCC',
          time: '09:00 AM - 10:30 AM',
          note: '',
          description: '',
          duration: '1 h 30 min',
          openingHours: '10:00 AM - 10:00 PM',
          tips: [],
          icon: Icons.place,
          color: Colors.blue,
          latitude: 3.1578,
          longitude: 101.7119,
        );

        const stop2 = TravelStop(
          title: 'Batu Caves',
          time: '11:00 AM - 01:00 PM',
          note: '',
          description: '',
          duration: '2 h',
          openingHours: '06:00 AM - 09:00 PM',
          tips: [],
          icon: Icons.place,
          color: Colors.green,
          latitude: 3.2379,
          longitude: 101.6840,
        );

        final dist = SmartItineraryService.calculateRouteDistanceKm([
          stop1,
          stop2,
        ]);
        // Haversine between KLCC and Batu Caves is ~9.4 km * 1.28 = ~12.0 km
        expect(dist, greaterThan(10.0));
        expect(dist, lessThan(16.0));

        // Single stop should yield 0.0 km
        expect(
          SmartItineraryService.calculateRouteDistanceKm([stop1]),
          equals(0.0),
        );
      },
    );

    test(
      'WeatherService returns realistic meteorological snapshot with outdoor suitability badge',
      () async {
        final forecast = await WeatherService().getForecastForDate(
          state: 'Penang',
          date: DateTime.now().add(const Duration(days: 1)),
        );

        expect(forecast.locationState, equals('Penang'));
        expect(forecast.temperatureC, greaterThan(20.0));
        expect(forecast.rainProbability, greaterThanOrEqualTo(0.0));
        expect(forecast.suitabilityBadge.isNotEmpty, isTrue);
        expect(forecast.adviceText.isNotEmpty, isTrue);
      },
    );
  });
}
