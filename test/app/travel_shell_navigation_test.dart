import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/app/smart_travel_app.dart';
import 'package:smart_travel_planner/app/travel_shell.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/screens/itinerary_ready_page.dart';
import 'package:smart_travel_planner/features/itinerary/screens/my_trips_screen.dart';
import 'package:smart_travel_planner/features/itinerary/screens/planner_page.dart';
import 'package:smart_travel_planner/features/itinerary/services/smart_itinerary_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_preferences_service.dart';
import 'package:smart_travel_planner/shared/widgets/app_header.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TripPreferencesService.clearPreferences();
    SmartItineraryService.clearLiveCache();
  });

  testWidgets(
    'Five tabs open their destinations and Home opens empty My Trips',
    (tester) async {
      await _withApp(tester, () async {
        for (final entry in {
          'Explore': 'Explore Malaysia',
          'Recognize': 'Image Recognition',
          'Plan': 'Plan Your Trip',
          'AI': 'Trip Assistant',
        }.entries) {
          await tester.tap(_tab(entry.key));
          await tester.pumpAndSettle();
          if (entry.key == 'Recognize') {
            expect(find.text(entry.value), findsOneWidget);
            expect(find.byTooltip('Notifications'), findsNothing);
          } else {
            expect(
              find.descendant(
                of: find.byType(AppHeader),
                matching: find.text(entry.value),
              ),
              findsOneWidget,
            );
          }
        }
        await tester.tap(_tab('Home'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('home-my-trips')));
        await tester.pumpAndSettle();
        expect(find.byType(MyTripsScreen), findsOneWidget);
        expect(find.text('Plan Your Trip'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('home-my-trips')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'Empty trips opens Plan and My Trips preserves the planner draft',
    (tester) async {
      await _withApp(tester, () async {
        await tester.tap(find.byKey(const ValueKey('home-my-trips')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Plan Your Trip'));
        await tester.pumpAndSettle();
        expect(find.byType(MyTripsScreen), findsNothing);
        expect(find.byKey(const ValueKey('plan-my-trips')), findsOneWidget);

        await tester.tap(find.text('Kuala Lumpur, Malaysia'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Johor, Malaysia'));
        await tester.pumpAndSettle();
        expect(find.text('Johor, Malaysia'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('plan-my-trips')));
        await tester.pumpAndSettle();
        expect(find.byType(MyTripsScreen), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Johor, Malaysia'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets('View Itinerary opens My Trips and back returns to Plan', (
    tester,
  ) async {
    await _withApp(tester, () async {
      await tester.tap(_tab('Plan'));
      await tester.pumpAndSettle();
      final planner = tester.widget<PlannerPage>(find.byType(PlannerPage));
      // Use the planner's completion callback without requesting live APIs.
      unawaited(
        Navigator.of(tester.element(find.byType(PlannerPage))).push<void>(
          MaterialPageRoute(
            builder: (_) =>
                ItineraryReadyPage(onViewItinerary: planner.onItineraryReady),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View Itinerary'));
      await tester.tap(find.text('View Itinerary'));
      await tester.pumpAndSettle();
      expect(find.byType(MyTripsScreen), findsOneWidget);
      expect(find.byType(ItineraryReadyPage), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('plan-my-trips')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('My Trips retains the selected day and supports system back', (
    tester,
  ) async {
    final validation = TripPreferencesService.validatePreferences(
      const TripPreferences(
        destination: 'Kuala Lumpur',
        numberOfDays: 2,
        dailyStartTime: TimeOfDay(hour: 9, minute: 0),
        dailyEndTime: TimeOfDay(hour: 21, minute: 0),
        interests: ['Culture'],
        budgetCategory: 'Medium',
        travelMode: 'Driving',
      ),
    );
    expect(validation.success, isTrue);
    await _withApp(tester, () async {
      await tester.tap(find.byKey(const ValueKey('home-my-trips')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Day 2'));
      await tester.pumpAndSettle();
      expect(find.text('Day 2 Theme'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-my-trips')), findsOneWidget);
      await tester.tap(_tab('Plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plan-my-trips')));
      await tester.pumpAndSettle();
      expect(find.text('Day 2 Theme'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Finder _tab(String label) => find.descendant(
  of: find.byType(TravelBottomNavigation),
  matching: find.text(label),
);

Future<void> _withApp(
  WidgetTester tester,
  Future<void> Function() check,
) async {
  debugNetworkImageHttpClientProvider = () => _ImageClient();
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

// Keep avatar and place images deterministic without external HTTP requests.
final _imageBytes = File('assets/recognition/nasi_lemak.jpg').readAsBytesSync();

class _ImageClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _ImageRequest();
}

class _ImageRequest extends Fake implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => _ImageResponse();
}

class _ImageResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => HttpStatus.ok;
  @override
  int get contentLength => _imageBytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(_imageBytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
