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
                'assets/recognition/danga_bay_waterfront.jpg',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-upcoming-trip')));
    expect(opened, true);
  });

  testWidgets('Upcoming trip shows quick actions when route callback is set', (
    tester,
  ) async {
    var openedPlan = false;
    var openedRoute = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripCard(
            trip: const SavedTrip(
              title: 'Johor Custom Schedule',
              date: 'Nov 23, 2026 (3 Days)',
              detail: '9 stops • RM 366 estimated',
              destination: 'Johor',
              budget: 'Moderate',
              interests: [],
              totalDays: 3,
            ),
            isDark: true,
            onTap: () => openedPlan = true,
            onTodayRouteTap: () => openedRoute = true,
          ),
        ),
      ),
    );
    expect(find.text('Open Plan'), findsOneWidget);
    expect(find.text("Today's Route"), findsOneWidget);
    await tester.tap(find.text("Today's Route"));
    expect(openedRoute, true);
    await tester.tap(find.text('Open Plan'));
    expect(openedPlan, true);
  });
}
