import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/auth/screens/auth_screen.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/onboarding/services/onboarding_service.dart';
import 'package:smart_travel_planner/features/profile/screens/profile_page.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OnboardingService.instance.resetForTesting(isCompleted: true);
  });

  testWidgets('editing a profile closes the dialog safely', (tester) async {
    final auth = AuthService();
    await tester.runAsync(() => auth.loginAsGuest());
    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
    await tester.ensureVisible(find.text('Edit Profile'));
    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'New Name');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('New Name'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await auth.logout();
  });

  testWidgets(
    'tapping Log Out prompts confirmation and transitions cleanly to AuthScreen',
    (tester) async {
      final auth = AuthService();
      await tester.runAsync(() => auth.loginAsGuest());
      expect(auth.isLoggedIn, isTrue);

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: ProfilePage(),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to Log Out button and tap it
      await tester.ensureVisible(find.text('Log Out'));
      await tester.tap(find.text('Log Out'));
      await tester.pumpAndSettle();

      // Verify confirmation dialog appears
      expect(
        find.text('Are you sure you want to log out of your travel profile?'),
        findsOneWidget,
      );

      // Confirm log out in the dialog
      final dialogLogoutBtn = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Log Out'),
      );
      await tester.tap(dialogLogoutBtn);
      await tester.pumpAndSettle();

      // Verify user is logged out and redirected to AuthScreen
      expect(auth.isLoggedIn, isFalse);
      expect(find.byType(ProfilePage), findsNothing);
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.text('Log In'), findsWidgets);
      expect(find.text('Successfully logged out.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
