import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/screens/planner_page.dart';
import 'package:smart_travel_planner/features/places/services/place_wishlist_store.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openPlanner(
    WidgetTester tester, {
    String userId = 'saved-test-user',
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PlannerPage(
            userId: userId,
            onItineraryReady: () {},
            onMyTripsTap: () {},
            enableTestingBypass: true,
            initialDestination: 'Kuala Lumpur',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows feedback snackbar when user has no saved places',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await openPlanner(tester, userId: 'empty-user');

      final btn = find.byKey(const ValueKey('plan-from-saved-places-btn'));
      expect(btn, findsOneWidget);

      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.textContaining('No saved places found'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'opens saved places sheet, selects and applies to must-visit attractions',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = PlaceWishlistStore('saved-user-1');
      await store.add(
        Attraction(
          xid: 'curated_kl_01',
          name: 'Petronas Twin Towers',
          latitude: 3.1579,
          longitude: 101.7123,
          category: 'Landmark',
          description: 'Iconic twin skyscrapers in Kuala Lumpur',
        ),
      );
      await store.add(
        Attraction(
          xid: 'curated_kl_02',
          name: 'Batu Caves',
          latitude: 3.2379,
          longitude: 101.6840,
          category: 'Culture',
          description: 'Limestone hill with Hindu shrines',
        ),
      );

      await openPlanner(tester, userId: 'saved-user-1');

      final btn = find.byKey(const ValueKey('plan-from-saved-places-btn'));
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      // Check bottom sheet title and items
      expect(find.text('Select Saved Places'), findsOneWidget);
      expect(find.text('Petronas Twin Towers'), findsOneWidget);
      expect(find.text('Batu Caves'), findsOneWidget);

      // Tap on Petronas Twin Towers item to select it
      await tester.tap(find.text('Petronas Twin Towers'));
      await tester.pumpAndSettle();

      // Tap Apply selected button
      final confirmBtn = find.byKey(
        const ValueKey('apply-saved-places-confirm-btn'),
      );
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Bottom sheet is closed, must-visit chip is rendered
      expect(find.text('Select Saved Places'), findsNothing);
      expect(find.text('Petronas Twin Towers'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);

      // Tap deleted on the chip removes it
      final deleteIcon = find.descendant(
        of: find.byKey(const ValueKey('must-visit-chip-curated_kl_01')),
        matching: find.byIcon(Icons.cancel),
      );
      if (deleteIcon.evaluate().isNotEmpty) {
        await tester.tap(deleteIcon);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('must-visit-chip-curated_kl_01')), findsNothing);
      }
    },
  );

  testWidgets(
    'disables button when 3 must-visit attractions are added',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = PlaceWishlistStore('saved-user-limit');
      for (var i = 1; i <= 3; i++) {
        await store.add(
          Attraction(
            xid: 'curated_kl_0$i',
            name: 'Place $i',
            latitude: 3.15 + i * 0.01,
            longitude: 101.71,
            category: 'Landmark',
          ),
        );
      }

      await openPlanner(tester, userId: 'saved-user-limit');

      final btn = find.byKey(const ValueKey('plan-from-saved-places-btn'));
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      // Select all 3 places
      await tester.tap(find.text('Place 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Place 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Place 3'));
      await tester.pumpAndSettle();

      // Confirm apply
      await tester.tap(find.byKey(const ValueKey('apply-saved-places-confirm-btn')));
      await tester.pumpAndSettle();

      // Badge should show 3/3
      expect(find.text('3/3'), findsOneWidget);

      // From saved places button should now have onPressed == null (disabled)
      final outlinedBtn = tester.widget<OutlinedButton>(btn);
      expect(outlinedBtn.onPressed, isNull);
    },
  );
}
