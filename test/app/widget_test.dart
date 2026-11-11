import 'package:flutter_test/flutter_test.dart';

import 'package:smart_travel_planner/app/smart_travel_app.dart';

void main() {
  testWidgets('Smart travel planner renders welcome and auth screens', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SmartTravelApp());

    // Verify WelcomeScreen elements
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
