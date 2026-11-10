import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/itinerary/screens/planner_page.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_preferences_service.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('Plan stays usable at 320 pixels with ${scale}x text', (
      tester,
    ) async {
      await _openPlanner(tester, width: 320, scale: scale);
      for (final label in [
        'Trip details',
        'Your daily pace',
        'Daily budget',
        'Getting around',
        'Make it your kind of trip',
        'Generate My Itinerary',
        'UC300 Flow Testing Tools',
      ]) {
        await _reveal(tester, find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
      await tester.tap(find.text('UC300 Flow Testing Tools'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Test A7 (Transit)'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Pickers and schedule choices keep updating the trip', (
    tester,
  ) async {
    await _openPlanner(tester);
    await _reveal(tester, find.text('Kuala Lumpur, Malaysia'));
    await tester.tap(find.text('Kuala Lumpur, Malaysia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Johor, Malaysia'));
    await tester.pumpAndSettle();
    expect(find.text('Johor, Malaysia'), findsOneWidget);

    final dateLabel = find.textContaining(RegExp(r'\d+ \w+ \d{4} - '));
    await _reveal(tester, dateLabel);
    await tester.tap(dateLabel);
    await tester.pumpAndSettle();
    expect(find.byType(DateRangePickerDialog), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await _reveal(tester, find.text('Relaxed'));
    await tester.tap(find.text('Relaxed'));
    await tester.pumpAndSettle();
    expect(find.text('9 hours of sightseeing per day'), findsOneWidget);

    await _reveal(tester, find.text('High'));
    await tester.tap(find.text('High'));
    await tester.pumpAndSettle();
    expect(find.text('Above ~RM900 total'), findsOneWidget);

    await _reveal(tester, find.text('Walking'));
    await tester.tap(find.text('Walking'));
    await tester.pumpAndSettle();
    expect(find.text('Enjoy nearby places at a walking pace.'), findsOneWidget);

    await _reveal(tester, find.text('Nature'));
    await tester.tap(find.text('Nature'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Nature'))
          .selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Generate keeps the existing unsupported transit validation', (
    tester,
  ) async {
    await _openPlanner(tester);
    await _reveal(tester, find.text('Transit'));
    await tester.tap(find.text('Transit'));
    await tester.pumpAndSettle();
    await _reveal(tester, find.text('Generate My Itinerary'));
    await tester.tap(find.text('Generate My Itinerary'));
    await tester.pumpAndSettle();
    expect(find.text(TripPreferencesService.m8UnsupportedMode), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    180,
    maxScrolls: 60,
    scrollable: find
        .descendant(
          of: find.byType(PlannerPage),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> _openPlanner(
  WidgetTester tester, {
  double width = 400,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: PlannerPage(onItineraryReady: () {}, onMyTripsTap: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
