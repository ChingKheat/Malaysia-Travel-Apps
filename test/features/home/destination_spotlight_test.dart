import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/app/smart_travel_app.dart';
import 'package:smart_travel_planner/app/travel_shell.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/home/models/spotlight_destination.dart';
import 'package:smart_travel_planner/features/home/screens/home_page.dart';
import 'package:smart_travel_planner/features/home/widgets/destination_spotlight_picker_sheet.dart';
import 'package:smart_travel_planner/features/itinerary/models/destination_leg.dart';
import 'package:smart_travel_planner/features/itinerary/screens/itinerary_page.dart';
import 'package:smart_travel_planner/features/itinerary/screens/planner_page.dart';
import 'package:smart_travel_planner/features/itinerary/services/smart_itinerary_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/supabase_itinerary_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_preferences_service.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';
import 'package:smart_travel_planner/shared/data/malaysia_states.dart';
import 'package:smart_travel_planner/shared/widgets/app_header.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TripPreferencesService.clearPreferences();
    SmartItineraryService.clearLiveCache();
    SupabaseItineraryService.resetOperationsForTesting();
    await AuthService().logout();
  });

  test(
    'every Spotlight destination has a loadable bundled asset and resolves to its exact canonical hub across locales',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      expect(spotlightDestinations.length, inInclusiveRange(5, 6));
      expect(allSpotlightDestinations.length, greaterThan(20));

      for (final item in allSpotlightDestinations) {
        if (item.imageAsset != null) {
          final bytes = await rootBundle.load(item.imageAsset!);
          final codec = await ui.instantiateImageCodec(
            bytes.buffer.asUint8List(),
          );
          final frame = await codec.getNextFrame();
          expect(frame.image.width, greaterThan(0));
          expect(frame.image.height, greaterThan(0));
          frame.image.dispose();
          codec.dispose();
        }

        final state = malaysiaStatesData.singleWhere(
          (s) => s.name == item.stateName,
        );
        final area = state.areas.singleWhere((a) => a.name == item.hubName);
        final leg = item.toDestinationLeg();
        expect(leg.destinationId, item.id);
        expect(leg.stateName, item.stateName);
        expect(leg.hubName, item.hubName);
        expect(leg.latitude, area.latitude);
        expect(leg.longitude, area.longitude);

        for (final locale in AppLocalizations.supportedLocales) {
          final l10n = lookupAppLocalizations(locale);
          expect(item.localizedTitle(l10n), isNotEmpty);
          expect(item.localizedRegion(l10n), isNotEmpty);
          final legInLocale = item.toDestinationLeg();
          expect(legInLocale.destinationId, item.id);
          expect(legInLocale.stateName, item.stateName);
          expect(legInLocale.hubName, item.hubName);
          expect(legInLocale.latitude, area.latitude);
          expect(legInLocale.longitude, area.longitude);
        }
      }
    },
  );

  testWidgets(
    'picker disables Continue at zero selections, supports deselecting, and cancel preserves draft',
    (tester) async {
      await _withOfflineGuestApp(tester, () async {
        // Seed an existing draft in Plan first.
        await tester.tap(_tab('Plan'));
        await tester.pumpAndSettle();
        final today = DateTime.now();
        await tester.tap(find.text('${today.day}').first);
        await tester.pump();
        final endDay = today.day < 28 ? today.day + 1 : today.day;
        await tester.tap(find.text('$endDay').last);
        await tester.pump();
        await tester.tap(find.text('Confirm travel dates'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Select Destination'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Johor'));
        await tester.pumpAndSettle();
        expect(find.text('Johor'), findsOneWidget);

        // Return to Explore, open Spotlight, select, deselect, then cancel.
        await tester.tap(_tab('Explore'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('spotlight-choose-btn')));
        await tester.pumpAndSettle();

        final continueBtn = find.byKey(
          const ValueKey('spotlight-continue-btn'),
        );
        expect(tester.widget<FilledButton>(continueBtn).onPressed, isNull);

        await _tapSpotlightOption(tester, 'langkawi');
        expect(tester.widget<FilledButton>(continueBtn).onPressed, isNotNull);

        await _tapSpotlightOption(tester, 'langkawi');
        expect(tester.widget<FilledButton>(continueBtn).onPressed, isNull);

        // Select Penang, then cancel with close button.
        await _tapSpotlightOption(tester, 'george_town');
        await tester.tap(
          find.byKey(const ValueKey('spotlight-picker-close-btn')),
        );
        await tester.pumpAndSettle();

        // Confirm Plan draft remained Johor untouched.
        await tester.tap(_tab('Plan'));
        await tester.pumpAndSettle();
        expect(find.text('Johor'), findsOneWidget);
        expect(find.text('George Town, Penang'), findsNothing);
      });
    },
  );

  testWidgets(
    'offline first-time guest can select two destinations including Langkawi and reach Plan with exact hubs',
    (tester) async {
      final spotlightHttpCalls = <Uri>[];
      await HttpOverrides.runZoned(() async {
        await _withOfflineGuestApp(tester, () async {
          expect(
            find.byKey(const ValueKey('destination-spotlight-card')),
            findsOneWidget,
          );
          expect(find.text('Where would you like to explore?'), findsOneWidget);
          final cardCenter = tester.getCenter(
            find.byKey(const ValueKey('destination-spotlight-card')),
          );
          expect(cardCenter.dx, closeTo(400, 20));
          expect(cardCenter.dy, inInclusiveRange(450, 750));

          spotlightHttpCalls.clear();
          await tester.tap(find.byKey(const ValueKey('spotlight-choose-btn')));
          await tester.pumpAndSettle();

          // Opening Spotlight picker must trigger zero network calls.
          expect(spotlightHttpCalls, isEmpty);

          await _tapSpotlightOption(tester, 'langkawi');
          await _tapSpotlightOption(tester, 'george_town');

          await tester.tap(
            find.byKey(const ValueKey('spotlight-continue-btn')),
          );
          await tester.pumpAndSettle();

          expect(
            find.descendant(
              of: find.byType(AppHeader),
              matching: find.text('Plan Your Trip'),
            ),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('planner-multi-city-route-card')),
            findsOneWidget,
          );
          expect(find.text('Langkawi, Kedah'), findsOneWidget);
          expect(find.text('George Town, Penang'), findsOneWidget);
          expect(find.text('Start'), findsOneWidget);
        });
      }, createHttpClient: (_) => _OfflineHttpClient(spotlightHttpCalls.add));
    },
  );

  testWidgets(
    'single Spotlight selection opens single-destination mode with exact hub and generates itinerary offline',
    (tester) async {
      await _withOfflineGuestApp(tester, () async {
        await tester.tap(find.byKey(const ValueKey('spotlight-choose-btn')));
        await tester.pumpAndSettle();

        await _tapSpotlightOption(tester, 'langkawi');
        await tester.tap(find.byKey(const ValueKey('spotlight-continue-btn')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('planner-multi-city-route-card')),
          findsNothing,
        );
        expect(find.text('Langkawi, Kedah'), findsOneWidget);

        // Complete the remaining planner steps and generate offline.
        await tester.tap(find.text('Select travel dates'));
        await tester.pumpAndSettle();
        final today = DateTime.now();
        await tester.tap(find.text('${today.day}').first);
        await tester.pump();
        final endDay = today.day < 28 ? today.day + 1 : today.day;
        await tester.tap(find.text('$endDay').last);
        await tester.pump();
        await tester.tap(find.text('Confirm travel dates'));
        await tester.pumpAndSettle();

        await _completePlannerStepsAndGenerate(tester);

        final savedPrefs = TripPreferencesService.storedPreferences;
        expect(savedPrefs, isNotNull);
        expect(savedPrefs!.planningMode, PlanningMode.singleDestination);
        expect(savedPrefs.destination, 'Kedah');
        expect(savedPrefs.effectiveLegs.single.hubName, 'Langkawi');
        expect(savedPrefs.effectiveLegs.single.latitude, 6.35);
        expect(savedPrefs.effectiveLegs.single.longitude, 99.8);
        expect(find.byType(ItineraryPage), findsOneWidget);
      });
    },
  );

  testWidgets(
    'multiple Spotlight hubs including two in Kuala Lumpur remain distinct and preserve first selected hub as start',
    (tester) async {
      await _withOfflineGuestApp(tester, () async {
        await tester.tap(find.byKey(const ValueKey('spotlight-choose-btn')));
        await tester.pumpAndSettle();

        await _tapSpotlightOption(tester, 'johor_bahru');
        await _tapSpotlightOption(tester, 'kuala_lumpur');
        await _tapSpotlightOption(tester, 'batu_caves');

        await tester.tap(find.byKey(const ValueKey('spotlight-continue-btn')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('planner-multi-city-route-card')),
          findsOneWidget,
        );
        expect(find.text('Johor Bahru, Johor'), findsOneWidget);
        expect(find.text('Kuala Lumpur'), findsOneWidget);
        expect(find.text('Batu Caves, Kuala Lumpur'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('remove-leg-johor_bahru')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('remove-leg-kuala_lumpur')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('remove-leg-batu_caves')),
          findsOneWidget,
        );

        // First selected hub (Johor Bahru) must be stop #1 ("Start").
        final jbOffset = tester.getTopLeft(find.text('Johor Bahru, Johor')).dy;
        final klOffset = tester.getTopLeft(find.text('Kuala Lumpur')).dy;
        expect(jbOffset, lessThan(klOffset));
      });
    },
  );

  testWidgets(
    'dismissing Home Spotlight card persists across relaunch and compact entry reopens picker',
    (tester) async {
      await _withOfflineGuestApp(tester, () async {
        await tester.tap(find.byKey(const ValueKey('spotlight-dismiss-btn')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('destination-spotlight-card')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('spotlight-compact-entry')),
          findsOneWidget,
        );
      });

      // Relaunch app with the same persisted SharedPreferences.
      await _withOfflineGuestApp(tester, () async {
        expect(
          find.byKey(const ValueKey('destination-spotlight-card')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('spotlight-compact-entry')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('spotlight-compact-entry')));
        await tester.pumpAndSettle();
        expect(find.byType(DestinationSpotlightPickerSheet), findsOneWidget);
      }, resetMockPrefs: false);

      // Logging out and logging back in shows the centered Spotlight prompt again.
      await tester.runAsync(() => AuthService().logout());
      await _withOfflineGuestApp(tester, () async {
        expect(
          find.byKey(const ValueKey('destination-spotlight-card')),
          findsOneWidget,
        );
      }, resetMockPrefs: false);
    },
  );

  testWidgets(
    'draft protection handles both Keep current draft and Start a new draft and never replays on tab switches',
    (tester) async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'planner_draft_v1_00000000-0000-4000-8000-000000000003': jsonEncode({
          'destination': 'Melaka',
          'startDate': now.add(const Duration(days: 1)).toIso8601String(),
          'endDate': now.add(const Duration(days: 3)).toIso8601String(),
          'destinationConfirmed': true,
          'datesConfirmed': true,
        }),
      });

      await _withOfflineGuestApp(tester, () async {
        // Dismiss the launch restore dialog if shown, then return to Explore.
        if (find
            .byKey(const ValueKey('plan-prompt-continue-btn'))
            .evaluate()
            .isNotEmpty) {
          await tester.tap(
            find.byKey(const ValueKey('plan-prompt-continue-btn')),
          );
          await tester.pumpAndSettle();
          await tester.tap(_tab('Explore'));
          await tester.pumpAndSettle();
        }

        // 1. Restored draft triggers protection -> choose "Keep current draft".
        await tester.tap(find.byKey(const ValueKey('spotlight-choose-btn')));
        await tester.pumpAndSettle();
        await _tapSpotlightOption(tester, 'langkawi');
        await tester.tap(find.byKey(const ValueKey('spotlight-continue-btn')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('spotlight-keep-draft-btn')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('spotlight-keep-draft-btn')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Melaka'), findsOneWidget);
        expect(find.text('Langkawi, Kedah'), findsNothing);

        // 2. Now choose "Start a new draft" from Spotlight.
        await tester.tap(_tab('Explore'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('spotlight-choose-btn')));
        await tester.pumpAndSettle();
        await _tapSpotlightOption(tester, 'langkawi');
        await tester.tap(find.byKey(const ValueKey('spotlight-continue-btn')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('spotlight-new-draft-btn')));
        await tester.pumpAndSettle();

        expect(find.text('Langkawi, Kedah'), findsOneWidget);
        expect(find.text('Melaka'), findsNothing);

        // 3. Edit destination manually, switch away and back -> must not replay Spotlight.
        await tester.tap(find.text('Langkawi, Kedah'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Johor'));
        await tester.pumpAndSettle();
        expect(find.text('Johor'), findsOneWidget);

        await tester.tap(_tab('Explore'));
        await tester.pumpAndSettle();
        await tester.tap(_tab('Plan'));
        await tester.pumpAndSettle();

        expect(find.text('Johor'), findsOneWidget);
        expect(find.text('Langkawi, Kedah'), findsNothing);
      }, resetMockPrefs: false);
    },
  );

  testWidgets(
    'pending Spotlight request awaits in-progress draft restoration before deciding',
    (tester) async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'planner_draft_v1_guest': jsonEncode({
          'destination': 'Melaka',
          'startDate': now.add(const Duration(days: 1)).toIso8601String(),
          'endDate': now.add(const Duration(days: 3)).toIso8601String(),
          'destinationConfirmed': true,
          'datesConfirmed': true,
        }),
      });

      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: PlannerPage(
              userId: 'guest',
              onItineraryReady: () {},
              pendingSpotlightRequest: SpotlightPlannerRequest(
                id: 1,
                destinations: [spotlightDestinations.first],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('spotlight-keep-draft-btn')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('spotlight-keep-draft-btn')));
      await tester.pumpAndSettle();

      expect(find.text('Melaka'), findsOneWidget);
    },
  );

  testWidgets(
    'more hubs than available days retains selections, blocks generation, and unblocks when resolved',
    (tester) async {
      await _withOfflineGuestApp(tester, () async {
        await tester.tap(find.byKey(const ValueKey('spotlight-choose-btn')));
        await tester.pumpAndSettle();
        await _tapSpotlightOption(tester, 'kuala_lumpur');
        await _tapSpotlightOption(tester, 'george_town');
        await _tapSpotlightOption(tester, 'langkawi');
        await tester.tap(find.byKey(const ValueKey('spotlight-continue-btn')));
        await tester.pumpAndSettle();

        // Pick a 2-day trip for 3 destinations.
        await tester.tap(find.text('Select travel dates'));
        await tester.pumpAndSettle();
        final today = DateTime.now();
        await tester.tap(find.text('${today.day}').first);
        await tester.pump();
        final nextDay = today.day < 28 ? today.day + 1 : today.day;
        await tester.tap(find.text('$nextDay').last);
        await tester.pump();
        await tester.tap(find.text('Confirm travel dates'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('planner-duration-conflict-notice')),
          findsOneWidget,
        );
        // All 3 destinations must still be retained.
        expect(find.text('Kuala Lumpur'), findsOneWidget);
        expect(find.text('George Town, Penang'), findsOneWidget);
        expect(find.text('Langkawi, Kedah'), findsOneWidget);

        final generateBtn = find.widgetWithText(
          FilledButton,
          'Generate My Itinerary',
        );
        expect(tester.widget<FilledButton>(generateBtn).onPressed, isNull);

        // Remove one destination to resolve the 3-hub vs 2-day conflict.
        await tester.tap(find.byKey(const ValueKey('remove-leg-langkawi')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('planner-duration-conflict-notice')),
          findsNothing,
        );
        expect(find.text('Langkawi, Kedah'), findsNothing);
        expect(find.text('Kuala Lumpur'), findsOneWidget);
        expect(find.text('George Town, Penang'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'Spotlight Home card and picker fit 320px width with 1.6x text scale without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Scaffold(
            body: HomePage(
              onPlanTap: () {},
              onItineraryTap: () {},
              onRouteTap: () {},
              onAssistantTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('spotlight-choose-btn')),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('spotlight-choose-btn')));
      await tester.pumpAndSettle();

      expect(find.byType(DestinationSpotlightPickerSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dynamic search and shuffle let travelers choose any Malaysian hub beyond the featured five',
    (tester) async {
      await _withOfflineGuestApp(tester, () async {
        await tester.tap(find.byKey(const ValueKey('spotlight-choose-btn')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('spotlight-shuffle-btn')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('spotlight-search-field')),
          'Ipoh',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('spotlight-option-ipoh')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('spotlight-search-field')),
          'Kota Kinabalu',
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('spotlight-option-kota_kinabalu')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('spotlight-continue-btn')));
        await tester.pumpAndSettle();

        expect(find.text('Ipoh, Perak'), findsOneWidget);
        expect(find.text('Kota Kinabalu, Sabah'), findsOneWidget);
      });
    },
  );

  test(
    'hubs without a matching bundled place photo never borrow another hub photo',
    () {
      final byId = {for (final item in allSpotlightDestinations) item.id: item};

      expect(byId['subang_jaya']?.imageAsset, isNull);
      expect(byId['putrajaya']?.imageAsset, isNull);
      expect(byId['kajang']?.imageAsset, isNull);
      expect(byId['rawang']?.imageAsset, isNull);

      expect(byId['kajang']?.highlightName, isNull);
      expect(byId['rawang']?.highlightName, isNull);
      expect(byId['putrajaya']?.highlightName, 'Putra Mosque (Pink Mosque)');

      expect(
        byId['kuala_lumpur']?.imageAsset,
        'assets/recognition/petronas.jpg',
      );
      expect(
        byId['batu_caves']?.imageAsset,
        'assets/recognition/batu_caves.jpg',
      );
    },
  );
}

Future<void> _tapSpotlightOption(WidgetTester tester, String id) async {
  final option = find.byKey(ValueKey('spotlight-option-$id'));
  if (option.evaluate().isEmpty) {
    final pickerList = find.descendant(
      of: find.descendant(
        of: find.byType(DestinationSpotlightPickerSheet),
        matching: find.byType(ListView),
      ),
      matching: find.byType(Scrollable),
    );
    tester.state<ScrollableState>(pickerList.first).position.jumpTo(0);
    await tester.pump();
    await tester.scrollUntilVisible(option, 240, scrollable: pickerList.first);
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(option);
  await tester.pumpAndSettle();
  await tester.tap(option);
  await tester.pumpAndSettle();
}

Finder _tab(String label) => find.descendant(
  of: find.byType(TravelBottomNavigation),
  matching: find.text(label),
);

Future<void> _completePlannerStepsAndGenerate(WidgetTester tester) async {
  Future<void> tapText(String text) async {
    final finder = find.text(text).first;
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  await tapText('Continue to traveler & pace');
  await tapText('Continue to daily hours');
  await tapText('Standard');
  await tapText('Continue');
  await tapText('Driving');
  await tapText('Continue to budget & dining');
  await tapText('Medium');
  await tapText('Continue to highlights & interests');
  await tapText('Nature');
  await tapText('Continue');
  await tapText('Generate My Itinerary');
}

Future<void> _withOfflineGuestApp(
  WidgetTester tester,
  Future<void> Function() check, {
  bool resetMockPrefs = true,
  void Function(Uri)? onHttpCall,
}) async {
  if (resetMockPrefs) {
    SharedPreferences.setMockInitialValues({});
  }
  debugNetworkImageHttpClientProvider = () => _OfflineHttpClient(onHttpCall);
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  try {
    await tester.runAsync(() => AuthService().loginAsGuest());
    await tester.pumpWidget(const SmartTravelApp());
    await tester.pumpAndSettle();
    await check();
  } finally {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    debugNetworkImageHttpClientProvider = null;
  }
}

class _OfflineHttpClient extends Fake implements HttpClient {
  _OfflineHttpClient(this.onHttpCall);
  final void Function(Uri)? onHttpCall;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    onHttpCall?.call(url);
    throw const SocketException('Offline airplane mode');
  }
}
