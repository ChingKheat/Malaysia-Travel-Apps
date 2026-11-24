import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/auth/models/travel_preferences.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/itinerary/models/itinerary_models.dart';
import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';
import 'package:smart_travel_planner/features/profile/screens/profile_page.dart';
import 'package:smart_travel_planner/features/profile/services/profile_preferences_service.dart';
import 'package:smart_travel_planner/features/profile/services/travel_footprint.dart';
import 'package:smart_travel_planner/features/profile/widgets/profile_sheets.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';
import 'package:smart_travel_planner/features/places/services/place_wishlist_store.dart';

void main() {
  final auth = AuthService();
  final settings = ProfilePreferencesService.instance;

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() async => auth.logout());

  test(
    'handles legacy and unknown values and round trips planner defaults',
    () {
      const defaults = {
        'travel_pace': 'moderate',
        'budget_tier': 'standard',
        'dietary_requirement': 'none',
      };
      for (final raw in [
        null,
        [],
        {'travel_pace': 'unknown', 'budget_tier': 4},
      ]) {
        expect(TravelPreferences.fromJson(raw).toJson(), defaults);
      }
      const value = TravelPreferences(
        pace: PaceCategory.packed,
        budget: BudgetTier.luxury,
        diet: DietaryPreference.halalFriendly,
      );
      final restored = TravelPreferences.fromJson(value.toJson());
      expect(restored.pace, PaceCategory.packed);
      expect(restored.budget.plannerValue, 'High');
      expect(restored.diet, DietaryPreference.halalFriendly);
    },
  );

  test('retains an offline account save with pending sync', () async {
    expect(await auth.login('tourist@example.com', 'SafeP@ss123!'), isTrue);
    expect(
      await settings.saveTravel(
        const TravelPreferences(diet: DietaryPreference.vegetarian),
      ),
      isTrue,
    );
    await settings.syncTravel();
    final saved = await settings.loadTravel();
    expect(saved.preferences?.diet, DietaryPreference.vegetarian);
    expect(saved.pending, isTrue);
    await auth.logout();
    await auth.loginAsGuest();
    expect((await settings.loadTravel()).preferences, isNull);
  });

  test(
    'footprint counts completed places and deduplicates valid regions',
    () async {
      final day = DateTime(2026, 1, 2);
      final storage = await SharedPreferences.getInstance();
      await storage.setString(
        'trip-execution-v1:trip:0:${day.toIso8601String()}',
        jsonEncode({
          'completed': ['place-b', 'place-c'],
        }),
      );
      ItineraryStop stop(String id, String region, {bool visited = false}) =>
          ItineraryStop(
            id: id,
            scheduleId: 'day',
            placeId: id,
            placeName: id,
            stopOrder: 1,
            arrivalTime: '09:00',
            departureTime: '10:00',
            placeState: region,
            isVisited: visited,
          );
      final footprint = await TravelFootprint.fromTrips([
        Itinerary(
          itineraryId: 'trip',
          userId: 'user',
          title: 'Trip',
          destinationState: 'Johor',
          createdAt: day,
          dailySchedules: [
            DailySchedule(
              scheduleId: 'day',
              itineraryId: 'trip',
              dayNumber: 1,
              scheduleDate: day,
              stops: [
                stop('place-a', 'Pulau Pinang', visited: true),
                stop('place-a', 'Penang', visited: true),
                stop('place-b', 'Penang'),
                stop('place-c', 'Unknown'),
                stop('planned-only', 'Johor'),
              ],
            ),
          ],
        ),
      ]);
      expect(footprint.places, ['place-a', 'place-b', 'place-c']);
      expect(footprint.regions, {'penang'});
    },
  );

  testWidgets('preferences and footprint work on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(auth.loginAsGuest);

    var openedTrips = false;
    Widget app(Key key) => MaterialApp(
      key: key,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    ProfilePage(onMyTripsTap: () => openedTrips = true),
              ),
            ),
            child: const Text('Open profile'),
          ),
        ),
      ),
    );

    Future<void> tap(String label) async {
      final target = find.text(label).last;
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(app(const ValueKey(1)));
    await tap('Open profile');
    expect(find.byKey(const ValueKey('profile-change-photo')), findsOneWidget);
    expect(find.text('Travel Preferences'), findsNothing);

    await tap('Places Visited');
    expect(find.text('Travel Footprint'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('States & territories'), findsNothing);

    expect(find.text('Preferred Currency'), findsNothing);
    expect(find.text('About Smart Travel Planner'), findsNothing);
    await tap('Tourist Emergency Hotlines');
    expect(find.text('999'), findsOneWidget);
    expect(find.text('112'), findsOneWidget);
    const launcher = MethodChannel('plugins.flutter.io/url_launcher');
    final messenger = tester.binding.defaultBinaryMessenger;
    final launched = <String>[];
    messenger.setMockMethodCallHandler(launcher, (call) async {
      expect(call.method, 'launch');
      launched.add((call.arguments as Map)['url'] as String);
      return launched.length > 1;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(launcher, null));
    expect(launched, isEmpty);
    final callButton = find.widgetWithText(TextButton, 'Call').first;
    await tester.ensureVisible(callButton);
    await tester.tap(callButton);
    await tester.pumpAndSettle();
    expect(launched, ['tel:999']);
    expect(find.text('Could not open the phone dialer.'), findsOneWidget);
    await tester.tap(callButton);
    await tester.pumpAndSettle();
    expect(launched, ['tel:999', 'tel:999']);
    expect(find.text('Could not open the phone dialer.'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.pumpWidget(app(const ValueKey(2)));
    await tap('Open profile');
    await tap('Trips Planned');
    expect(openedTrips, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TravelPreferencesEditor saves preferences', (tester) async {
    TravelPreferences? saved;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TravelPreferencesEditor(
            initial: const TravelPreferences(),
            onSave: (val) async {
              saved = val;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Fast-paced'));
    await tester.tap(find.text('Vegetarian'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved?.pace, PaceCategory.packed);
    expect(saved?.diet, DietaryPreference.vegetarian);
  });

  testWidgets('displays saved places and removes them on tap', (tester) async {
    await tester.runAsync(auth.loginAsGuest);
    final uid = auth.currentUser!.uid;
    final wishlist = PlaceWishlistStore(uid);
    await wishlist.add(
      const Attraction(
        xid: 'attr-1',
        name: 'Batu Caves',
        category: 'Landmark',
        latitude: 3.2379,
        longitude: 101.6840,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProfilePage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your Saved Places'), findsOneWidget);
    expect(find.text('Batu Caves'), findsOneWidget);

    final removeBtn = find.byTooltip('Remove from saved').first;
    await tester.ensureVisible(removeBtn);
    await tester.tap(removeBtn);
    await tester.pumpAndSettle();

    expect(find.text('Batu Caves'), findsNothing);
    expect(find.text('No Saved Places Yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
