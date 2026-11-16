import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/app/travel_shell.dart';
import 'package:smart_travel_planner/features/image_recognition/models/recognition_result.dart';
import 'package:smart_travel_planner/features/image_recognition/screens/image_recognition_page.dart';
import 'package:smart_travel_planner/features/image_recognition/services/recognition_history_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void phoneSize(
    WidgetTester tester, {
    double width = 390,
    double height = 844,
  }) {
    tester.view.physicalSize = Size(width, height);
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

  testWidgets('Scan stays at the physical center and opens its destination', (
    tester,
  ) async {
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
    for (final label in ['Explore', 'Community', 'Scan', 'Plan', 'AI']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Itinerary'), findsNothing);
    expect(find.byType(InkWell), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('History opens from the scan card and shows existing scans', (
    tester,
  ) async {
    phoneSize(tester);
    await RecognitionHistoryStore(userId: 'recognition-test').save([
      RecognitionResult(
        name: 'Batu Caves',
        kind: 'landmark',
        description: 'A landmark.',
        location: 'Gombak',
        recognizedAt: DateTime(2026),
      ),
    ]);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    final history = find.byKey(const ValueKey('scan-history'));
    expect(history.hitTestable(), findsOneWidget);
    expect(find.text('Demo Results'), findsNothing);
    expect(find.text('Try a sample landmark photo'), findsOneWidget);
    await tester.tap(history);
    await tester.pumpAndSettle();
    expect(find.text('Batu Caves'), findsOneWidget);
    expect(find.text('Clear history'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(history.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Landmark sample filters nearby spots and starts a new scan', (
    tester,
  ) async {
    phoneSize(tester);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Twin Steel Spires'));
    await tester.pumpAndSettle();
    expect(find.text('Built-in sample · Mock recognition'), findsOneWidget);
    expect(find.text('Petronas Twin Towers'), findsOneWidget);
    final filter = find.text('Food & Cafés');
    await tester.scrollUntilVisible(filter, 240);
    await tester.tap(filter);
    await tester.pumpAndSettle();
    expect(find.text("Madam Kwan's · Suria KLCC"), findsOneWidget);
    final hours = find.text('8:00 AM–10:00 PM');
    await tester.scrollUntilVisible(hours, 120);
    expect(hours, findsOneWidget);
    expect(
      find.text(
        'Signature Nasi Bojari, chicken curry, and Penang char kway teow inside Level 4.',
      ),
      findsOneWidget,
    );
    expect(find.text('KLCC Park & Lake Symphony'), findsNothing);
    final save = find.widgetWithText(FilledButton, 'Save spot').first;
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('visual_scan_saved_spots:recognition-test'),
      contains('sample_madam_kwans'),
    );
    final newScan = find.text('New scan');
    await tester.scrollUntilVisible(newScan, -240);
    await tester.pumpAndSettle();
    await tester.tap(newScan);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('scan-history')), findsOneWidget);
    expect(
      await RecognitionHistoryStore(userId: 'recognition-test').load(),
      isEmpty,
    );
  });

  for (final (width, height, scale) in [
    (390.0, 844.0, 1.0),
    (320.0, 480.0, 1.6),
  ]) {
    testWidgets(
      'Visual Scan fits a ${width.toInt()}px phone at ${scale}x text',
      (tester) async {
        phoneSize(tester, width: width, height: height);
        await tester.pumpWidget(page(textScale: scale));
        await tester.pumpAndSettle();

        expect(find.text('Visual Landmark Guide'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('scan-history')).hitTestable(),
          findsOneWidget,
        );
        final camera = find.text('Take Photo');
        await tester.scrollUntilVisible(camera, 100);
        await tester.pumpAndSettle();
        expect(camera.hitTestable(), findsOneWidget);
        final gallery = find.text('Upload Image');
        await tester.scrollUntilVisible(gallery, 100);
        await tester.pumpAndSettle();
        expect(gallery.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
