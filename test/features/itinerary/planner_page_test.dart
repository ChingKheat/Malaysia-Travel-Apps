import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/screens/itinerary_page.dart';
import 'package:smart_travel_planner/features/itinerary/screens/planner_page.dart';
import 'package:smart_travel_planner/features/itinerary/services/smart_itinerary_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_preferences_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/scan_plan_places_store.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';

void main() {
  const locationChannel = MethodChannel('flutter.baseflow.com/geolocator');

  testWidgets('the generated schedule starts from the selected GPS position', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final messenger = tester.binding.defaultBinaryMessenger;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(locationChannel, (call) async {
      calls.add(call.method);
      return switch (call.method) {
        'isLocationServiceEnabled' => true,
        'checkPermission' => 0,
        'requestPermission' => 2,
        'getCurrentPosition' => {'latitude': 3.1579, 'longitude': 101.7123},
        _ => null,
      };
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(locationChannel, null),
    );
    addTearDown(TripPreferencesService.clearPreferences);
    addTearDown(SmartItineraryService.clearLiveCache);

    final travelDay = DateUtils.dateOnly(
      DateTime.now(),
    ).add(const Duration(days: 7));
    await _openPlanner(
      tester,
      initialDestination: 'Kuala Lumpur',
      enableTestingBypass: true,
      initialTravelDates: DateTimeRange(start: travelDay, end: travelDay),
      initialDailyStartTime: const TimeOfDay(hour: 8, minute: 0),
      initialDailyEndTime: const TimeOfDay(hour: 20, minute: 0),
      initialInterests: const {'Culture'},
      initialBudgetCategory: 'Medium',
      initialTravelMode: 'Driving',
    );
    await _choose(tester, 'Daily starting point (optional)');
    expect(calls, isEmpty);
    await _choose(tester, 'Use current location');
    expect(calls, [
      'isLocationServiceEnabled',
      'checkPermission',
      'requestPermission',
      'getCurrentPosition',
    ]);
    expect(find.text('Current location'), findsOneWidget);
    expect(find.byTooltip('Clear starting point'), findsOneWidget);
    await _choose(tester, 'Generate My Itinerary');

    final origin = TripPreferencesService.storedPreferences?.dailyOrigin;
    expect(origin?.latitude, 3.1579);
    expect(origin?.longitude, 101.7123);
    expect(find.byType(ItineraryPage), findsOneWidget);
  });

  testWidgets('a place can still be chosen when GPS is unavailable', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(locationChannel, (_) async => false);
    addTearDown(
      () => messenger.setMockMethodCallHandler(locationChannel, null),
    );

    await _openPlanner(
      tester,
      initialDestination: 'Kuala Lumpur',
      enableTestingBypass: true,
    );
    await _choose(tester, 'Daily starting point (optional)');
    await _choose(tester, 'Use current location');
    expect(
      find.text('Couldn’t get your location. Try again or choose a place.'),
      findsOneWidget,
    );
    await _choose(tester, 'KL Sentral');
    expect(find.text('KL Sentral'), findsOneWidget);
  });

  testWidgets('daily starting point suggestions stay in the trip state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final places = GooglePlacesService(
      endpoint: 'https://project.test/functions/v1/google-places',
      accessToken: 'test-session',
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['operation'], 'planner_search');
        expect(body['state'], 'Johor');
        return http.Response(
          jsonEncode({
            'places': [
              {
                'id': 'ChIJPetronasKL',
                'displayName': {'text': 'Petronas Twin Towers (KLCC)'},
                'formattedAddress':
                    'Jalan Ampang, 50088 Kuala Lumpur, Malaysia',
                'location': {'latitude': 3.1579, 'longitude': 101.7116},
              },
              {
                'id': 'ChIJPetronasJohor',
                'displayName': {'text': 'PETRONAS Johor Bahru'},
                'formattedAddress':
                    "Jalan Tampoi, 81200 Johor Bahru, Johor Darul Ta'zim, Malaysia",
                'location': {'latitude': 1.49, 'longitude': 103.71},
              },
            ],
          }),
          200,
        );
      }),
    );
    await _openPlanner(
      tester,
      initialDestination: 'Johor',
      enableTestingBypass: true,
      startingPointPlaces: places,
    );
    await _choose(tester, 'Daily starting point (optional)');

    final outOfState = find.text('Petronas Twin Towers (KLCC)');
    expect(outOfState, findsNothing);
    expect(find.text('Tan Hiok Nee Cultural Street'), findsOneWidget);
    final legolandRow = find.widgetWithText(
      ListTile,
      'Legoland Malaysia Resort',
    );
    final legolandPhoto = tester.widget<Image>(
      find.descendant(of: legolandRow, matching: find.byType(Image)),
    );
    expect(
      (legolandPhoto.image as ResizeImage).imageProvider,
      const AssetImage('assets/recognition/legoland_malaysia.jpg'),
    );

    await tester.enterText(find.byType(TextField), 'petronas');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(outOfState, findsNothing);
    final localResult = find.text('PETRONAS Johor Bahru');
    expect(localResult.hitTestable(), findsOneWidget);
    final onlineRow = find.widgetWithText(ListTile, 'PETRONAS Johor Bahru');
    expect(
      find.descendant(
        of: onlineRow,
        matching: find.byIcon(Icons.place_outlined),
      ),
      findsOneWidget,
    );
    await tester.tap(localResult);
    await tester.pumpAndSettle();
    expect(localResult, findsOneWidget);
  });

  testWidgets(
    'typing a partial daily starting point shows selectable matches',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final queries = <String>[];
      final places = GooglePlacesService(
        endpoint: 'https://project.test/functions/v1/google-places',
        accessToken: 'test-session',
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['operation'], 'planner_search');
          expect(body['state'], 'Kuala Lumpur');
          queries.add(body['query'] as String);
          return http.Response(
            jsonEncode({
              'places': [
                for (final number in [15, 16, 18])
                  {
                    'id': 'ChIJPV$number',
                    'displayName': {'text': 'PV$number'},
                    'formattedAddress': 'Setapak, Kuala Lumpur',
                    'location': {'latitude': 3.19, 'longitude': 101.72},
                  },
              ],
            }),
            200,
          );
        }),
      );
      await _openPlanner(
        tester,
        initialDestination: 'Kuala Lumpur',
        enableTestingBypass: true,
        startingPointPlaces: places,
      );
      await _choose(tester, 'Daily starting point (optional)');

      final input = find.byType(TextField);
      await tester.enterText(input, 'pt');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(input, 'pv');
      await tester.pump();
      expect(queries, isEmpty);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(queries, ['pv']);
      for (final name in ['PV15', 'PV16', 'PV18']) {
        expect(find.text(name).hitTestable(), findsOneWidget);
      }
      await tester.tap(find.text('PV16'));
      await tester.pumpAndSettle();
      expect(find.text('PV16'), findsOneWidget);
      expect(find.text('PV15'), findsNothing);
    },
  );

  testWidgets('an unlisted hotel can be used as the daily starting point', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _openPlanner(
      tester,
      initialDestination: 'Kuala Lumpur',
      enableTestingBypass: true,
    );
    final origin = find.text('Daily starting point (optional)');
    expect(origin, findsOneWidget);
    await _choose(tester, 'Daily starting point (optional)');

    const hotel = 'Unlisted Garden Hotel';
    await tester.enterText(find.byType(TextField), hotel);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add starting point manually'));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(of: dialog, matching: find.text(hotel)),
      findsOneWidget,
    );
    final coordinates = find.descendant(
      of: dialog,
      matching: find.widgetWithText(TextFormField, 'Coordinates'),
    );
    await tester.enterText(coordinates, '91, 101.7123');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(dialog, findsOneWidget);
    expect(find.text('Enter valid latitude and longitude.'), findsOneWidget);

    await tester.enterText(coordinates, '3.1579, 101.7123');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(find.text(hotel), findsOneWidget);
    final clearOrigin = find.byTooltip('Clear starting point');
    await _reveal(tester, clearOrigin);
    await tester.tap(clearOrigin);
    await tester.pumpAndSettle();
    expect(find.text(hotel), findsNothing);
    expect(find.text('Choose a place'), findsOneWidget);
  });

  testWidgets('places selected from Scan appear under highlights', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = ScanPlanPlacesStore('planner-scan-test');
    await store.add(
      const Attraction(
        xid: 'google_klccpark',
        name: 'KLCC Park',
        latitude: 3.15,
        longitude: 101.71,
        category: 'Park',
      ),
    );
    await _openPlanner(
      tester,
      userId: 'planner-scan-test',
      enableTestingBypass: true,
    );
    final place = find.byKey(const ValueKey('plan-scan-place-google_klccpark'));
    await _reveal(tester, place);
    expect(find.text('KLCC Park'), findsOneWidget);
    expect(find.text('Places selected for your plan'), findsOneWidget);
  });

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
      Finder chip(String label) => find.widgetWithText(SelectionCard, label);
      for (final label in labels) {
        await _reveal(tester, chip(label).first);
        await tester.tap(chip(label).first);
        await tester.pumpAndSettle();
        for (final option in labels) {
          expect(
            tester.widgetList<SelectionCard>(chip(option)).first.selected,
            option == label,
          );
        }
      }
    }

    expect(find.text('Also open to MRT / LRT'), findsNothing);
    expect(find.text('Also open to walking'), findsNothing);
  });

  for (final mode in ['Driving', 'Grab / E-hailing', 'Transit']) {
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
        expect(
          find.text(
            'Enter 1–240 minutes, including walking, waiting and transfers.',
          ),
          findsOneWidget,
        );
        await tester.enterText(estimate, '241');
        await tester.pumpAndSettle();
        expect(
          find.text('Enter a whole number from 1 to 240.'),
          findsOneWidget,
        );
        final continueButton = find.widgetWithText(
          TextButton,
          'Continue to budget & dining',
        );
        expect(tester.widget<TextButton>(continueButton).onPressed, isNull);
        await tester.enterText(estimate, '25');
        await tester.pumpAndSettle();
        expect(find.text('Enter a whole number from 1 to 240.'), findsNothing);
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
      final interest = find.widgetWithText(SelectionCard, 'Nature');
      await _reveal(tester, interest);
      expect(interest.hitTestable(), findsOneWidget);
    });
  }

  testWidgets('planning progress stays visible while scrolling', (
    tester,
  ) async {
    await _openPlanner(tester);
    final progress = find.byKey(const ValueKey('plan-progress'));
    final initialPosition = tester.getTopLeft(progress);
    expect(find.text('0 of 5 sections completed'), findsOneWidget);
    await _reveal(tester, find.text('Generate My Itinerary'));
    expect(progress.hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(progress), initialPosition);
    _scrollToTop(tester);
    await tester.pumpAndSettle();
    await _unlockSchedule(tester);
    expect(find.text('1 of 5 sections completed'), findsOneWidget);
    expect(tester.getTopLeft(progress), initialPosition);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('Plan stays usable at 320 pixels with ${scale}x text', (
      tester,
    ) async {
      await _openPlanner(tester, width: 320, scale: scale);
      await _unlockSchedule(tester);
      await _choose(tester, 'Standard');
      await _choose(tester, 'Continue');
      await _choose(tester, 'Driving');
      if (scale == 2.0) {
        await _choose(tester, 'Transit');
        final estimate = find.byType(TextFormField);
        await _reveal(tester, estimate);
        await tester.enterText(estimate, '25');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
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
    await _reveal(tester, find.text('Driving'));
    await tester.tap(find.text('Driving'));
    await tester.pumpAndSettle();
    final modeNote = find.text('Explore further by car or e-hailing.');
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
          .widget<SelectionCard>(find.widgetWithText(SelectionCard, 'Nature'))
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

      // The entire basics section is highlighted while its inputs are active.
      final basics = find.byKey(const ValueKey('trip-basics-section'));
      double basicsBorderWidth() {
        final container = tester.widget<AnimatedContainer>(
          find
              .descendant(of: basics, matching: find.byType(AnimatedContainer))
              .first,
        );
        return (container.decoration! as BoxDecoration).border!.top.width;
      }

      expect(basicsBorderWidth(), 2);
      // Initial step: Destination is lit up
      expect(find.text('Select'), findsOneWidget);
      expect(find.text('Next'), findsNothing);

      // Step 1: Select Destination -> lights up Travel Dates
      await tester.tap(find.text('Select Destination'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Johor'));
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
      expect(basicsBorderWidth(), 1);
      await _reveal(tester, hours);
      expect(hours.hitTestable(), findsNothing);
      await _choose(tester, 'Continue to daily hours');

      // Step 3: Choose schedule and tap Continue -> lights up Getting around
      await _reveal(tester, find.text('Standard'));
      await tester.tap(find.text('Standard'));
      await tester.pumpAndSettle();
      await _choose(tester, 'Continue');

      expect(find.text('Next'), findsNothing);

      // Step 4: Choose Driving to unlock Budget
      await _reveal(tester, find.text('Driving'));
      await tester.tap(find.text('Driving'));
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
  await tester.tap(find.text('Johor'));
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
  String userId = 'guest',
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
  GooglePlacesService? startingPointPlaces,
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
          userId: userId,
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
          startingPointPlaces: startingPointPlaces,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
