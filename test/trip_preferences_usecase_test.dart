import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/models/trip_preferences.dart';
import 'package:smart_travel_planner/services/trip_preferences_service.dart';

void main() {
  group('UC300_Enter Trip Preferences Unit & Requirement Tests', () {
    test('C1 / A1: Empty/missing mandatory fields return M2 and highlights empty fields', () {
      const prefs = TripPreferences(
        destination: '',
        numberOfDays: null,
        dailyStartTime: null,
        dailyEndTime: null,
        interests: ['Food'],
        budgetCategory: '',
        travelMode: '',
      );

      final result = TripPreferencesService.validatePreferences(prefs);

      expect(result.success, isFalse);
      expect(result.message, equals(TripPreferencesService.m2Mandatory));
      expect(result.emptyFields.contains('destination'), isTrue);
      expect(result.emptyFields.contains('numberOfDays'), isTrue);
      expect(result.emptyFields.contains('dailyStartTime'), isTrue);
      expect(result.emptyFields.contains('dailyEndTime'), isTrue);
      expect(result.emptyFields.contains('budgetCategory'), isTrue);
      expect(result.emptyFields.contains('travelMode'), isTrue);
    });

    test('C2 / A2: Unsupported destination returns M3', () {
      const prefs = TripPreferences(
        destination: 'Not A Real Malaysia State',
        numberOfDays: 3,
        dailyStartTime: TimeOfDay(hour: 8, minute: 0),
        dailyEndTime: TimeOfDay(hour: 22, minute: 0),
        interests: ['Food'],
        budgetCategory: 'Medium',
        travelMode: 'Driving',
      );

      final result = TripPreferencesService.validatePreferences(prefs);

      expect(result.success, isFalse);
      expect(result.message, equals(TripPreferencesService.m3InvalidDestination));
    });

    test('C3 / A3: Travel days range out of limits (e.g. 0 or > 30) returns M4', () {
      const invalidDaysLow = TripPreferences(
        destination: 'Kuala Lumpur',
        numberOfDays: 0,
        dailyStartTime: TimeOfDay(hour: 8, minute: 0),
        dailyEndTime: TimeOfDay(hour: 22, minute: 0),
        interests: ['Food'],
        budgetCategory: 'Medium',
        travelMode: 'Driving',
      );

      const invalidDaysHigh = TripPreferences(
        destination: 'Kuala Lumpur',
        numberOfDays: 31,
        dailyStartTime: TimeOfDay(hour: 8, minute: 0),
        dailyEndTime: TimeOfDay(hour: 22, minute: 0),
        interests: ['Food'],
        budgetCategory: 'Medium',
        travelMode: 'Driving',
      );

      final resultLow = TripPreferencesService.validatePreferences(invalidDaysLow);
      final resultHigh = TripPreferencesService.validatePreferences(invalidDaysHigh);

      expect(resultLow.success, isFalse);
      expect(resultLow.message, equals(TripPreferencesService.m4InvalidDays));

      expect(resultHigh.success, isFalse);
      expect(resultHigh.message, equals(TripPreferencesService.m4InvalidDays));
    });

    test('C4 / A4: End time equal to or earlier than start time returns M5', () {
      const invalidTimeRange = TripPreferences(
        destination: 'Kuala Lumpur',
        numberOfDays: 3,
        dailyStartTime: TimeOfDay(hour: 18, minute: 0),
        dailyEndTime: TimeOfDay(hour: 8, minute: 0),
        interests: ['Food'],
        budgetCategory: 'Medium',
        travelMode: 'Driving',
      );

      final result = TripPreferencesService.validatePreferences(invalidTimeRange);

      expect(result.success, isFalse);
      expect(result.message, equals(TripPreferencesService.m5InvalidTimeRange));
    });

    test('C5 / A5: Empty interests list returns M6', () {
      const noInterests = TripPreferences(
        destination: 'Kuala Lumpur',
        numberOfDays: 3,
        dailyStartTime: TimeOfDay(hour: 8, minute: 0),
        dailyEndTime: TimeOfDay(hour: 22, minute: 0),
        interests: [],
        budgetCategory: 'Medium',
        travelMode: 'Driving',
      );

      final result = TripPreferencesService.validatePreferences(noInterests);

      expect(result.success, isFalse);
      expect(result.message, equals(TripPreferencesService.m6NoInterests));
    });

    test('C6 / A6: Invalid budget category returns M7', () {
      const invalidBudget = TripPreferences(
        destination: 'Kuala Lumpur',
        numberOfDays: 3,
        dailyStartTime: TimeOfDay(hour: 8, minute: 0),
        dailyEndTime: TimeOfDay(hour: 22, minute: 0),
        interests: ['Food'],
        budgetCategory: 'InvalidBudgetCategory',
        travelMode: 'Driving',
      );

      final result = TripPreferencesService.validatePreferences(invalidBudget);

      expect(result.success, isFalse);
      expect(result.message, equals(TripPreferencesService.m7InvalidBudget));
    });

    test('C7 / A7: Unsupported travel mode returns M8', () {
      const unsupportedMode = TripPreferences(
        destination: 'Kuala Lumpur',
        numberOfDays: 3,
        dailyStartTime: TimeOfDay(hour: 8, minute: 0),
        dailyEndTime: TimeOfDay(hour: 22, minute: 0),
        interests: ['Food'],
        budgetCategory: 'Medium',
        travelMode: 'Public Transport',
      );

      final result = TripPreferencesService.validatePreferences(unsupportedMode);

      expect(result.success, isFalse);
      expect(result.message, equals(TripPreferencesService.m8UnsupportedMode));
    });

    test('FR300_10 & FR300_11: Valid preferences return success M1 and store preferences', () {
      const validPrefs = TripPreferences(
        destination: 'Kuala Lumpur',
        numberOfDays: 5,
        dailyStartTime: TimeOfDay(hour: 8, minute: 0),
        dailyEndTime: TimeOfDay(hour: 22, minute: 0),
        interests: ['Food', 'Culture'],
        budgetCategory: 'Medium',
        travelMode: 'Driving',
      );

      final result = TripPreferencesService.validatePreferences(validPrefs);

      expect(result.success, isTrue);
      expect(result.message, equals(TripPreferencesService.m1Success));
      expect(TripPreferencesService.storedPreferences, isNotNull);
      expect(TripPreferencesService.storedPreferences!.destination, equals('Kuala Lumpur'));
    });
  });
}
