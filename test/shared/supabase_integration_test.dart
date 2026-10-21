// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/core/config/supabase_config.dart';
import 'package:smart_travel_planner/features/itinerary/models/itinerary_models.dart';
import 'package:smart_travel_planner/features/auth/models/user_model.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/supabase_itinerary_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Supabase Configuration & Architecture Tests', () {
    test('SupabaseConfig initializes safely without crashing when unconfigured', () async {
      final initialized = await SupabaseConfig.initialize();
      // In CI / test environment without real keys, returns false safely without throwing exceptions
      expect(initialized, isA<bool>());
    });

    test('UserModel serializes to and from Supabase profiles schema (Table 4.2)', () {
      final now = DateTime.now();
      final user = UserModel(
        uid: 'user_test_uuid_123',
        name: 'Ching Kheat',
        email: 'chingkheat@example.com',
        createdAt: now,
        preferredLanguage: 'en',
      );

      final map = user.toSupabaseMap();
      expect(map['user_id'], equals('user_test_uuid_123'));
      expect(map['email'], equals('chingkheat@example.com'));
      expect(map['full_name'], equals('Ching Kheat'));
      expect(map['preferred_language'], equals('en'));

      final reconstructed = UserModel.fromSupabase(map, 'user_test_uuid_123');
      expect(reconstructed.uid, equals('user_test_uuid_123'));
      expect(reconstructed.name, equals('Ching Kheat'));
      expect(reconstructed.email, equals('chingkheat@example.com'));
      expect(reconstructed.preferredLanguage, equals('en'));
    });
  });

  group('UC601 & UC700 Supabase Itinerary Service Tests', () {
    late AuthService authService;
    late SupabaseItineraryService itineraryService;

    setUp(() {
      authService = AuthService();
      itineraryService = SupabaseItineraryService();
    });

    test('Saving an itinerary requires authenticated user session (Constraint C2)', () async {
      // Ensure logged out
      await authService.logout();

      final result = await itineraryService.saveItinerary(
        title: 'Kuala Lumpur 3-Day Trip',
        destinationState: 'Kuala Lumpur',
        totalCost: 180.0,
        dailySchedules: [],
      );

      expect(result.success, isFalse);
      expect(result.message, contains('Authentication required'));
    });

    test('UC601: Authenticated user can save an itinerary and its daily stops', () async {
      // Log in with seeded user
      final loginRes = await authService.loginUser(
        email: 'chingkheat@example.com',
        password: 'SafeP@ss123!',
      );
      expect(loginRes.success, isTrue);

      final sampleStops = [
        const ItineraryStop(
          id: 'stop_1',
          scheduleId: 'sched_1',
          placeId: 'poi_kl_batu_caves',
          placeName: 'Batu Caves',
          stopOrder: 1,
          arrivalTime: '08:30',
          departureTime: '10:00',
        ),
        const ItineraryStop(
          id: 'stop_2',
          scheduleId: 'sched_1',
          placeId: 'poi_kl_central_market',
          placeName: 'Central Market',
          stopOrder: 2,
          arrivalTime: '10:45',
          departureTime: '12:30',
        ),
      ];

      final sampleSchedules = [
        DailySchedule(
          scheduleId: 'sched_1',
          itineraryId: '',
          dayNumber: 1,
          scheduleDate: DateTime.now(),
          totalDistanceKm: 14.5,
          stops: sampleStops,
        ),
      ];

      final result = await itineraryService.saveItinerary(
        title: 'Kuala Lumpur Heritage & Nature',
        destinationState: 'Kuala Lumpur',
        totalCost: 150.0,
        dailySchedules: sampleSchedules,
      );

      expect(result.success, isTrue);
      expect(result.synced, isFalse);
      expect(result.message, equals(SupabaseItineraryService.m1SaveLocal));
      expect(result.itineraryId, isNotNull);

      // UC700: Retrieve saved itineraries for user
      final savedTrips = await itineraryService.getSavedItineraries();
      expect(savedTrips.isNotEmpty, isTrue);
      expect(savedTrips.first.destinationState, equals('Kuala Lumpur'));
      expect(savedTrips.first.dailySchedules.first.stops.length, equals(2));

      // Test conversion to SavedTrip for UI backwards-compatibility
      final tripCardModel = savedTrips.first.toSavedTrip();
      expect(tripCardModel.destination, equals('Kuala Lumpur'));
      expect(tripCardModel.detail, contains('2 stops'));

      // Test deletion
      final deleted = await itineraryService.deleteItinerary(savedTrips.first.itineraryId);
      expect(deleted, isTrue);
    });
  });
}
