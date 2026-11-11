import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/home/screens/home_page.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_preferences_service.dart';
import 'package:smart_travel_planner/features/places/screens/api_retrieval_screen.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TripPreferencesService.clearPreferences();
    await AuthService().logout();
  });

  testWidgets(
    'Saved Places Inspector banner is hidden for non-admins and shown for admins',
    (tester) async {
      debugNetworkImageHttpClientProvider = () => _FakeImageClient();
      try {
        await tester.runAsync(() => AuthService().loginAsGuest());

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
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

        // Hidden for guest user.
        expect(find.text('Saved Places Inspector'), findsNothing);
        expect(find.byType(HeroPanel), findsOneWidget);

        // Hidden for regular tourist account.
        await tester.runAsync(
          () => AuthService().login('tourist@example.com', 'SafeP@ss123!'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Saved Places Inspector'), findsNothing);

        // Visible when logged in as admin, and opens ApiRetrievalScreen.
        await tester.runAsync(
          () => AuthService().login('chingkheat@example.com', 'SafeP@ss123!'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Saved Places Inspector'), findsOneWidget);

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.byType(ApiRetrievalScreen), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();

        // Hidden again after logging out.
        await tester.runAsync(() => AuthService().logout());
        await tester.pumpAndSettle();
        expect(find.text('Saved Places Inspector'), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        debugNetworkImageHttpClientProvider = null;
      }
    },
  );
}

final _imageBytes = File('assets/recognition/nasi_lemak.jpg').readAsBytesSync();

class _FakeImageClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeImageRequest();
}

class _FakeImageRequest extends Fake implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => _FakeImageResponse();
}

class _FakeImageResponse extends Stream<List<int>>
    implements HttpClientResponse {
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
