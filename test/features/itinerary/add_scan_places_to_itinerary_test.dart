import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/screens/itinerary_page.dart';
import 'package:smart_travel_planner/features/itinerary/screens/planner_page.dart';
import 'package:smart_travel_planner/features/itinerary/services/scan_plan_places_store.dart';
import 'package:smart_travel_planner/features/itinerary/services/smart_itinerary_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_preferences_service.dart';
import 'package:smart_travel_planner/features/places/services/place_wishlist_store.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const petronas = Attraction(
    xid: 'curated_kl_01',
    name: 'Petronas Twin Towers',
    latitude: 3.1579,
    longitude: 101.7123,
    category: 'Sights, Landmark, Architecture',
    description: 'Iconic twin skyscrapers in Kuala Lumpur.',
  );

  const saloma = Attraction(
    xid: 'curated_kl_saloma',
    name: 'Saloma Link Bridge',
    latitude: 3.1627,
    longitude: 101.7077,
    category: 'Sights, Landmark, Architecture',
    description: 'Pedestrian bridge in Kampung Baru, Kuala Lumpur.',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ScanPlanPlacesStore.resetForTesting();
    TripPreferencesService.clearPreferences();
    SmartItineraryService.clearLiveCache();
  });

  Widget testApp(Widget child) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  testWidgets(
    'PlannerPage shows scanned places at top, auto-fills city & interest, and marks them already added in From saved places',
    (tester) async {
      tester.view.physicalSize = const Size(420, 920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const userId = 'planner-autofill-user';
      final scanStore = ScanPlanPlacesStore(userId);
      await scanStore.add(petronas);
      await scanStore.add(saloma);

      final wishlist = PlaceWishlistStore(userId);
      await wishlist.add(petronas);
      await wishlist.add(
        const Attraction(
          xid: 'curated_kl_02',
          name: 'Batu Caves',
          latitude: 3.2379,
          longitude: 101.6840,
          category: 'Culture',
        ),
      );

      await tester.pumpWidget(
        testApp(
          PlannerPage(
            userId: userId,
            useModernPicker: true,
            initialTravelDates: DateTimeRange(
              start: DateTime(2026, 12, 1),
              end: DateTime(2026, 12, 3),
            ),
            initialDailyStartTime: const TimeOfDay(hour: 9, minute: 0),
            initialDailyEndTime: const TimeOfDay(hour: 20, minute: 0),
            initialBudgetCategory: 'Medium',
            initialTravelMode: 'Driving',
            onItineraryReady: () {},
            onMyTripsTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top scan card is immediately visible, with auto-filled city & notice.
      expect(
        find.byKey(const ValueKey('planner-scan-places-card')),
        findsOneWidget,
      );
      expect(find.text('Petronas Twin Towers'), findsOneWidget);
      expect(find.text('Saloma Link Bridge'), findsOneWidget);
      expect(find.text('Kuala Lumpur'), findsOneWidget);
      expect(
        find.text('Destination & interests pre-filled from your scanned places.'),
        findsOneWidget,
      );

      // Open From saved places and verify Petronas is marked Already added.
      final optionalTile = find.text('Optional: Add must-visit places');
      await tester.ensureVisible(optionalTile);
      await tester.tap(optionalTile);
      await tester.pumpAndSettle();

      final savedBtn = find.byKey(const ValueKey('plan-from-saved-places-btn'));
      await tester.ensureVisible(savedBtn);
      await tester.tap(savedBtn);
      await tester.pumpAndSettle();

      expect(find.text('Select Saved Places'), findsOneWidget);
      expect(find.text('Already added'), findsWidgets);
    },
  );

  testWidgets(
    'PlannerPage prioritizes scanned places as mustVisitPlaces when generating itinerary',
    (tester) async {
      tester.view.physicalSize = const Size(420, 920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const userId = 'planner-priority-user';
      final scanStore = ScanPlanPlacesStore(userId);
      await scanStore.add(petronas);

      final travelDay = DateUtils.dateOnly(
        DateTime.now(),
      ).add(const Duration(days: 7));

      await tester.pumpWidget(
        testApp(
          PlannerPage(
            userId: userId,
            enableTestingBypass: true,
            initialDestination: 'Kuala Lumpur',
            initialTravelDates: DateTimeRange(start: travelDay, end: travelDay),
            initialDailyStartTime: const TimeOfDay(hour: 9, minute: 0),
            initialDailyEndTime: const TimeOfDay(hour: 20, minute: 0),
            initialInterests: const {'Culture'},
            initialBudgetCategory: 'Medium',
            initialTravelMode: 'Driving',
            onItineraryReady: () {},
            onMyTripsTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final generateBtn = find.text('Generate My Itinerary');
      await tester.ensureVisible(generateBtn);
      await tester.tap(generateBtn);
      await tester.pumpAndSettle();

      expect(find.byType(ItineraryPage), findsOneWidget);
      final prefs = TripPreferencesService.storedPreferences;
      expect(prefs, isNotNull);
      expect(
        prefs!.mustVisitPlaces.map((p) => p.title),
        contains('Petronas Twin Towers'),
      );
    },
  );
}
