import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/auth/widgets/create_account_form.dart';

void main() {
  testWidgets('registration can be retried after an invalid email', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CreateAccountForm())),
    );
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Test User');
    await tester.enterText(fields.at(1), 'invalid');
    await tester.enterText(fields.at(2), 'Password123!');
    await tester.enterText(fields.at(3), 'Password123!');
    await tester.ensureVisible(find.text('Register Account'));
    await tester.tap(find.text('Register Account'));
    await tester.pump();
    expect(find.textContaining('Please enter a valid email'), findsOneWidget);
    await tester.enterText(fields.at(1), 'retry@example.com');
    await tester.ensureVisible(find.text('Register Account'));
    await tester.tap(find.text('Register Account'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
