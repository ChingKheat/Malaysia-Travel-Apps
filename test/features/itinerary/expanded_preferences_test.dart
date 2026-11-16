import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/services/planner_smart_fill.dart';
import 'package:smart_travel_planner/features/itinerary/services/scheduling_engine.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';

void main() {
  TravelStop stop(String name) => TravelStop.fromJson({
    'title': name,
    'latitude': 3.14,
    'longitude': 101.71,
    'visit_minutes': 60,
    'opening_hours': 'Open 24 hours',
  });

  test('legacy preferences and invalid new values use safe defaults', () {
    final preferences = TripPreferences.fromJson({
      'destination': 'Kuala Lumpur',
      'arrival_minutes': -1,
      'dietary_preference': 'unknown',
      'departure_buffer_minutes': 500,
    });
    expect(preferences.destination, 'Kuala Lumpur');
    expect(preferences.arrivalTime, isNull);
    expect(preferences.dietaryPreference, DietaryPreference.unrestricted);
    expect(preferences.departureBufferMinutes, 60);
  });

  test('expanded preferences round-trip through the saved-trip JSON', () {
    final original = TripPreferences(
      travelerType: TravelerType.family,
      paceCategory: PaceCategory.relaxed,
      dietaryPreference: DietaryPreference.vegetarian,
      accommodationArea: stop('Accommodation'),
      arrivalTime: const TimeOfDay(hour: 12, minute: 15),
      departureTime: const TimeOfDay(hour: 18, minute: 0),
      departureBufferMinutes: 180,
      departureTransferMinutes: 15,
      mustVisitPlaces: [stop('Landmark')],
      secondaryTransportModes: const ['Walking'],
    );
    final restored = TripPreferences.fromJson(original.toJson());
    expect(restored.toJson(), original.toJson());
    expect(restored.dailyOrigin?.title, 'Accommodation');
  });

  test('a one-day trip applies both buffers and prioritizes a must-visit', () {
    final date = DateTime(2026, 12, 7);
    final priority = stop('Priority');
    final preferences = TripPreferences(
      startDate: date,
      endDate: date,
      arrivalTime: const TimeOfDay(hour: 12, minute: 0),
      departureTime: const TimeOfDay(hour: 17, minute: 15),
      departureTransferMinutes: 15,
      departureBufferMinutes: 180,
      mustVisitPlaces: [priority],
    );
    final visits = SchedulingEngine.schedule(
      candidates: [stop('Other'), priority],
      preferences: preferences,
      date: date,
      visited: {},
    );
    expect(visits.map((visit) => visit.title), ['Priority']);
    expect(visits.single.time, '01:00 PM - 02:00 PM');
  });

  test(
    'verified short walking legs override the primary mode and round-trip',
    () {
      final origin = stop('Station');
      final destination = TravelStop.fromJson({
        ...stop('Museum').toJson(),
        'latitude': 3.145,
      });
      final key =
          '${SchedulingEngine.identity(origin)}>${SchedulingEngine.identity(destination)}';
      final preferences = TripPreferences(
        accommodationArea: origin,
        travelMode: 'Public Transport',
        secondaryTransportModes: const ['Walking'],
        transitPlanningMinutes: 25,
      );
      final visits = SchedulingEngine.schedule(
        candidates: [destination],
        preferences: preferences,
        date: DateTime(2026, 12, 7),
        visited: {},
        walkingLegs: {key: const TravelLeg(8, 0.5, estimated: false)},
      );
      expect(visits.single.travelMinutes, 8);
      expect(visits.single.inboundMode, 'Walking');
      expect(
        TravelStop.fromJson(visits.single.toJson()).inboundMode,
        'Walking',
      );
    },
  );

  test('smart fill validates supported fields and has a local fallback', () {
    expect(
      PlannerSmartFill.validate({
        'traveler': 'family',
        'diet': 'unverified',
        'date': '2030-01-01',
      }),
      {'traveler': 'family'},
    );
    expect(
      PlannerSmartFill.localSuggestions(
        'My parents want local food and a relaxed trip.',
      ),
      {'traveler': 'family', 'interest': 'Food', 'pace': 'relaxed'},
    );
  });
}
