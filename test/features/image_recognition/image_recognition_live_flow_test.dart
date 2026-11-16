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
import 'package:smart_travel_planner/features/places/models/google_place_details.dart';

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
  final placeQueries = <String>[];

  @override
  Future<List<GooglePlaceDetails>> searchPlaces(String query) async {
    placeQueries.add(query);
    return [
      GooglePlaceDetails.fromApi({
        'id': 'khooKongsiId',
        'displayName': {'text': 'Leong San Tong Khoo Kongsi'},
        'formattedAddress': 'Cannon Square, George Town',
      }),
    ];
  }

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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
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
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapPhotoSource(tester, 'Upload Image');
    await tester.pumpAndSettle();
    expect(find.text('Possible matches'), findsOneWidget);
    expect(find.text('Photo scan · Reference photos'), findsOneWidget);
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
    expect(find.text('Original photo'), findsOneWidget);
    expect(api.scans, 1);
    final history = await RecognitionHistoryStore(
      userId: 'reference-choice',
    ).load();
    expect(history.single.name, 'Satay');
    expect(history.single.source, RecognitionSource.userConfirmedReference);
    expect(history.single.referenceCandidates, isEmpty);
  });

  testWidgets('Place search leaves the inconclusive upload and scan in place', (
    tester,
  ) async {
    phone(tester);
    final api = _Service()
      ..resultOverride = RecognitionResult(
        name: 'No confident match',
        kind: 'unknown',
        description: '',
        location: '',
        recognizedAt: DateTime(2026),
        labels: const ['Temple'],
      );
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageRecognitionPage(service: api, imagePicker: _Picker()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapPhotoSource(tester, 'Upload Image');
    await tester.pumpAndSettle();
    final search = find.text('Search for a place');
    await tester.ensureVisible(search);
    await tester.tap(search);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Open in Google Maps'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    final clue = find.widgetWithText(ActionChip, 'Temple');
    await tester.ensureVisible(clue);
    await tester.tap(clue);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Temple ',
    );
    await tester.enterText(find.byType(TextField), 'Temple George Town');
    await tester.tap(find.widgetWithText(FilledButton, 'Search'));
    await tester.pumpAndSettle();
    expect(api.placeQueries, ['Temple George Town']);
    expect(find.text('Leong San Tong Khoo Kongsi'), findsOneWidget);
    Navigator.of(tester.element(find.text('Leong San Tong Khoo Kongsi'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('No confident match'), findsOneWidget);
    expect(find.text('Original photo'), findsOneWidget);
    expect(api.scans, 1);
  });

  for (final entry in {
    ImageSource.camera: 'Take Photo',
    ImageSource.gallery: 'Upload Image',
  }.entries) {
    testWidgets(
      '${entry.key.name} starts one scan and saves only result text',
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
        expect(find.text('Your photo is ready'), findsNothing);
        expect(find.text('Recognize photo'), findsNothing);

        await tester.pumpAndSettle();
        final sheet = tester.widget<RecognitionResultSheet>(
          find.byType(RecognitionResultSheet),
        );
        expect(sheet.image, isNotNull);
        expect(find.text('Confident visual match'), findsOneWidget);
        expect(find.text('Original photo'), findsOneWidget);
        expect(find.text('Nearby attractions & food'), findsOneWidget);
        expect(api.scans, 1);
        final history = await RecognitionHistoryStore(userId: 'live').load();
        expect(history, hasLength(1));
        expect(history.single.isSample, isFalse);
        expect(history.single.toJson().keys, isNot(contains('image')));
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
    'Offline recognition retains samples and does not save fabricated results',
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
      await tester.ensureVisible(history);
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
