import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/app/travel_shell.dart';
import 'package:smart_travel_planner/features/auth/screens/auth_screen.dart';
import 'package:smart_travel_planner/features/auth/screens/welcome_screen.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService().logout();
  });

  testWidgets('WelcomeScreen background Stack fills the entire viewport height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: WelcomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final stackSize = tester.getSize(
      find.descendant(
        of: find.byType(WelcomeScreen),
        matching: find.byType(Stack),
      ).first,
    );
    expect(stackSize, const Size(412, 915));
    expect(tester.takeException(), isNull);
  });

  testWidgets('WelcomeScreen Get Started transitions directly to TravelShell', (
    tester,
  ) async {
    debugNetworkImageHttpClientProvider = () => _ImageClient();
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: WelcomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify WelcomeScreen is shown
      expect(find.byType(WelcomeScreen), findsOneWidget);

      // Tap Get Started
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // Verify it navigated to TravelShell and user is logged in
      expect(find.byType(TravelShell), findsOneWidget);
      expect(AuthService().isLoggedIn, isTrue);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      debugNetworkImageHttpClientProvider = null;
    }
  });

  testWidgets('WelcomeScreen Log In / Sign Up opens AuthScreen and login transitions to TravelShell', (
    tester,
  ) async {
    debugNetworkImageHttpClientProvider = () => _ImageClient();
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: WelcomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Log In / Sign Up
      await tester.tap(find.text('Log In / Sign Up'));
      await tester.pumpAndSettle();

      // Verify AuthScreen is opened
      expect(find.byType(AuthScreen), findsOneWidget);

      // Enter pre-registered credentials
      final emailField = find.widgetWithText(TextField, 'Email Address');
      final passwordField = find.widgetWithText(TextField, 'Password');
      await tester.enterText(emailField, 'tourist@example.com');
      await tester.enterText(passwordField, 'SafeP@ss123!');
      await tester.pumpAndSettle();

      // Tap Log In button
      await tester.tap(find.widgetWithText(FilledButton, 'Log In'));
      await tester.pumpAndSettle();

      // Crucial check: Must navigate directly to TravelShell, NOT stuck on WelcomeScreen!
      expect(find.byType(TravelShell), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
      expect(AuthService().isLoggedIn, isTrue);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      debugNetworkImageHttpClientProvider = null;
    }
  });
}

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
