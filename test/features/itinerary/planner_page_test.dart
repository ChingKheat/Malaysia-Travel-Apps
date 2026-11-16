import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/screens/itinerary_page.dart';
import 'package:smart_travel_planner/features/itinerary/screens/planner_page.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_preferences_service.dart';

void main() {
  testWidgets('all traveler, pace and dining choices can be selected', (
    tester,
  ) async {
    await _openPlanner(
      tester,
      enableTestingBypass: true,
      initialTravelMode: 'Driving',
    );
    for (final labels in [
      ['Couple', 'Family', 'Friends', 'Seniors', 'Solo'],
      [
        'Relaxed (2–3 visits/day)',
        'Balanced (3–4 visits/day)',
        'Packed (5+ visits/day)',
      ],
      [
        'Halal-friendly',
        'Vegetarian',
        'Street food enthusiast',
        'No restriction',
      ],
    ]) {
      Finder chip(String label) => find.widgetWithText(ChoiceChip, label);
      for (final label in labels) {
        await _reveal(tester, chip(label));
        await tester.tap(chip(label));
        await tester.pumpAndSettle();
        for (final option in labels) {
          expect(
            tester.widget<ChoiceChip>(chip(option)).selected,
            option == label,
          );
        }
      }
    }

    for (final label in ['Also open to MRT / LRT', 'Also open to walking']) {
      final checkbox = find.widgetWithText(CheckboxListTile, label);
      await _reveal(tester, checkbox);
      for (final expected in [true, false]) {
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
        expect(tester.widget<CheckboxListTile>(checkbox).value, expected);
      }
    }
  });

  for (final mode in ['Driving', 'Grab / E-hailing', 'Walking', 'Transit']) {
    testWidgets('$mode unlocks budget after its required inputs', (
      tester,
    ) async {
      final start = DateTime(2026, 12, 7);
      await _openPlanner(
        tester,
        initialDestination: 'Kuala Lumpur',
        initialTravelDates: DateTimeRange(start: start, end: start),
        initialDailyStartTime: const TimeOfDay(hour: 9, minute: 0),
        initialDailyEndTime: const TimeOfDay(hour: 18, minute: 0),
      );
      final budget = find.text('Medium');
      await _reveal(tester, budget);
      expect(budget.hitTestable(), findsNothing);

      await _choose(tester, mode);
      if (mode == 'Transit') {
        await _reveal(tester, budget);
        expect(budget.hitTestable(), findsNothing);
        final estimate = find.byType(TextFormField);
        await _reveal(tester, estimate);
        await tester.enterText(estimate, '25');
        await tester.pumpAndSettle();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      }

      await _reveal(tester, budget);
      expect(budget.hitTestable(), findsNothing);
      await _choose(tester, 'Continue to budget & dining');
      await _reveal(tester, budget);
      expect(budget.hitTestable(), findsOneWidget);
      await tester.tap(budget);
      await tester.pumpAndSettle();
      await _choose(tester, 'Continue to highlights & interests');
      await tester.pumpAndSettle();
      final interest = find.widgetWithText(FilterChip, 'Nature');
      await _reveal(tester, interest);
      expect(interest.hitTestable(), findsOneWidget);
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('classic preset applies a Kuala Lumpur origin and highlights', (
      tester,
    ) async {
      await _openPlanner(tester);
      await _choose(tester, 'Quick presets');
      await _choose(tester, 'First-time explorer · culture and KL landmarks');
      expect(find.byType(ItineraryPage), findsNothing);
      await _reveal(tester, find.text('Bukit Bintang'));
      expect(find.text('Bukit Bintang'), findsWidgets);
      await _reveal(tester, find.text('Petronas Twin Towers (KLCC)'));
      expect(find.text('Petronas Twin Towers (KLCC)'), findsOneWidget);
    });

    testWidgets('Plan stays usable at 320 pixels with ${scale}x text', (
      tester,
    ) async {
      await _openPlanner(tester, width: 320, scale: scale);
      await _unlockSchedule(tester);
      await _choose(tester, 'Standard');
      await _choose(tester, 'Continue');
      await _choose(tester, 'Walking');
      await _choose(tester, 'Continue to budget & dining');
      await _choose(tester, 'High');
      await tester.pumpAndSettle();
      await _choose(tester, 'Continue to highlights & interests');
      await _choose(tester, 'Food');
      await _choose(tester, 'Continue');
      _scrollToTop(tester);
      await tester.pumpAndSettle();
      for (final label in [
        'Trip basics',
        'Who & pace',
        'Your daily pace',
        'Getting around',
        'Budget & dining',
        'Highlights & interests',
        'Generate My Itinerary',
      ]) {
        try {
          await _reveal(tester, find.text(label));
        } on StateError {
          fail('Could not scroll to the $label section.');
        }
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
    expect(find.text('High').hitTestable(), findsNothing);
    await _reveal(tester, find.text('Walking'));
    await tester.tap(find.text('Walking'));
    await tester.pumpAndSettle();
    final modeNote = find.text('Enjoy nearby places at a walking pace.');
    await _reveal(tester, modeNote);
    expect(modeNote, findsOneWidget);
    await _choose(tester, 'Continue to budget & dining');

    await _reveal(tester, find.text('High'));
    await tester.tap(find.text('High'));
    await tester.pumpAndSettle();
    await _choose(tester, 'Continue to highlights & interests');
    await tester.pumpAndSettle();
    await _reveal(tester, find.text('Above ~RM900 total'));
    expect(find.text('Above ~RM900 total'), findsOneWidget);

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
    final readyPage = find.byType(ItineraryPage);
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
  });

  testWidgets('Planner starts with empty/clean slate defaults', (tester) async {
    await _openPlanner(tester);
    expect(find.text('Select Destination'), findsOneWidget);
    expect(find.text('Select travel dates'), findsOneWidget);
  });

  testWidgets(
    'Guided flow: steps illuminate with light and transfer to next box upon selection',
    (tester) async {
      await _openPlanner(tester);

      // Initial step: Destination is lit up
      expect(find.text('Select'), findsOneWidget);
      expect(find.text('Next'), findsNothing);

      // Step 1: Select Destination -> lights up Travel Dates
      await tester.tap(find.text('Select Destination'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Johor, Malaysia'));
      await tester.pumpAndSettle();

      // Now Travel Dates has 'Select' light, Destination no longer has light
      expect(find.text('Select'), findsOneWidget);
      expect(find.text('Next'), findsNothing);

      // Step 2: Pick travel dates, then review the optional details.
      await tester.tap(find.text('Select travel dates'));
      await tester.pumpAndSettle();
      final dialog = tester.element(find.byType(DateRangePickerDialog));
      final start = DateUtils.dateOnly(
        DateTime.now(),
      ).add(const Duration(days: 7));
      Navigator.of(dialog).pop(
        DateTimeRange(start: start, end: start.add(const Duration(days: 3))),
      );
      await tester.pumpAndSettle();

      final hours = find.text('Standard');
      await _reveal(tester, hours);
      expect(hours.hitTestable(), findsNothing);
      await _choose(tester, 'Continue to traveler & pace');
      await _reveal(tester, hours);
      expect(hours.hitTestable(), findsNothing);
      await _choose(tester, 'Continue to daily hours');

      // Step 3: Choose schedule and tap Continue -> lights up Getting around
      await _reveal(tester, find.text('Standard'));
      await tester.tap(find.text('Standard'));
      await tester.pumpAndSettle();
      await _choose(tester, 'Continue');

      // Getting around is now illuminated with 'Next'
      expect(find.text('Next'), findsOneWidget);

      // Step 4: Choose Walking to unlock Budget
      await _reveal(tester, find.text('Walking'));
      await tester.tap(find.text('Walking'));
      await tester.pumpAndSettle();

      await _choose(tester, 'Continue to budget & dining');

      // Budget is now illuminated
      expect(find.text('Next'), findsOneWidget);

      // Step 5: Choose a budget to unlock Interests
      await _reveal(tester, find.text('Medium'));
      await tester.tap(find.text('Medium'));
      await tester.pumpAndSettle();
      await _choose(tester, 'Continue to highlights & interests');
      await tester.pumpAndSettle();

      // Interests is now illuminated
      expect(find.text('Next'), findsOneWidget);

      // Step 6: Choose Interest and tap Continue -> lights up Generate button
      await _reveal(tester, find.text('Food'));
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      await _choose(tester, 'Continue');

      // All previous card badges are off
      expect(find.text('Next'), findsNothing);
      expect(find.text('Select'), findsNothing);

      // Tapping on an earlier card (e.g. Daily Budget) re-illuminates it
      _scrollToTop(tester);
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Budget & dining'));
      await tester.tap(find.text('Budget & dining'));
      await tester.pumpAndSettle();
      expect(find.text('Next'), findsOneWidget);
    },
  );
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
    expect(find.text('Select travel dates').hitTestable(), findsNothing);
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
  await _choose(tester, 'Continue to traveler & pace');
  await _choose(tester, 'Continue to daily hours');
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
  if (target.evaluate().isEmpty) {
    final position = tester.state<ScrollableState>(_plannerScrollable).position;
    position.jumpTo(0);
    await tester.pumpAndSettle();
    for (
      var attempt = 0;
      attempt < 60 && target.evaluate().isEmpty;
      attempt++
    ) {
      final next = (position.pixels + 180).clamp(0.0, position.maxScrollExtent);
      if (next <= position.pixels) break;
      position.jumpTo(next);
      await tester.pumpAndSettle();
    }
  }
  expect(target, findsWidgets);
  await tester.ensureVisible(target.first);
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
