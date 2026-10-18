import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/models/travel_stop.dart';
import 'package:smart_travel_planner/models/trip_preferences.dart';
import 'package:smart_travel_planner/services/google_places_service.dart';
import 'package:smart_travel_planner/services/smart_itinerary_service.dart';
import 'package:smart_travel_planner/services/weather_service.dart';

void main() {
  group('SmartItineraryService Unit Tests', () {
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
      expect(stops.any((s) => s.title.contains('Penang') || s.title.contains('George Town') || s.title.contains('Gurney')), isTrue);
    });

    test('Schedules attractions for Melaka with lunch break', () {
      const prefs = TripPreferences(
        destination: 'Melaka',
        dailyStartTime: TimeOfDay(hour: 8, minute: 30),
        dailyEndTime: TimeOfDay(hour: 21, minute: 0),
        travelMode: 'Driving',
        interests: ['Culture', 'Food'],
      );

      final stops = SmartItineraryService.generateDailyStops(
        preferences: prefs,
        dayIndex: 0,
      );

      expect(stops.isNotEmpty, isTrue);
      // Check Melaka landmark is present
      expect(stops.any((s) => s.title.contains('Dutch Square') || s.title.contains('A Famosa') || s.title.contains('Jonker')), isTrue);
      // Check lunch stop is scheduled
      expect(stops.any((s) => s.title.toLowerCase().contains('lunch')), isTrue);
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

    test('GooglePlacesService builds photo URLs and convertGooglePlaceToStop extracts multiple photos', () {
      const samplePhotoName = 'places/ChIJ123/photos/ABC456';
      final photoUrl = GooglePlacesService.buildPhotoUrl(samplePhotoName);
      expect(photoUrl.contains('places.googleapis.com/v1/$samplePhotoName/media'), isTrue);
      expect(photoUrl.contains('maxWidthPx='), isTrue);

      final dummyPlace = {
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

      expect(stop.photoUrls.length, equals(3));
      expect(stop.primaryPhotoUrl, isNotNull);
      expect(stop.primaryPhotoUrl!.contains('photo1'), isTrue);
    });

    test('calculateRouteDistanceKm accurately computes distance with tortuosity factor', () {
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

      final dist = SmartItineraryService.calculateRouteDistanceKm([stop1, stop2]);
      // Haversine between KLCC and Batu Caves is ~9.4 km * 1.28 = ~12.0 km
      expect(dist, greaterThan(10.0));
      expect(dist, lessThan(16.0));

      // Single stop should yield 0.0 km
      expect(SmartItineraryService.calculateRouteDistanceKm([stop1]), equals(0.0));
    });

    test('WeatherService returns realistic meteorological snapshot with outdoor suitability badge', () async {
      final forecast = await WeatherService().getForecastForDate(
        state: 'Penang',
        date: DateTime.now().add(const Duration(days: 1)),
      );

      expect(forecast.locationState, equals('Penang'));
      expect(forecast.temperatureC, greaterThan(20.0));
      expect(forecast.rainProbability, greaterThanOrEqualTo(0.0));
      expect(forecast.suitabilityBadge.isNotEmpty, isTrue);
      expect(forecast.adviceText.isNotEmpty, isTrue);
    });
  });
}
