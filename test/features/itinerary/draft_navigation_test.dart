import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/screens/itinerary_page.dart';
import 'package:smart_travel_planner/features/itinerary/services/smart_itinerary_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/supabase_itinerary_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_preferences_service.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'Back offers a device draft and dismissing keeps the result open',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() => AuthService().login('tourist@example.com', 'SafeP@ss123!'));
      TripPreferencesService.activate(
        TripPreferences(destination: 'Johor', numberOfDays: 1),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(
                      appBar: _Bar(),
                      body: ItineraryPage(compactResult: true),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byType(BackButton));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Leave this itinerary?'), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Leave this itinerary?'), findsNothing);
      expect(find.byType(ItineraryPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Leave this itinerary?'), findsOneWidget);
      await tester.tap(find.text('Decide later'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ItineraryPage), findsNothing);
      final trips = await SupabaseItineraryService().getSavedItineraries(
        refresh: false,
        includeDrafts: true,
      );
      expect(trips.single.isDraft, isTrue);
      expect(TripPreferencesService.storedPreferences, isNull);
      SmartItineraryService.clearLiveCache();
    },
  );
}

class _Bar extends StatelessWidget implements PreferredSizeWidget {
  const _Bar();
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) => AppBar();
}
