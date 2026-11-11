import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/app/travel_shell.dart';
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
    for (final label in ['Home', 'Explore', 'Scan', 'Plan', 'AI']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Itinerary'), findsNothing);
    expect(find.byType(InkWell), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Demo results stay separate from real scan history', (
    tester,
  ) async {
    phoneSize(tester);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Demo Results'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Sultan Abdul Samad Building'),
      250,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sultan Abdul Samad Building'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sultan Abdul Samad Building'));
    await tester.pumpAndSettle();
    expect(find.text('SAMPLE PREVIEW'), findsOneWidget);
    await tester.ensureVisible(find.text('Add to Wishlist'));
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Add to Wishlist'),
          )
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.text('Done'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(
      await RecognitionHistoryStore(userId: 'recognition-test').load(),
      isEmpty,
    );
    await tester.tap(find.text('History (0)'));
    await tester.pumpAndSettle();
    expect(find.text('No scans yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Presets can be filtered to food', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Demo Results'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    expect(find.text('Nasi Lemak'), findsOneWidget);
    expect(find.text('LANDMARK'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final (width, height, scale) in [
    (390.0, 844.0, 1.0),
    (320.0, 480.0, 1.6),
  ]) {
    testWidgets(
      'Photo guidelines fit a ${width.toInt()}px phone at ${scale}x text',
      (tester) async {
        phoneSize(tester, width: width, height: height);
        await tester.pumpWidget(page(textScale: scale));
        await tester.pumpAndSettle();

        final images = tester.widgetList<Image>(find.byType(Image)).toList();
        expect(images.map((image) => (image.image as AssetImage).assetName), [
          'assets/recognition/nasi_lemak.jpg',
          'assets/recognition/batu_caves.jpg',
        ]);
        final centerTip = find.text('Center the subject');
        final featureTip = find.text('Include the key feature');
        expect(
          tester.getTopLeft(centerTip).dx,
          lessThan(tester.getTopLeft(featureTip).dx),
        );
        expect(
          tester.getTopLeft(centerTip).dy,
          tester.getTopLeft(featureTip).dy,
        );
        final camera = find.text('Take Photo');
        await tester.scrollUntilVisible(camera, 100);
        await tester.pumpAndSettle();
        expect(camera.hitTestable(), findsOneWidget);
        final gallery = find.text('Upload from Gallery');
        await tester.scrollUntilVisible(gallery, 100);
        await tester.pumpAndSettle();
        expect(gallery.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
