import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/app/travel_shell.dart';
import 'package:smart_travel_planner/features/itinerary/services/scan_plan_places_store.dart';
import 'package:smart_travel_planner/features/image_recognition/models/recognition_result.dart';
import 'package:smart_travel_planner/features/image_recognition/screens/image_recognition_page.dart';
import 'package:smart_travel_planner/features/image_recognition/services/recognition_history_store.dart';
import 'package:smart_travel_planner/features/places/services/place_wishlist_store.dart';
import 'package:smart_travel_planner/features/places/screens/attraction_detail_page.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';
import 'package:smart_travel_planner/shared/utils/demo_feedback.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ScanPlanPlacesStore.resetForTesting();
  });

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

  Widget page({
    String userId = 'recognition-test',
    double textScale = 1,
    RecognitionHistoryStore? historyStore,
  }) => MaterialApp(
    theme: ThemeData(
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: demoOutlinedButtonStyle(),
      ),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: ImageRecognitionPage(
        key: ValueKey(userId),
        userId: userId,
        historyStore: historyStore,
      ),
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

  testWidgets('Wishlist saved from Scan is shown on the Scan page', (
    tester,
  ) async {
    phoneSize(tester, width: 320);
    await PlaceWishlistStore('recognition-test').toggle(
      const Attraction(
        xid: 'google_testgarden',
        name: 'Test Garden',
        latitude: 2.9,
        longitude: 101.7,
        category: 'Park',
      ),
    );
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scan-wishlist')));
    await tester.pumpAndSettle();
    expect(find.text('Wishlist'), findsOneWidget);
    expect(find.text('Test Garden'), findsOneWidget);
    expect(find.text('Remove from saved'), findsNothing);
    await tester.tap(find.text('Clear wishlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Test Garden'), findsNothing);
    expect(
      find.text('Places you add to your wishlist will appear here.'),
      findsOneWidget,
    );
    expect(await PlaceWishlistStore('recognition-test').load(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Wishlist groups places, saves a note, and sends selections to Plan',
    (tester) async {
      phoneSize(tester);
      final wishlist = PlaceWishlistStore('recognition-test');
      await wishlist.toggle(
        const Attraction(
          xid: 'garden_kl',
          name: 'Test Garden',
          latitude: 3.15,
          longitude: 101.69,
          category: 'Park',
        ),
      );
      await wishlist.toggle(
        const Attraction(
          xid: 'park_langkawi',
          name: 'Island Park',
          latitude: 6.35,
          longitude: 99.80,
          category: 'Park',
        ),
      );
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('scan-wishlist')));
      await tester.pumpAndSettle();
      expect(find.text('Kuala Lumpur'), findsOneWidget);
      expect(find.text('Langkawi'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Add a note'),
        findsNWidgets(2),
      );

      await tester.tap(find.text('Add a note').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Visit at sunset');
      await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
      await tester.pumpAndSettle();
      expect(find.text('Visit at sunset'), findsOneWidget);
      expect((await wishlist.loadNotes()).values, contains('Visit at sunset'));

      await tester.tap(find.text('Add to plan').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to plan').last);
      await tester.pumpAndSettle();
      final planned = ScanPlanPlacesStore('recognition-test').places;
      expect(
        planned.map((place) => place.name),
        containsAll(['Test Garden', 'Island Park']),
      );
      expect((await wishlist.load()), hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Wishlist clears selected places and keeps the others', (
    tester,
  ) async {
    phoneSize(tester);
    final store = PlaceWishlistStore('recognition-test');
    for (final name in ['Test Garden', 'Test Museum']) {
      await store.toggle(
        Attraction(
          xid: name,
          name: name,
          latitude: 2.9,
          longitude: 101.7,
          category: 'Place',
        ),
      );
    }
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scan-wishlist')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear wishlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Test Garden'), findsNothing);
    expect(find.text('Test Museum'), findsOneWidget);
    expect((await store.load()).single.name, 'Test Museum');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Wishlist repairs an older landmark with missing coordinates', (
    tester,
  ) async {
    phoneSize(tester);
    final wishlist = PlaceWishlistStore('recognition-test');
    await wishlist.toggle(
      const Attraction(
        xid: 'scan_sultan_abdul_samad',
        name: 'Sultan Abdul Samad Building',
        latitude: 0,
        longitude: 0,
        category: 'Historic Landmark',
      ),
    );
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scan-wishlist')));
    await tester.pumpAndSettle();
    expect(find.text('Location needed'), findsNothing);
    expect(find.text('Kuala Lumpur'), findsOneWidget);
    final repaired = (await wishlist.load()).single;
    expect(repaired.latitude, greaterThan(0));
    expect(repaired.longitude, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('History shows saved photo thumbnails and framed clear action', (
    tester,
  ) async {
    phoneSize(tester, width: 320);
    const photoId = '00000000-0000-4000-8000-000000000001';
    final photo = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg==',
    );
    final store = _PhotoHistoryStore([
      (
        result: RecognitionResult(
          name: 'Batu Caves',
          kind: 'landmark',
          description: 'A landmark.',
          location: 'Gombak',
          recognizedAt: DateTime(2026),
        ),
        photoId: photoId,
      ),
    ], photo);
    await tester.pumpWidget(page(historyStore: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scan-history')));
    await tester.pumpAndSettle();
    expect(
      find.byType(Image).evaluate().any((element) {
        final image = element.widget as Image;
        return image.image is MemoryImage;
      }),
      isTrue,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Clear history'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Opening a scanned Wishlist place reuses its uploaded photo', (
    tester,
  ) async {
    phoneSize(tester);
    const name = 'Batu Caves';
    await PlaceWishlistStore('recognition-test').toggle(
      const Attraction(
        xid: 'scan_batu_caves',
        name: name,
        latitude: 3.23,
        longitude: 101.68,
        category: 'Landmark',
      ),
    );
    const photoId = '00000000-0000-4000-8000-000000000002';
    final photo = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg==',
    );
    final history = _PhotoHistoryStore([
      (
        result: RecognitionResult(
          name: name,
          kind: 'landmark',
          description: name,
          location: 'Malaysia',
          recognizedAt: DateTime(2026),
        ),
        photoId: photoId,
      ),
    ], photo);
    await tester.pumpWidget(page(historyStore: history));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scan-wishlist')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(ListTile), matching: find.text(name)),
    );
    await tester.pumpAndSettle();
    final detail = tester.widget<AttractionDetailPage>(
      find.byType(AttractionDetailPage),
    );
    expect(detail.heroPhoto, isA<MemoryImage>());
    expect(tester.takeException(), isNull);
  });

  testWidgets('History stays visible with a full list of previous scans', (
    tester,
  ) async {
    phoneSize(tester, width: 320);
    final entries = List<RecognitionHistoryEntry>.generate(
      30,
      (index) => (
        result: RecognitionResult(
          name: 'Saved landmark $index',
          kind: 'landmark',
          description: 'A saved scan.',
          location: 'Malaysia',
          recognizedAt: DateTime(2026, 11, 17),
        ),
        photoId: null,
      ),
    );
    await tester.pumpWidget(
      page(
        historyStore: _PhotoHistoryStore(
          entries,
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg==',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scan-history')));
    await tester.pumpAndSettle();
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Saved landmark 0'), findsOneWidget);
    expect(find.text('Clear history'), findsOneWidget);
    await tester.tap(find.text('Clear history'));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('History removes only selected scans in a dark dialog', (
    tester,
  ) async {
    phoneSize(tester);
    await RecognitionHistoryStore(userId: 'recognition-test').save([
      for (final name in ['Batu Caves', 'Petronas Twin Towers'])
        (
          result: RecognitionResult(
            name: name,
            kind: 'landmark',
            description: name,
            location: 'Malaysia',
            recognizedAt: DateTime(2026),
          ),
          photoId: null,
        ),
    ]);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scan-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear history'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Batu Caves'), findsNothing);
    expect(find.text('Petronas Twin Towers'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Saving a scan result opens the saved place in Scan wishlist', (
    tester,
  ) async {
    phoneSize(tester);
    await RecognitionHistoryStore(userId: 'recognition-test').save([
      (
        result: RecognitionResult(
          name: 'Petronas Twin Towers',
          kind: 'landmark',
          description: 'Twin towers.',
          location: 'Kuala Lumpur',
          recognizedAt: DateTime(2026),
        ),
        photoId: null,
      ),
    ]);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scan-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Petronas Twin Towers'));
    await tester.pumpAndSettle();
    final add = find.widgetWithText(FilledButton, 'Add to wishlist').first;
    await tester.scrollUntilVisible(add, 140);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.text('Add a note'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Visit at sunset');
    await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
    await tester.pumpAndSettle();
    expect(
      (await PlaceWishlistStore('recognition-test').loadNotes()).values,
      contains('Visit at sunset'),
    );
    expect(find.widgetWithText(FilledButton, 'Saved'), findsWidgets);
    expect(find.text('Saved to favorite places'), findsNothing);
    expect(
      (await PlaceWishlistStore('recognition-test').load()).single.name,
      'Petronas Twin Towers',
    );
    expect(
      (await PlaceWishlistStore('recognition-test').load()).single.latitude,
      greaterThan(0),
    );
    final wishlist = find.widgetWithText(OutlinedButton, 'Wishlist');
    await tester.scrollUntilVisible(wishlist, -180);
    await tester.tap(wishlist);
    await tester.pumpAndSettle();
    expect(
      find.text('Petronas Twin Towers'),
      findsOneWidget,
      reason: 'Wishlist view should display the just-saved place',
    );
    expect(
      (await PlaceWishlistStore('recognition-test').load()).single.name,
      'Petronas Twin Towers',
    );
  });

  testWidgets('Quick landmarks show map distance and open place details', (
    tester,
  ) async {
    phoneSize(tester, width: 320);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    final landmark = find.text('Sultan Abdul Samad Building');
    await tester.scrollUntilVisible(landmark, 140);
    await tester.ensureVisible(landmark);
    await tester.pumpAndSettle();
    expect(find.textContaining('from your current location'), findsWidgets);
    await tester.tap(landmark);
    await tester.pumpAndSettle();
    expect(find.byType(AttractionDetailPage), findsOneWidget);
    await tester.tap(find.byTooltip('Save attraction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decide later'));
    await tester.pumpAndSettle();
    expect(
      (await PlaceWishlistStore('recognition-test').load()).single.name,
      'Sultan Abdul Samad Building',
    );
    Navigator.of(tester.element(find.byType(AttractionDetailPage))).pop();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
    await tester.pumpAndSettle();
    final wishlistButton = find.byKey(const ValueKey('scan-wishlist'));
    await tester.ensureVisible(wishlistButton);
    await tester.pumpAndSettle();
    await tester.tap(wishlistButton);
    await tester.pumpAndSettle();
    expect(find.text('Sultan Abdul Samad Building'), findsOneWidget);
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
      final detailsAction = find
          .widgetWithText(FilledButton, 'Check place details')
          .first;
      await tester.scrollUntilVisible(detailsAction, 120);
      final itineraryAction = find
          .widgetWithText(FilledButton, 'Add to itinerary')
          .first;
      final wishlistAction = find
          .widgetWithText(FilledButton, 'Add to wishlist')
          .first;
      final actionButtons = [detailsAction, itineraryAction, wishlistAction];
      final widths = actionButtons
          .map(tester.getSize)
          .map((size) => size.width)
          .toList();
      final tops = actionButtons
          .map(tester.getTopLeft)
          .map((point) => point.dy)
          .toList();
      expect(
        widths.every((width) => (width - widths.first).abs() < 1),
        isTrue,
        reason: '$widths $tops',
      );
      expect(
        tops.every((top) => (top - tops.first).abs() < 1),
        isTrue,
        reason: '$widths $tops',
      );
      final xPositions = actionButtons
          .map(tester.getTopLeft)
          .map((point) => point.dx)
          .toList();
      expect(xPositions[1], lessThan(xPositions[2]));
      expect(xPositions[2], lessThan(xPositions[0]));
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
      final add = find.descendant(
        of: find.byKey(const ValueKey('curated_kl_04')),
        matching: find.text('Add to itinerary'),
      );
      await tester.scrollUntilVisible(add, 120);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(
        ScanPlanPlacesStore('recognition-test').places.map((p) => p.name),
        contains('Jalan Alor Night Food Street'),
      );
      final newScan = find.widgetWithText(OutlinedButton, 'New Scan');
      await tester.scrollUntilVisible(newScan.hitTestable(), -240);
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(newScan).style, isNotNull);
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

        expect(find.text('Visual Landmark Guide'), findsNothing);
        expect(
          find.byKey(const ValueKey('scan-history')).hitTestable(),
          findsOneWidget,
        );
        final photo = find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/recognition/scan_hero_klcc.png',
        );
        expect(
          tester.getBottomLeft(find.byKey(const ValueKey('scan-history'))).dy,
          lessThan(tester.getTopLeft(photo).dy),
        );
        expect(
          tester.getBottomLeft(find.byKey(const ValueKey('scan-wishlist'))).dy,
          lessThan(tester.getTopLeft(photo).dy),
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

  testWidgets('Place actions fit one row at 320px with large text', (
    tester,
  ) async {
    phoneSize(tester, width: 320, height: 480);
    await RecognitionHistoryStore(userId: 'recognition-test').save([
      (
        result: RecognitionResult(
          name: 'Petronas Twin Towers',
          kind: 'landmark',
          description: 'Twin towers.',
          location: 'Kuala Lumpur',
          recognizedAt: DateTime(2026),
        ),
        photoId: null,
      ),
    ]);
    await tester.pumpWidget(page(textScale: 1.6));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scan-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Petronas Twin Towers'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Add to wishlist').first, 130);
    expect(tester.takeException(), isNull);
  });
}

class _PhotoHistoryStore extends RecognitionHistoryStore {
  _PhotoHistoryStore(this.entries, this.photo)
    : super(userId: 'recognition-test');

  final List<RecognitionHistoryEntry> entries;
  final Uint8List photo;

  @override
  Future<List<RecognitionHistoryEntry>> load() async => entries;

  @override
  Future<Uint8List?> loadPhoto(String? id) async =>
      id == entries.first.photoId ? photo : null;
}
