import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/image_recognition/data/recognition_presets.dart';
import 'package:smart_travel_planner/features/image_recognition/models/recognition_result.dart';
import 'package:smart_travel_planner/features/image_recognition/screens/image_recognition_page.dart';
import 'package:smart_travel_planner/features/image_recognition/services/image_recognition_service.dart';
import 'package:smart_travel_planner/features/image_recognition/services/recognition_history_store.dart';
import 'package:smart_travel_planner/features/image_recognition/widgets/recognition_result_sheet.dart';

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
  @override
  Future<RecognitionResult> recognize(Uint8List bytes) async {
    scans++;
    await pendingScan?.future;
    if (fail) {
      throw const ImageRecognitionException(
        'Service is offline. Try a sample.',
      );
    }
    return RecognitionResult(
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

  for (final entry in {
    ImageSource.camera: 'Take Photo',
    ImageSource.gallery: 'Upload from Gallery',
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
        expect(find.text('Vision confidence 90%'), findsOneWidget);
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
      await tapPhotoSource(tester, 'Upload from Gallery');
      await tester.pumpAndSettle();
      expect(picker.sources, [ImageSource.gallery]);
      expect(api.scans, 0);
      expect(find.text('Upload from Gallery').hitTestable(), findsOneWidget);
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
    await tapPhotoSource(tester, 'Upload from Gallery');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(api.scans, 1);
    await tester.tap(find.byTooltip('Cancel recognition'));
    await tester.pumpAndSettle();
    api.pendingScan!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Scanning photo…'), findsNothing);
    expect(find.byType(RecognitionResultSheet), findsNothing);
    expect(find.text('Upload from Gallery'), findsOneWidget);
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
      await tapPhotoSource(tester, 'Upload from Gallery');
      await tester.pumpAndSettle();
      expect(api.scans, 1);
      expect(find.text('Service is offline. Try a sample.'), findsOneWidget);
      expect(await RecognitionHistoryStore(userId: 'offline').load(), isEmpty);
      expect(find.text('History (0)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      api.dispose();
    },
  );

  testWidgets(
    'Translation switches back to English and reuses the cached translation',
    (tester) async {
      phone(tester);
      final api = _Service();
      final original = recognitionPresets[1].sampleResult();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecognitionResultSheet(result: original, service: api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> language(String value) async {
        await tester.ensureVisible(find.byType(DropdownButton<String>));
        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(value).last);
        await tester.pumpAndSettle();
      }

      await language('Bahasa Melayu');
      expect(find.text('Menara Berkembar Petronas'), findsOneWidget);
      await language('English');
      expect(find.text('Petronas Twin Towers'), findsOneWidget);
      await language('Bahasa Melayu');
      expect(api.translations, 1);
      expect(original.name, 'Petronas Twin Towers');
      expect(tester.takeException(), isNull);
      api.dispose();
    },
  );

  testWidgets('Failed translation keeps original text and selected language', (
    tester,
  ) async {
    phone(tester);
    final api = _Service()..failTranslation = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecognitionResultSheet(
            result: recognitionPresets[1].sampleResult(),
            service: api,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(DropdownButton<String>));
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('简体中文').last);
    await tester.pumpAndSettle();
    expect(find.text('Petronas Twin Towers'), findsOneWidget);
    expect(find.text('Translation unavailable.'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .value,
      'en',
    );
    expect(tester.takeException(), isNull);
    api.dispose();
  });
}
