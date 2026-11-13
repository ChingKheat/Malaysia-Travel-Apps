import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/screens/itinerary_ready_page.dart';
import 'package:smart_travel_planner/features/itinerary/screens/planner_page.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_preferences_service.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('Plan stays usable at 320 pixels with ${scale}x text', (
      tester,
    ) async {
      await _openPlanner(tester, width: 320, scale: scale);
      await _unlockSchedule(tester);
      await _choose(tester, 'Standard');
      await _choose(tester, 'Continue');
      await _choose(tester, 'High');
      await _choose(tester, 'Walking');
      await _choose(tester, 'Food');
      await _choose(tester, 'Continue');
      _scrollToTop(tester);
      await tester.pumpAndSettle();
      for (final label in [
        'Trip details',
        'Your daily pace',
        'Daily budget',
        'Getting around',
        'Make it your kind of trip',
        'Generate My Itinerary',
      ]) {
        await _reveal(tester, find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
    });
  }

  testWidgets('Pickers and schedule choices keep updating the trip', (
    tester,
  ) async {
    await _openPlanner(tester);
    SharedPreferences.setMockInitialValues({});
    await _unlockSchedule(tester, checkCancellation: true);

    await _reveal(tester, find.text('Standard'));
    await tester.tap(find.text('Standard'));
    await tester.pumpAndSettle();

    await _reveal(tester, find.text('Daily End Time'));
    tester
        .widget<DropdownButton<TimeOfDay>>(
          find.byType(DropdownButton<TimeOfDay>).last,
        )
        .onChanged!(const TimeOfDay(hour: 7, minute: 0));
    await tester.pumpAndSettle();
    await _reveal(tester, find.text('Continue'));
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Continue').first)
          .onPressed,
      isNull,
    );
    expect(
      find.text(TripPreferencesService.m5InvalidTimeRange),
      findsOneWidget,
    );
    _scrollToTop(tester);
    await tester.pumpAndSettle();

    await _reveal(tester, find.text('Relaxed'));
    await tester.tap(find.text('Relaxed'));
    await tester.pumpAndSettle();
    expect(find.text('9 hours of sightseeing per day'), findsOneWidget);

    await _reveal(tester, find.text('High'));
    expect(find.text('High').hitTestable(), findsNothing);
    _scrollToTop(tester);
    await tester.pumpAndSettle();
    await _choose(tester, 'Continue');
    await _reveal(tester, find.text('High'));
    await tester.tap(find.text('High'));
    await tester.pumpAndSettle();
    expect(find.text('Above ~RM900 total'), findsOneWidget);

    await _reveal(tester, find.text('Walking'));
    await tester.tap(find.text('Walking'));
    await tester.pumpAndSettle();
    expect(find.text('Enjoy nearby places at a walking pace.'), findsOneWidget);

    final generate = find.widgetWithText(FilledButton, 'Generate My Itinerary');
    await _reveal(tester, generate);
    expect(tester.widget<FilledButton>(generate).onPressed, isNull);
    _scrollToTop(tester);
    await tester.pumpAndSettle();
    await _choose(tester, 'Food');
    await _choose(tester, 'Food');
    await _reveal(tester, find.text('Continue'));
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Continue').first)
          .onPressed,
      isNull,
    );

    await _reveal(tester, find.text('Nature'));
    await tester.tap(find.text('Nature'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Nature'))
          .selected,
      isTrue,
    );
    await _choose(tester, 'Continue');
    await _reveal(tester, find.text('Generate My Itinerary'));

    _scrollToTop(tester);
    await tester.pumpAndSettle();
    final dateLabel = find.textContaining(RegExp(r'\d{4} - '));
    await _reveal(tester, dateLabel);
    await tester.tap(dateLabel);
    await tester.pumpAndSettle();
    final dialog = tester.element(find.byType(DateRangePickerDialog));
    final start = DateUtils.dateOnly(
      DateTime.now(),
    ).add(const Duration(days: 7));
    Navigator.of(
      dialog,
    ).pop(DateTimeRange(start: start, end: start.add(const Duration(days: 3))));
    await tester.pumpAndSettle();
    await _reveal(tester, find.text('Above ~RM1,200 total'));
    await _choose(tester, 'Generate My Itinerary');
    final readyPage = find.byType(ItineraryReadyPage);
    for (
      var attempt = 0;
      attempt < 20 && readyPage.evaluate().isEmpty;
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pumpAndSettle();
    }
    expect(readyPage, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Generate keeps the existing unsupported transit validation', (
    tester,
  ) async {
    final now = DateTime.now();
    await _openPlanner(
      tester,
      enableTestingBypass: true,
      initialDestination: 'Kuala Lumpur',
      initialTravelDates: DateTimeRange(
        start: DateTime(now.year, now.month, now.day + 2),
        end: DateTime(now.year, now.month, now.day + 5),
      ),
      initialDailyStartTime: const TimeOfDay(hour: 8, minute: 0),
      initialDailyEndTime: const TimeOfDay(hour: 22, minute: 0),
      initialBudgetCategory: 'Medium',
      initialTravelMode: 'Public Transport',
      initialInterests: const {'Food', 'Culture'},
    );
    _scrollToTop(tester);
    await tester.pumpAndSettle();
    await _reveal(tester, find.text('Generate My Itinerary'));
    await tester.tap(find.text('Generate My Itinerary'));
    await tester.pumpAndSettle();
    expect(find.text(TripPreferencesService.m8UnsupportedMode), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Planner starts with empty/clean slate defaults', (tester) async {
    await _openPlanner(tester);
    expect(find.text('Select Destination'), findsOneWidget);
    expect(find.text('Select travel dates'), findsOneWidget);
  });
}

