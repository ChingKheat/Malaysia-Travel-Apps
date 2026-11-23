import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/itinerary/models/itinerary_models.dart';
import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/screens/itinerary_page.dart';
import 'package:smart_travel_planner/features/itinerary/services/supabase_itinerary_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_preferences_service.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';

void main() {
  testWidgets('Saved itinerary labels only estimated travel times', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    TripPreferencesService.clearPreferences();
    final saved = await tester.runAsync(() async {
      await AuthService().login('tourist@example.com', 'SafeP@ss123!');
      return SupabaseItineraryService().saveItinerary(
        title: 'Route estimate test',
        destinationState: 'Johor',
        totalCost: 0,
        preferences: TripPreferences(
          destination: 'Johor',
          travelMode: 'Driving',
        ),
        dailySchedules: [
          DailySchedule(
            scheduleId: '',
            itineraryId: '',
            dayNumber: 1,
            scheduleDate: DateTime(2026, 11, 22),
            stops: [
              for (final (order, minutes, estimated) in [
                (1, 8, true),
                (2, 12, true),
                (3, 20, false),
              ])
                ItineraryStop(
                  id: '',
                  scheduleId: '',
                  placeId: 'local-$order',
                  placeName: 'Stop $order',
                  stopOrder: order,
                  arrivalTime: '09:00 AM',
                  departureTime: '10:00 AM',
                  snapshot: TravelStop.fromJson({
                    'title': 'Stop $order',
                    'time': '09:00 AM - 10:00 AM',
                    'travel_minutes': minutes,
                    'inbound_mode': 'Driving',
                    'travel_is_estimated': estimated,
                  }),
                ),
            ],
          ),
        ],
      );
    });
    expect(saved?.success, isTrue);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ItineraryPage(initialItineraryId: saved!.itineraryId),
          ),
        ),
      );
      await SupabaseItineraryService().getSavedItineraries(refresh: false);
    });
    await tester.pumpAndSettle();
    expect(find.text('Stop 1'), findsOneWidget);

    expect(find.text('Driving · 8 min · Planning estimate'), findsOneWidget);
    expect(find.text('Driving · 12 min · Planning estimate'), findsOneWidget);
    expect(find.text('Driving · 20 min'), findsOneWidget);
  });
}
