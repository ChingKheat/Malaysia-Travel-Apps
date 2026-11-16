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
      (
        result: RecognitionResult(
          name: 'Batu Caves',
          kind: 'landmark',
          description: 'A landmark.',
          location: 'Gombak',
          recognizedAt: DateTime(2026),
        ),
        photoId: null,
      ),
    ]);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    final history = find.byKey(const ValueKey('scan-history'));
    expect(history.hitTestable(), findsOneWidget);
    expect(find.text('Demo Results'), findsNothing);
    final tips = find.text('Tips for a clearer photo');
    await tester.scrollUntilVisible(tips, 160);
    expect(find.text('Use good light'), findsOneWidget);
    expect(find.text('Show the whole landmark'), findsOneWidget);
    expect(find.text('Include a readable sign'), findsOneWidget);
    expect(find.text('Try a sample landmark photo'), findsNothing);
    await tester.scrollUntilVisible(history.hitTestable(), -160);
    await tester.tap(history);
    await tester.pumpAndSettle();
    expect(find.text('Batu Caves'), findsOneWidget);
    expect(find.text('Clear history'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(history.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'A landmark from history describes the place and filters nearby spots',
    (tester) async {
      phoneSize(tester);
      final landmarkResult = RecognitionResult(
        name: 'Petronas Twin Towers',
        kind: 'landmark',
        description: 'The double-deck Skybridge links the towers.',
        location: 'KLCC, Kuala Lumpur',
        recognizedAt: DateTime(2026),
      );
      await RecognitionHistoryStore(
        userId: 'recognition-test',
      ).save([(result: landmarkResult, photoId: null)]);
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      final historyStyle = tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('scan-history')))
          .style;
      await tester.tap(find.byKey(const ValueKey('scan-history')));
      await tester.pumpAndSettle();
      final landmark = find.text(landmarkResult.name);
      await tester.scrollUntilVisible(landmark, 160);
      await tester.tap(landmark);
      await tester.pumpAndSettle();
      expect(find.text('Petronas Twin Towers'), findsOneWidget);
      expect(find.text('KLCC, Kuala Lumpur'), findsOneWidget);
      expect(find.text('About this landmark'), findsOneWidget);
      expect(find.text(landmarkResult.description), findsOneWidget);
      expect(find.text('Nearby attractions & food'), findsOneWidget);
      final filter = find.text('Food & Cafés');
      await tester.scrollUntilVisible(filter.hitTestable(), 240);
      await tester.tap(filter);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Jalan Alor Night Food Street'),
        120,
      );
      expect(find.text('Aquaria KLCC'), findsNothing);
      final save = find.widgetWithText(FilledButton, 'Save spot').first;
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('visual_scan_saved_spots:recognition-test'),
        isNotEmpty,
      );
      final newScan = find.widgetWithText(OutlinedButton, 'New Scan');
      await tester.scrollUntilVisible(newScan.hitTestable(), -240);
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(newScan).style, historyStyle);
      await tester.tap(newScan);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('scan-history')), findsOneWidget);
      expect(
        (await RecognitionHistoryStore(
          userId: 'recognition-test',
        ).load()).single.result.name,
        landmarkResult.name,
      );
    },
  );

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
