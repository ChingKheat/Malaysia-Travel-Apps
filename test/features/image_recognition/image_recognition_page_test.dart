import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/app/travel_shell.dart';
import 'package:smart_travel_planner/features/image_recognition/screens/image_recognition_page.dart';
import 'package:smart_travel_planner/features/image_recognition/services/recognition_history_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void phoneSize(WidgetTester tester, {double width = 390}) {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget page({String userId = 'recognition-test', double textScale = 1}) =>
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: ImageRecognitionPage(key: ValueKey(userId), userId: userId),
        ),
      );

  testWidgets(
    'Recognize stays at the physical center and opens its destination',
    (tester) async {
      phoneSize(tester);
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: TravelBottomNavigation(
              selectedIndex: 0,
              onSelected: (index) => selected = index,
            ),
          ),
        ),
      );
      final scan = find.byKey(const ValueKey('scan-navigation-button'));
      expect(tester.getCenter(scan).dx, closeTo(195, 0.1));
      await tester.tap(scan);
      expect(selected, 2);
      for (final label in ['Home', 'Explore', 'Recognize', 'Plan', 'AI']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Itinerary'), findsNothing);
      expect(find.byType(InkWell), findsNWidgets(5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Sample result persists locally, reopens and clears from history',
    (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      final sample = find.text('Petronas Twin Towers');
      await tester.ensureVisible(sample);
      await tester.tap(sample);
      await tester.pumpAndSettle();
      expect(find.text('SAMPLE PREVIEW'), findsOneWidget);
      expect(find.text('KLCC, Kuala Lumpur'), findsOneWidget);
      await tester.ensureVisible(find.text('Done'));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('History (1)'), findsOneWidget);
      expect(
        await RecognitionHistoryStore(userId: 'recognition-test').load(),
        hasLength(1),
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      await tester.tap(find.text('History (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Petronas Twin Towers'));
      await tester.pumpAndSettle();
      expect(find.text('SAMPLE PREVIEW'), findsOneWidget);
      await tester.ensureVisible(find.text('Done'));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('History (1)'), findsOneWidget);
      await tester.tap(find.text('Clear history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('No scans yet'), findsOneWidget);
      expect(
        await RecognitionHistoryStore(userId: 'recognition-test').load(),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Presets can be filtered to food', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Presets'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    expect(find.text('Nasi Lemak'), findsOneWidget);
    expect(find.text('LANDMARK'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Scanner supports narrow phones and larger text', (tester) async {
    phoneSize(tester, width: 320);
    await tester.pumpWidget(page(textScale: 1.6));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Helpful Tips'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Presets'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('History (0)'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
