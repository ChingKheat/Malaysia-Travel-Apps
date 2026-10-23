import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_travel_planner/features/image_recognition/data/recognition_presets.dart';
import 'package:smart_travel_planner/features/image_recognition/services/image_recognition_service.dart';

void main() {
  ImageRecognitionService service(
    MockClient client, {
    String? token = 'signed-in',
  }) => ImageRecognitionService(
    client: client,
    accessToken: token,
    endpoint: 'https://backend.test/image-recognition',
  );

  test('Rejects guests and oversized images before any HTTP request', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('{}', 200);
    });
    final guest = service(client, token: null);
    await expectLater(
      guest.recognize(Uint8List.fromList([1])),
      throwsA(isA<ImageRecognitionException>()),
    );
    final online = service(client);
    await expectLater(
      online.recognize(Uint8List(0)),
      throwsA(isA<ImageRecognitionException>()),
    );
    await expectLater(
      online.recognize(Uint8List(ImageRecognitionService.maxImageBytes + 1)),
      throwsA(isA<ImageRecognitionException>()),
    );
    expect(calls, 0);
    client.close();
  });

  test('Photo bytes go only to the backend with user authentication', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'backend.test');
      expect(request.headers['Authorization'], 'Bearer signed-in');
      expect(request.headers.containsKey('X-Goog-Api-Key'), isFalse);
      expect(request.url.queryParameters.containsKey('key'), isFalse);
      final body = jsonDecode(request.body) as Map;
      expect(body['operation'], 'recognize');
      expect(base64Decode(body['image'] as String), [1, 2, 3]);
      return http.Response(
        jsonEncode({
          'landmarks': [
            {'name': 'Petronas Towers', 'score': 0.96},
          ],
          'labels': [
            {'name': 'Tower', 'score': 0.9},
          ],
        }),
        200,
      );
    });
    final result = await service(
      client,
    ).recognize(Uint8List.fromList([1, 2, 3]));
    expect(result.name, 'Petronas Twin Towers');
    expect(result.confidence, 0.96);
    expect(result.isSample, isFalse);
    expect(result.labels, ['Tower']);
    client.close();
  });

  test(
    'Generic food labels and low-confidence names do not invent a specific dish',
    () async {
      for (final labels in [
        [
          {'name': 'Rice', 'score': 0.99},
          {'name': 'Food', 'score': 0.99},
        ],
        [
          {'name': 'Nasi lemak', 'score': 0.2},
        ],
      ]) {
        final client = MockClient(
          (_) async => http.Response(jsonEncode({'labels': labels}), 200),
        );
        final result = await service(client).recognize(Uint8List.fromList([1]));
        expect(result.kind, 'unknown');
        expect(result.confidence, isNull);
        client.close();
      }
    },
  );

  test(
    'Specific high-confidence dish detection resolves a curated description',
    () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'labels': [
              {'name': 'Nasi lemak', 'score': 0.9},
            ],
          }),
          200,
        ),
      );
      final result = await service(client).recognize(Uint8List.fromList([1]));
      expect(result.name, 'Nasi Lemak');
      expect(result.kind, 'food');
      client.close();
    },
  );

  test(
    'Translation retains identity and history metadata; decodes Google text entities',
    () async {
      final original = recognitionPresets.first.sampleResult();
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        expect(body['operation'], 'translate');
        expect(body['target'], 'ms');
        expect(body['texts'], [
          original.name,
          original.description,
          original.location,
        ]);
        return http.Response(
          jsonEncode({
            'translations': [
              'Bangunan Sultan',
              'Seni &amp; budaya &#39;Malaysia&#39;',
              'Kuala Lumpur',
            ],
          }),
          200,
        );
      });
      final api = service(client);
      final translated = await api.translate(original, 'ms');
      expect(translated.name, 'Bangunan Sultan');
      expect(translated.description, "Seni & budaya 'Malaysia'");
      expect(translated.sampleId, original.sampleId);
      expect(translated.recognizedAt, original.recognizedAt);
      expect(original.name, 'Sultan Abdul Samad Building');
      expect(await api.translate(original, 'en'), same(original));
      client.close();
    },
  );

  test(
    'Failed or malformed server responses produce safe actionable errors',
    () async {
      for (final response in [
        http.Response('{}', 401),
        http.Response('{}', 413),
        http.Response('{}', 429),
        http.Response('{}', 503),
        http.Response('invalid', 200),
      ]) {
        final client = MockClient((_) async => response);
        await expectLater(
          service(client).recognize(Uint8List.fromList([1])),
          throwsA(isA<ImageRecognitionException>()),
        );
        client.close();
      }
      final client = MockClient(
        (_) async => throw http.ClientException('offline'),
      );
      await expectLater(
        service(client).recognize(Uint8List.fromList([1])),
        throwsA(isA<ImageRecognitionException>()),
      );
      client.close();
    },
  );

  test(
    'Translation rejects incomplete results and unsupported languages',
    () async {
      final client = MockClient(
        (_) async => http.Response('{"translations":["only one"]}', 200),
      );
      final api = service(client);
      await expectLater(
        api.translate(recognitionPresets.first.sampleResult(), 'ms'),
        throwsA(isA<ImageRecognitionException>()),
      );
      await expectLater(
        api.translate(recognitionPresets.first.sampleResult(), 'invalid'),
        throwsA(isA<ImageRecognitionException>()),
      );
      client.close();
    },
  );
}
