import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/profile/screens/profile_page.dart';

void main() {
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
}
