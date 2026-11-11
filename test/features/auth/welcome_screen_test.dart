import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/auth/screens/welcome_screen.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';

void main() {
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
}
