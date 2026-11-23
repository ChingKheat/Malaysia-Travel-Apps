import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/screens/itinerary_page.dart';
import 'package:smart_travel_planner/features/itinerary/services/smart_itinerary_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_preferences_service.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';

void main() {
  testWidgets('Itinerary page shows forecast status when travel date is beyond 5 days', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(
      () => AuthService().login('tourist@example.com', 'SafeP@ss123!'),
    );

    // Trip 7 days in the future (beyond 5-day forecast horizon)
    final futureStart = DateTime.now().add(const Duration(days: 7));
    TripPreferencesService.activate(
      TripPreferences(
        destination: 'Johor',
        numberOfDays: 2,
        startDate: futureStart,
        endDate: futureStart.add(const Duration(days: 1)),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: ItineraryPage(compactResult: true),
        ),
      ),
    );

    // Wait for initial async loading
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));

    // Forecast status indicator should be visible
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    expect(find.textContaining('Forecast unavailable'), findsOneWidget);

    // Tapping the indicator reveals the advisory SnackBar
    await tester.tap(find.byIcon(Icons.cloud_off_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.textContaining('5 days of travel'),
      findsOneWidget,
    );

    SmartItineraryService.clearLiveCache();
  });
}
