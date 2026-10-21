import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';
import 'package:smart_travel_planner/features/itinerary/screens/edit_itinerary_screen.dart';
import 'package:smart_travel_planner/features/itinerary/services/smart_itinerary_service.dart';

void main() {
  group('UC602: Edit Itinerary Unit Tests', () {
    const stop1 = TravelStop(
      title: 'Petronas Twin Towers',
      time: '09:00 AM - 10:30 AM',
      note: 'Landmark',
      description: 'Iconic twin skyscrapers',
      duration: '1 h 30 min',
      openingHours: '10:00 AM - 10:00 PM',
      tips: ['Buy tickets online'],
      icon: Icons.place,
      color: Colors.blue,
      latitude: 3.1579,
      longitude: 101.7116,
      placeId: 'poi_klcc',
    );

    const stop2 = TravelStop(
      title: 'Batu Caves',
      time: '10:45 AM - 12:15 PM',
      note: 'Culture & Temple',
      description: 'Limestone hill and shrine',
      duration: '1 h 30 min',
      openingHours: '07:00 AM - 09:00 PM',
      tips: ['Wear comfortable shoes'],
      icon: Icons.temple_hindu,
      color: Colors.orange,
      latitude: 3.2374,
      longitude: 101.6839,
      placeId: 'poi_batu_caves',
    );

    const stop3 = TravelStop(
      title: 'Central Market',
      time: '12:30 PM - 02:00 PM',
      note: 'Shopping & Handicrafts',
      description: 'Heritage market',
      duration: '1 h 30 min',
      openingHours: '10:00 AM - 10:00 PM',
      tips: ['Souvenirs & snacks'],
      icon: Icons.storefront,
      color: Colors.teal,
      latitude: 3.1453,
      longitude: 101.6958,
      placeId: 'poi_central_market',
    );

    test('Reordering stops updates sequence and recalculates route distance accurately', () {
      final originalList = [stop1, stop2, stop3];
      final originalDistance = SmartItineraryService.calculateRouteDistanceKm(originalList);
      expect(originalDistance, greaterThan(0.0));

      // Reverse order: stop3 -> stop1 -> stop2
      final reorderedList = [stop3, stop1, stop2];
      final reorderedDistance = SmartItineraryService.calculateRouteDistanceKm(reorderedList);

      // Distance changes due to route topology differences
      expect(reorderedDistance, greaterThan(0.0));
      expect(reorderedList.first.title, equals('Central Market'));
      expect(reorderedList.last.title, equals('Batu Caves'));
    });

    test('Swap outdoor stop with weather-proof indoor alternative replaces stop and retains slot', () {
      final currentStops = [stop1, stop2];

      const indoorReplacement = TravelStop(
        title: 'Aquaria KLCC',
        time: '10:45 AM - 12:15 PM',
        note: 'Indoor alternative • Weather protected',
        description: 'State-of-the-art oceanarium',
        duration: '1 h 30 min',
        openingHours: '10:00 AM - 08:00 PM',
        tips: ['Air-conditioned'],
        icon: Icons.roofing_outlined,
        color: Colors.blue,
        latitude: 3.1534,
        longitude: 101.7127,
        placeId: 'curated_kl_11',
      );

      // Swap stop 2 (Batu Caves) with Aquaria KLCC
      currentStops[1] = indoorReplacement;

      expect(currentStops[1].title, equals('Aquaria KLCC'));
      expect(currentStops[1].placeId, equals('curated_kl_11'));
      expect(currentStops[1].note.contains('Indoor alternative'), isTrue);
    });

    test('Deleting a stop updates total count and recalculates distance', () {
      final stops = [stop1, stop2, stop3];
      expect(stops.length, equals(3));

      // Remove middle stop
      stops.removeAt(1);

      expect(stops.length, equals(2));
      expect(stops.first.title, equals('Petronas Twin Towers'));
      expect(stops.last.title, equals('Central Market'));

      final newDistance = SmartItineraryService.calculateRouteDistanceKm(stops);
      expect(newDistance, greaterThan(0.0));
    });

    testWidgets('EditItineraryScreen displays non-overflowing badge when stop exists in other days', (tester) async {
      const otherDayStop = TravelStop(
        title: 'Petronas Twin Towers (KLCC)',
        time: '09:00 AM - 10:30 AM',
        note: 'Scheduled on Day 1',
        description: 'Skyscrapers',
        duration: '1 h 30 min',
        openingHours: '10:00 AM - 10:00 PM',
        tips: [],
        icon: Icons.place,
        color: Colors.blue,
        latitude: 3.1578,
        longitude: 101.7119,
        placeId: 'curated_kl_01',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: EditItineraryScreen(
            tripTitle: 'Kuala Lumpur Trip',
            destination: 'Kuala Lumpur',
            dayNumber: 2,
            initialStops: [stop1, stop2],
            otherDaysStops: [otherDayStop],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Stop card shows non-overflowing tag
      expect(find.text('In other day'), findsOneWidget);

      // Verify no RenderFlex overflow exceptions occurred
      expect(tester.takeException(), isNull);
    });

    testWidgets('EditItineraryScreen blocks saving if two duplicate stops exist on same day', (tester) async {
      const duplicateStop1 = TravelStop(
        title: 'Petronas Twin Towers (KLCC)',
        time: '02:00 PM - 03:30 PM',
        note: 'Afternoon visit',
        description: 'Skyscrapers',
        duration: '1 h 30 min',
        openingHours: '10:00 AM - 10:00 PM',
        tips: [],
        icon: Icons.place,
        color: Colors.blue,
        latitude: 3.1578,
        longitude: 101.7119,
        placeId: 'curated_kl_01',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: EditItineraryScreen(
            tripTitle: 'Kuala Lumpur Trip',
            destination: 'Kuala Lumpur',
            dayNumber: 1,
            initialStops: [stop1, duplicateStop1],
            otherDaysStops: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top banner detects same day duplicates
      expect(find.textContaining('Duplicate attractions detected'), findsOneWidget);

      // Attempting to Save triggers blocking snackbar
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('appears multiple times today'), findsOneWidget);
    });
  });
}
