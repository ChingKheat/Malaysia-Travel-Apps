import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';
import 'package:smart_travel_planner/features/image_recognition/models/recognition_result.dart';
import 'package:smart_travel_planner/features/image_recognition/screens/image_recognition_page.dart';
import 'package:smart_travel_planner/features/image_recognition/services/image_recognition_service.dart';
import 'package:smart_travel_planner/features/image_recognition/services/recognition_history_store.dart';
import 'package:smart_travel_planner/features/image_recognition/widgets/recognition_result_sheet.dart';
import 'package:smart_travel_planner/features/image_recognition/screens/recognition_scan_screen.dart';
import 'package:smart_travel_planner/features/places/models/google_place_details.dart';
import 'package:smart_travel_planner/features/places/screens/attraction_detail_page.dart';
import 'package:smart_travel_planner/shared/services/location_service.dart';
import 'package:latlong2/latlong.dart';

class _Picker extends ImagePicker {
  _Picker({this.pick});

  final XFile? Function()? pick;
  final sources = <ImageSource>[];

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    sources.add(source);
    final override = pick;
    if (override != null) return override();
    return XFile.fromData(
      File('assets/recognition/petronas.jpg').readAsBytesSync(),
      name: 'photo.jpg',
    );
  }
}

class _Service extends ImageRecognitionService {
  int scans = 0;
  int translations = 0;
  bool fail = false;
  bool failTranslation = false;
  Completer<void>? pendingScan;
  RecognitionResult? resultOverride;
  @override
  Future<RecognitionResult> recognize(Uint8List bytes) async {
    scans++;
    await pendingScan?.future;
    if (fail) {
      throw const ImageRecognitionException(
        'Service is offline. Try a sample.',
      );
    }
    return resultOverride ??
        RecognitionResult(
          name: 'Petronas Twin Towers',
          kind: 'landmark',
          description: 'Curated guide text.',
          location: 'Kuala Lumpur',
          recognizedAt: DateTime(2026),
          confidence: 0.9,
        );
  }

  @override
  Future<RecognitionResult> translate(
    RecognitionResult result,
    String target,
  ) async {
    translations++;
    if (failTranslation) {
      throw const ImageRecognitionException('Translation unavailable.');
    }
    return RecognitionResult(
      name: 'Menara Berkembar Petronas',
      kind: result.kind,
      description: 'Panduan.',
      location: result.location,
      recognizedAt: result.recognizedAt,
      sampleId: result.sampleId,
    );
  }
}

class _NearbyService extends _Service {
  final queries = <String>[];
  final centers = <LatLng?>[];

  @override
  Future<GooglePlaceDetails?> lookupPlace(String name, {String? area}) async =>
      const GooglePlaceDetails('museum-id', {
        'editorialSummary': {'text': 'A converted mining museum.'},
        'formattedAddress': 'Kampar, Perak, Malaysia',
        'location': {'latitude': 4.30, 'longitude': 101.15},
      });

  @override
  Future<List<GooglePlaceDetails>> searchPlaces(
    String query, {
    LatLng? near,
  }) async {
    queries.add(query);
    centers.add(near);
    return query.startsWith('restaurants')
        ? const [
            GooglePlaceDetails('cafe-id', {
              'displayName': {'text': 'Museum Café'},
              'formattedAddress': 'Kampar, Perak',
              'location': {'latitude': 4.30, 'longitude': 101.15},
            }),
          ]
        : const [
            GooglePlaceDetails('museum-id', {
              'displayName': {'text': 'Kinta Tin Mining Museum'},
            }),
            GooglePlaceDetails('park-id', {
              'displayName': {'text': 'Kampar Heritage Park'},
              'formattedAddress': 'Kampar, Perak',
              'location': {'latitude': 4.31, 'longitude': 101.16},
            }),
          ];
  }
}

class _FoodNearbyService extends _NearbyService {
  @override
  Future<List<GooglePlaceDetails>> searchPlaces(
    String query, {
    LatLng? near,
  }) async {
    queries.add(query);
    centers.add(near);
    if (query.startsWith('Nasi Dagang restaurants')) {
      return const [
        GooglePlaceDetails('food-place-id', {
          'displayName': {'text': 'East Coast Kitchen'},
          'primaryTypeDisplayName': {'text': 'Malaysian restaurant'},
          'formattedAddress': 'Kuala Lumpur, Malaysia',
          'location': {'latitude': 3.14, 'longitude': 101.69},
        }),
      ];
    }
    return const [];
  }
}

class _NoOriginService extends _NearbyService {
  @override
  Future<GooglePlaceDetails?> lookupPlace(String name, {String? area}) async =>
      null;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  RecognitionHistoryStore historyFor(String userId) => RecognitionHistoryStore(
    userId: userId,
    applicationDirectory: () async => throw UnsupportedError('No photo folder'),
  );
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> tapPhotoSource(WidgetTester tester, String label) async {
    final source = find.text(label);
    await tester.scrollUntilVisible(source, 100);
    await tester.pumpAndSettle();
    await tester.tap(source);
  }

