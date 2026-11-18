import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/screens/today_plan_page.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';

void main() {
  final stops = [
    TravelStop.fromJson({
      'title': 'The Chow Kit Kitchen & Bar',
    }).scheduled(540, 615),
    TravelStop.fromJson({
      'title': 'Perbadanan Kemajuan Kraftangan Malaysia',
    }).scheduled(620, 710, transit: 5),
  ];

  Widget plan({required Brightness brightness, double textScale = 1}) {
    return MaterialApp(
      theme: ThemeData(brightness: brightness),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: TodayPlanPage(
        storageKey: 'today-plan-redesign',
        stops: stops,
        date: DateTime(2026, 11, 18),
        preferences: const TripPreferences(),
      ),
    );
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the primary action follows trip state and restores progress', (
    tester,
  ) async {
    await tester.pumpWidget(plan(brightness: Brightness.dark));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Trip actions'));
    await tester.pumpAndSettle();
    expect(find.text('Skip stop'), findsOneWidget);
    expect(find.text('Delay 15 min'), findsOneWidget);
    await tester.tap(find.text('Pause trip'));
    await tester.pumpAndSettle();
    expect(find.text('Trip paused'), findsOneWidget);

    await tester.tap(find.text('Resume trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark visited'));
    await tester.pumpAndSettle();
    expect(find.text('1 visited · 0 skipped · 1 remaining'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(plan(brightness: Brightness.dark));
    await tester.pumpAndSettle();
    expect(find.text('1 visited · 0 skipped · 1 remaining'), findsOneWidget);
    expect(find.text('Mark visited'), findsOneWidget);

    await tester.tap(find.text('Mark visited'));
    await tester.pumpAndSettle();
    expect(find.text('Day complete'), findsOneWidget);
    expect(find.text('Mark visited'), findsNothing);
  });

  for (final (size, brightness) in [
    (const Size(375, 750), Brightness.dark),
    (const Size(750, 375), Brightness.light),
  ]) {
    testWidgets('the timeline scrolls with enlarged text at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(plan(brightness: brightness, textScale: 2));
      await tester.pumpAndSettle();
      final start = find.text('Start trip');
      final initialPosition = tester.getCenter(start);

      await tester.scrollUntilVisible(
        find.text(stops.last.title),
        100,
        scrollable: find.byType(Scrollable),
      );

      expect(tester.getCenter(start), initialPosition);
      expect(tester.takeException(), isNull);
    });
  }
}
