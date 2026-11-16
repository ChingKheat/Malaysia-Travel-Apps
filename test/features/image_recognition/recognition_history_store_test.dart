import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/image_recognition/models/recognition_result.dart';
import 'package:smart_travel_planner/features/image_recognition/services/recognition_history_store.dart';

void main() {
  test(
    'Photos survive reopening, stay account scoped and clear with history',
    () async {
      final directory = await Directory.systemTemp.createTemp('scan-history-');
      addTearDown(() => directory.delete(recursive: true));
      final result = RecognitionResult(
        name: 'Petronas Twin Towers',
        kind: 'landmark',
        description: '',
        location: 'Kuala Lumpur',
        recognizedAt: DateTime(2026),
      );
      SharedPreferences.setMockInitialValues({
        'recognition_history_v1:traveller': jsonEncode([result.toJson()]),
      });
      RecognitionHistoryStore store(String userId) => RecognitionHistoryStore(
        userId: userId,
        applicationDirectory: () async => directory,
      );

      final first = store('traveller');
      final legacy = (await first.load()).single;
      expect(legacy.result.name, result.name);
      expect(legacy.photoId, isNull);

      const photoId = '12345678-1234-4234-8234-123456789abc';
      final photo = Uint8List.fromList([1, 2, 3, 4]);
      expect(
        await first.save(
          [(result: result, photoId: photoId), legacy],
          photo: (photoId, photo),
        ),
        isTrue,
      );

      final reopened = store('traveller');
      final entries = await reopened.load();
      expect(entries.map((entry) => entry.photoId), [photoId, null]);
      expect(await reopened.loadPhoto(photoId), photo);
      expect(await store('other').loadPhoto(photoId), isNull);

      expect(await reopened.save([]), isTrue);
      expect(await store('traveller').load(), isEmpty);
      expect(await store('traveller').loadPhoto(photoId), isNull);
    },
  );
}