  testWidgets('Choosing a reference match updates the one history entry', (
    tester,
  ) async {
    phone(tester);
    final api = _Service()
      ..resultOverride = RecognitionResult(
        name: 'Possible matches',
        kind: 'unknown',
        description: '',
        location: '',
        recognizedAt: DateTime(2026),
        source: RecognitionSource.reference,
        referenceCandidates: const [
          ReferenceSubject(id: 'satay', name: 'Satay', kind: 'food'),
          ReferenceSubject(id: 'roti_canai', name: 'Roti Canai', kind: 'food'),
        ],
      );
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageRecognitionPage(
            userId: 'reference-choice',
            service: api,
            imagePicker: _Picker(),
            historyStore: historyFor('reference-choice'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapPhotoSource(tester, 'Upload Image');
    await tester.pumpAndSettle();
    expect(find.text('Possible matches'), findsOneWidget);
    expect(find.text('Scan result'), findsOneWidget);
    expect(
      find.text(
        'Grilled meat skewers commonly served with peanut sauce, cucumber and rice cakes.',
      ),
      findsOneWidget,
    );
    expect(find.text('Hours vary by venue.').first, findsOneWidget);
    final option = find.text('Satay');
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(find.text('Selected by you'), findsOneWidget);
    expect(find.text('Scan result'), findsOneWidget);
    expect(api.scans, 1);
    final history = await RecognitionHistoryStore(
      userId: 'reference-choice',
    ).load();
    expect(history.single.result.name, 'Satay');
    expect(
      history.single.result.source,
      RecognitionSource.userConfirmedReference,
    );
    expect(history.single.result.referenceCandidates, isEmpty);
    expect(history.single.photoId, isNotNull);
  });

  testWidgets(
    'Area-only suggestions can be selected without typing a location',
    (tester) async {
      phone(tester);
      final api = _Service()
        ..resultOverride = RecognitionResult(
          name: 'Places in the area',
          kind: 'unknown',
          description: '',
          location: '',
          recognizedAt: DateTime(2026),
          areaHint: 'Langkawi',
          source: RecognitionSource.areaLookup,
          referenceCandidates: const [
            ReferenceSubject(
              id: 'google:eagleSquareId',
              name: 'Eagle Square',
              kind: 'landmark',
            ),
          ],
        );
      addTearDown(api.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageRecognitionPage(
              service: api,
              imagePicker: _Picker(),
              historyStore: historyFor('guest'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapPhotoSource(tester, 'Upload Image');
      await tester.pumpAndSettle();
      expect(find.text('Places in the area'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      final candidate = find.text('Eagle Square');
      await tester.ensureVisible(candidate);
      await tester.tap(candidate);
      await tester.pumpAndSettle();
      expect(find.text('Selected by you'), findsOneWidget);
      expect(find.text('Scan result'), findsOneWidget);
      expect(api.scans, 1);
      final history = await RecognitionHistoryStore(userId: 'guest').load();
      expect(history.single.result.name, 'Eagle Square (Dataran Lang)');
    },
  );

  testWidgets('An uncertain scan offers guidance and both retry sources', (
    tester,
  ) async {
    phone(tester);
    final picker = _Picker();
    final api = _Service()
      ..resultOverride = RecognitionResult(
        name: 'Try another photo',
        kind: 'unknown',
        description: '',
        location: '',
        recognizedAt: DateTime(2026),
      );
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageRecognitionPage(service: api, imagePicker: picker),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapPhotoSource(tester, 'Upload Image');
    await tester.pumpAndSettle();
    expect(find.text('Try another photo'), findsOneWidget);
    final retake = find.text('Retake photo');
    final upload = find.text('Upload another photo');
    await tester.scrollUntilVisible(find.text('Tips for a clearer photo'), 130);
    await tester.scrollUntilVisible(find.text('Find attractions'), 130);
    expect(find.text('Nearby attractions & food'), findsOneWidget);
    expect(find.text('Find restaurants'), findsOneWidget);
    await tester.scrollUntilVisible(retake, -130);
    await tester.ensureVisible(retake);
    await tester.tap(retake);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(upload, 100);
    await tester.ensureVisible(upload);
    await tester.tap(upload);
    await tester.pumpAndSettle();
    expect(picker.sources, [
      ImageSource.gallery,
      ImageSource.camera,
      ImageSource.gallery,
    ]);
    expect(api.scans, 3);
  });

  testWidgets(
    'An uncatalogued landmark uses place details and both nearby searches',
    (tester) async {
      phone(tester);
      final api = _NearbyService();
      addTearDown(api.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecognitionResultSheet(
              result: RecognitionResult(
                name: 'Kinta Tin Mining Museum',
                kind: 'landmark',
                description: '',
                location: 'Kampar',
                recognizedAt: DateTime(2026),
                placeId: 'museum-id',
              ),
              service: api,
              onNewScan: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('About this landmark'), findsOneWidget);
      expect(find.text('A converted mining museum.'), findsOneWidget);
      expect(find.text('Nearby attractions & food'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Museum Café'), 130);
      expect(find.byKey(const ValueKey('scan-nearby-distance')), findsWidgets);
      expect(find.textContaining('from the scanned landmark'), findsWidgets);
      expect(find.text('Kampar Heritage Park'), findsOneWidget);
      expect(find.text('Kinta Tin Mining Museum'), findsOneWidget);
      expect(find.text('Add to itinerary'), findsWidgets);
      expect(find.text('Check place details'), findsWidgets);
      expect(api.queries, [
        'tourist attractions near Kinta Tin Mining Museum, Kampar',
        'restaurants near Kinta Tin Mining Museum, Kampar',
      ]);
    },
  );

  testWidgets('A nearby card explains when distance cannot be calculated', (
    tester,
  ) async {
    phone(tester);
    final api = _NoOriginService();
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecognitionResultSheet(
            result: RecognitionResult(
              name: 'Unknown Museum',
              kind: 'landmark',
              description: '',
              location: 'Kampar',
              recognizedAt: DateTime(2026),
            ),
            service: api,
            onNewScan: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Kampar Heritage Park'), 130);
    expect(
      find.text('Distance unavailable until location is known'),
      findsWidgets,
    );
  });

  testWidgets('A dish result searches for nearby restaurants serving it', (
    tester,
  ) async {
    phone(tester);
    final api = _FoodNearbyService();
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecognitionResultSheet(
            result: RecognitionResult(
              name: 'Nasi Dagang',
              kind: 'food',
              description: 'East coast rice dish.',
              location: '',
              recognizedAt: DateTime(2026),
            ),
            service: api,
            onNewScan: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('East Coast Kitchen'), 120);
    expect(find.text('East Coast Kitchen'), findsOneWidget);
    expect(
      api.queries,
      contains('Nasi Dagang restaurants near Kuala Lumpur City Centre'),
    );
    expect(find.textContaining('Check the menu'), findsOneWidget);
    expect(find.textContaining('Enable location'), findsOneWidget);
  });

  testWidgets('adding a scanned place shows the plan count and opens Plan', (
    tester,
  ) async {
    phone(tester);
    var openedPlan = false;
    final api = _NearbyService();
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecognitionResultSheet(
            userId: 'scan-plan-flow-test',
            result: RecognitionResult(
              name: 'Sultan Abdul Samad Building',
              kind: 'landmark',
              description: '',
              location: 'Kuala Lumpur',
              recognizedAt: DateTime(2026),
            ),
            service: api,
            onNewScan: () {},
            onOpenPlan: () => openedPlan = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to itinerary').first);
    await tester.pumpAndSettle();
    expect(find.text('Places selected for your plan'), findsOneWidget);
    expect(find.text('1 place'), findsOneWidget);
    final button = find.text('Add to Plan');
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(button);
    expect(openedPlan, true);
  });

  testWidgets('Dish restaurants use real GPS area before photo area', (
    tester,
  ) async {
    phone(tester);
    final location = LocationService();
    location.updateLocation(
      const LatLng(5.41, 100.33),
      'George Town',
      isRealGps: true,
    );
    addTearDown(
      () => location.updateLocation(
        const LatLng(3.1390, 101.6869),
        'Kuala Lumpur City Centre',
      ),
    );
    final api = _FoodNearbyService();
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecognitionResultSheet(
            result: RecognitionResult(
              name: 'Roti Canai',
              kind: 'food',
              description: '',
              location: '',
              recognizedAt: DateTime(2026),
              areaHint: 'Kuala Lumpur',
            ),
            service: api,
            onNewScan: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.queries, contains('Roti Canai restaurants'));
    expect(api.centers, contains(const LatLng(5.41, 100.33)));
  });

  for (final entry in {
    ImageSource.camera: 'Take Photo',
    ImageSource.gallery: 'Upload Image',
  }.entries) {
    testWidgets(
      '${entry.key.name} opens a dark scanner and reuses the photo from history',
      (tester) async {
        phone(tester);
        final api = _Service();
        addTearDown(api.dispose);
        final picker = _Picker();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ImageRecognitionPage(
                userId: 'live',
                service: api,
                imagePicker: picker,
                historyStore: historyFor('live'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(api.scans, 0);
        await tapPhotoSource(tester, entry.value);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(picker.sources, [entry.key]);
        expect(api.scans, 1);
        expect(find.text('Scanning photo…'), findsOneWidget);
        expect(
          tester
              .widget<Scaffold>(
                find.descendant(
                  of: find.byType(RecognitionScanScreen),
                  matching: find.byType(Scaffold),
                ),
              )
              .backgroundColor,
          Colors.black,
        );
        expect(find.text('Your photo is ready'), findsNothing);
        expect(find.text('Recognize photo'), findsNothing);

        await tester.pumpAndSettle();
        final sheet = tester.widget<RecognitionResultSheet>(
          find.byType(RecognitionResultSheet),
        );
        expect(sheet.photo, isA<MemoryImage>());
        expect(find.text('Confident visual match'), findsOneWidget);
        expect(find.text('Scan result'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Nearby attractions & food'),
          160,
        );
        expect(find.text('Nearby attractions & food'), findsOneWidget);
        expect(api.scans, 1);
        final history = await RecognitionHistoryStore(userId: 'live').load();
        expect(history, hasLength(1));
        expect(history.single.result.isSample, isFalse);
        expect(history.single.photoId, isNotNull);

        await tester.scrollUntilVisible(find.text('New Scan'), -180);
        await tester.tap(find.text('New Scan'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('scan-history')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Petronas Twin Towers'));
        await tester.pumpAndSettle();
        expect(find.text('Scan result'), findsOneWidget);
        final story = find.text('Check place details');
        await tester.scrollUntilVisible(story, 140);
        await tester.tap(story);
        await tester.pumpAndSettle();
        final detail = tester.widget<AttractionDetailPage>(
          find.byType(AttractionDetailPage),
        );
        expect(
          (detail.heroPhoto as MemoryImage).bytes,
          (sheet.photo as MemoryImage).bytes,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final entry in <String, int?>{
    'picker cancellation': null,
    'empty file': 0,
    'oversized file': ImageRecognitionService.maxImageBytes + 1,
  }.entries) {
    testWidgets('${entry.key} returns to the guide without scanning', (
      tester,
    ) async {
      phone(tester);
      final api = _Service();
      addTearDown(api.dispose);
      final length = entry.value;
      final picker = _Picker(
        pick: () => length == null
            ? null
            : XFile.fromData(Uint8List(length), name: 'invalid.jpg'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageRecognitionPage(service: api, imagePicker: picker),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapPhotoSource(tester, 'Upload Image');
      await tester.pumpAndSettle();
      expect(picker.sources, [ImageSource.gallery]);
      expect(api.scans, 0);
      expect(find.text('Upload Image').hitTestable(), findsOneWidget);
      expect(find.text('Scanning photo…'), findsNothing);
      expect(
        find.byType(SnackBar),
        length == null ? findsNothing : findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Closing a scan discards a late recognition result', (
    tester,
  ) async {
    phone(tester);
    final api = _Service()..pendingScan = Completer<void>();
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageRecognitionPage(
            userId: 'cancelled',
            service: api,
            imagePicker: _Picker(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapPhotoSource(tester, 'Upload Image');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(api.scans, 1);
    await tester.tap(find.byTooltip('Cancel recognition'));
    await tester.pumpAndSettle();
    api.pendingScan!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Scanning photo…'), findsNothing);
    expect(find.byType(RecognitionResultSheet), findsNothing);
    expect(find.text('Upload Image'), findsOneWidget);
    expect(await RecognitionHistoryStore(userId: 'cancelled').load(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Offline recognition retains photo guidance and does not save fabricated results',
    (tester) async {
      phone(tester);
      final api = _Service()..fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageRecognitionPage(
              userId: 'offline',
              service: api,
              imagePicker: _Picker(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapPhotoSource(tester, 'Upload Image');
      await tester.pumpAndSettle();
      expect(api.scans, 1);
      expect(find.text('Service is offline. Try a sample.'), findsOneWidget);
      expect(await RecognitionHistoryStore(userId: 'offline').load(), isEmpty);
      final history = find.byKey(const ValueKey('scan-history'));
      await tester.scrollUntilVisible(history, -160);
      await tester.pump();
      expect(history.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      api.dispose();
    },
  );

  for (final fail in [false, true]) {
    testWidgets(
      'Result follows app language with translation failure = $fail',
      (tester) async {
        phone(tester);
        final api = _Service()..failTranslation = fail;
        addTearDown(api.dispose);
        final result = await api.recognize(Uint8List(0));
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ms'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: RecognitionResultSheet(
                result: result,
                service: api,
                onNewScan: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(DropdownButton<String>), findsNothing);
        expect(
          find.text(
            fail ? 'Petronas Twin Towers' : 'Menara Berkembar Petronas',
          ),
          findsOneWidget,
        );
        expect(api.translations, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
