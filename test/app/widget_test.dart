import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smart_travel_planner/app/smart_travel_app.dart';
import 'package:smart_travel_planner/features/auth/screens/auth_screen.dart';
import 'package:smart_travel_planner/features/auth/screens/welcome_screen.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/onboarding/screens/onboarding_setup_screen.dart';
import 'package:smart_travel_planner/features/onboarding/services/onboarding_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService().logout();
  });

  testWidgets('Smart travel planner prompts Citylore onboarding setup on first launch then transitions directly to Login page', (
    WidgetTester tester,
  ) async {
    OnboardingService.instance.resetForTesting(isCompleted: false);
    await tester.pumpWidget(const SmartTravelApp());
    await tester.pumpAndSettle();

    // Verify Onboarding Step 1 is prompted as the first page
    expect(find.byType(OnboardingSetupScreen), findsOneWidget);
    expect(find.text('Citylore'), findsOneWidget);
    expect(find.text('Welcome setup · Step 1 of 3'), findsOneWidget);
    expect(find.text('Choose your\nguide language'), findsOneWidget);

    // Select English and tap Continue
    await tester.tap(find.byKey(const ValueKey('language-option-en')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-cta-button')));
    await tester.pumpAndSettle();

    // Verify Step 2 Location Access
    expect(find.text('Welcome setup · Step 2 of 3'), findsOneWidget);
    expect(find.text('Discover landmarks\n& cafés around you'), findsOneWidget);

    // Tap Continue to Step 3
    await tester.tap(find.byKey(const ValueKey('onboarding-cta-button')));
    await tester.pumpAndSettle();

    // Verify Step 3 Terms & Privacy
    expect(find.text('Welcome setup · Step 3 of 3'), findsOneWidget);
    expect(find.text('Your privacy\n& travel terms'), findsOneWidget);

    // Agree to terms
    await tester.tap(find.byKey(const ValueKey('terms-agreement-card')));
    await tester.pumpAndSettle();

    // Tap Accept & Continue
    await tester.tap(find.byKey(const ValueKey('onboarding-cta-button')));
    await tester.pumpAndSettle();

    // Now verified to transition directly to Login page (AuthScreen with Log In tab active)!
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('Log In'), findsWidgets);
    expect(find.text('Create Account'), findsWidgets);
    expect(find.byKey(const ValueKey('auth-guest-button')), findsOneWidget);
  });

  testWidgets('Smart travel planner renders welcome and auth screens when onboarding skipped/completed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SmartTravelApp(skipOnboarding: true));
    await tester.pumpAndSettle();

    // Verify WelcomeScreen elements
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('Welcome!'), findsOneWidget);
    expect(find.text('Smart Travel\nPlanning'), findsOneWidget);

    // Tap Log In / Sign Up to open AuthScreen
    await tester.ensureVisible(find.text('Log In / Sign Up'));
    await tester.tap(find.text('Log In / Sign Up'));
    await tester.pumpAndSettle();

    // Verify AuthScreen tabs
    expect(find.text('Log In'), findsWidgets);
    expect(find.text('Create Account'), findsWidgets);
  });
}