Future<void> _unlockSchedule(
  WidgetTester tester, {
  bool checkCancellation = false,
}) async {
  expect(find.text('Travel dates'), findsOneWidget);
  expect(find.text('Select travel dates').hitTestable(), findsNothing);
  await _choose(tester, 'Select Destination');
  if (checkCancellation) {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Travel dates'), findsOneWidget);
    expect(
      find.text('Select travel dates').hitTestable(),
      findsNothing,
    );
    await _choose(tester, 'Select Destination');
  }
  await tester.tap(find.text('Johor, Malaysia'));
  await tester.pumpAndSettle();

  final dateLabel = find.text('Select travel dates');
  await _reveal(tester, dateLabel);
  await tester.tap(dateLabel);
  await tester.pumpAndSettle();
  if (checkCancellation) {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await _reveal(tester, find.text('Relaxed'));
    expect(find.text('Relaxed').hitTestable(), findsNothing);
    _scrollToTop(tester);
    await tester.pumpAndSettle();
    await _reveal(tester, dateLabel);
    await tester.tap(dateLabel);
    await tester.pumpAndSettle();
  }
  final dialog = find.byType(DateRangePickerDialog);
  final save = MaterialLocalizations.of(tester.element(dialog)).saveButtonLabel;
  await tester.tap(
    find.descendant(
      of: dialog,
      matching: find.textContaining(
        RegExp('^${RegExp.escape(save)}\$', caseSensitive: false),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String label) async {
  final target = find.text(label);
  await _reveal(tester, target);
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

Finder get _plannerScrollable => find
    .descendant(of: find.byType(PlannerPage), matching: find.byType(Scrollable))
    .first;

void _scrollToTop(WidgetTester tester) =>
    tester.state<ScrollableState>(_plannerScrollable).position.jumpTo(0);

Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    180,
    maxScrolls: 60,
    scrollable: _plannerScrollable,
  );
  await tester.pumpAndSettle();
}

Future<void> _openPlanner(
  WidgetTester tester, {
  double width = 400,
  double scale = 1,
  bool enableTestingBypass = false,
  String? initialDestination,
  DateTimeRange? initialTravelDates,
  TimeOfDay? initialDailyStartTime,
  TimeOfDay? initialDailyEndTime,
  Set<String>? initialInterests,
  String? initialBudgetCategory,
  String? initialTravelMode,
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
        body: PlannerPage(
          onItineraryReady: () {},
          onMyTripsTap: () {},
          enableTestingBypass: enableTestingBypass,
          initialDestination: initialDestination,
          initialTravelDates: initialTravelDates,
          initialDailyStartTime: initialDailyStartTime,
          initialDailyEndTime: initialDailyEndTime,
          initialInterests: initialInterests,
          initialBudgetCategory: initialBudgetCategory,
          initialTravelMode: initialTravelMode,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
