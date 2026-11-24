import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/home/widgets/trip_cards.dart';
import 'package:smart_travel_planner/features/itinerary/models/saved_trip.dart';

void main() {
  testWidgets('Upcoming trip uses a photo card and opens the trip', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripCard(
            trip: const SavedTrip(
              title: 'Johor Custom Schedule',
              date: 'Nov 25, 2026',
              detail: '12 stops',
              destination: 'Johor',
              budget: 'Moderate',
              interests: [],
            ),
            isDark: true,
            onTap: () => opened = true,
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('home-upcoming-trip')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/recognition/trip_schedule_malaysia.png',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-upcoming-trip')));
    expect(opened, true);
  });
}
