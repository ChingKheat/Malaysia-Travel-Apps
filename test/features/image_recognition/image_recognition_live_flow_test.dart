import 'dart:typed_data';
import 'dart:io';
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
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => XFile.fromData(
    File('assets/recognition/petronas.jpg').readAsBytesSync(),
    name: 'photo.jpg',
  );
}

class _Service extends ImageRecognitionService {
  int scans = 0;
  int translations = 0;
  bool fail = false;
  bool failTranslation = false;
  @override
  Future<RecognitionResult> recognize(Uint8List bytes) async {
    scans++;
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

  testWidgets(
    'Photo preview requires an explicit scan and persists result text only',
    (tester) async {
      phone(tester);
      final api = _Service();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageRecognitionPage(
              userId: 'live',
              service: api,
              imagePicker: _Picker(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload from Gallery'));
      await tester.pumpAndSettle();
      expect(find.text('Your photo is ready'), findsOneWidget);
      expect(api.scans, 0);
      await tester.ensureVisible(find.text('Recognize photo'));
      await tester.tap(find.text('Recognize photo'));
      await tester.pumpAndSettle();
      expect(api.scans, 1);
      expect(find.text('Vision confidence 90%'), findsOneWidget);
      final history = await RecognitionHistoryStore(userId: 'live').load();
      expect(history, hasLength(1));
      expect(history.single.isSample, isFalse);
      expect(history.single.toJson().keys, isNot(contains('image')));
      expect(tester.takeException(), isNull);
      api.dispose();
    },
  );

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
      await tester.tap(find.text('Upload from Gallery'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Recognize photo'));
      await tester.tap(find.text('Recognize photo'));
      await tester.pumpAndSettle();
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
