import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_travel_planner/features/image_recognition/data/recognition_presets.dart';
import 'package:smart_travel_planner/features/image_recognition/models/recognition_result.dart';
import 'package:smart_travel_planner/features/image_recognition/services/image_recognition_service.dart';
import 'package:smart_travel_planner/features/image_recognition/services/reference_image_matcher.dart';

void main() {
  ImageRecognitionService service(
    MockClient client, {
    String? token = 'signed-in',
    ReferenceImageLookup? referenceLookup,
  }) => ImageRecognitionService(
    client: client,
    accessToken: token,
    endpoint: 'https://backend.test/image-recognition',
    referenceLookup: referenceLookup ?? (_) async => null,
  );

  test(
    'Gemini can suggest a dish outside the bundled index without Places',
    () async {
      final operations = <String>[];
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        operations.add(body['operation'] as String);
        return http.Response(
          jsonEncode(
            body['operation'] == 'recognize_context'
                ? {
                    'foodSuggestion': 'Nasi Dagang',
                    'lines': ['Terengganu'],
                  }
                : {
                    'labels': [
                      {'name': 'Rice', 'score': 0.95},
                    ],
                  },
          ),
          200,
        );
      });
      addTearDown(client.close);
      final api = service(client);
      final result = await api.recognize(Uint8List.fromList([1]));
      expect(result.source, RecognitionSource.foodSuggestion);
      expect(result.referenceCandidates.single.name, 'Nasi Dagang');
      expect(
        api.confirmReference(result, result.referenceCandidates.single.id).kind,
        'food',
      );
      expect(operations, ['recognize', 'recognize_context']);
    },
  );

  test(
    'Matching Gemini and reference food evidence confirms the dish',
    () async {
      const dish = ReferenceSubject(id: 'satay', name: 'Satay', kind: 'food');
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        return http.Response(
          body['operation'] == 'recognize_context'
              ? '{"foodSuggestion":"Satay"}'
              : '{}',
          200,
        );
      });
      addTearDown(client.close);
      final api = service(
        client,
        referenceLookup: (_) async =>
            const ReferenceImageMatch.identified(dish),
      );
      final result = await api.recognize(Uint8List.fromList([1]));
      expect(result.name, 'Satay');
      expect(result.kind, 'food');
      expect(result.source, RecognitionSource.reference);
    },
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
    expect(result.visionLandmarkName, 'Petronas Towers');
    expect(result.isSample, isFalse);
    expect(result.labels, ['Tower']);
    client.close();
  });

  test(
    'Conflicting image evidence prevents a certain landmark result',
    () async {
      const conflicting = ReferenceSubject(
        id: 'batu-caves',
        name: 'Batu Caves',
        kind: 'landmark',
      );
      final api = service(
        MockClient(
          (_) async => http.Response(
            '{"landmarks":[{"name":"Petronas Twin Towers","score":0.96}]}',
            200,
          ),
        ),
        referenceLookup: (_) async =>
            const ReferenceImageMatch.identified(conflicting),
      );
      addTearDown(api.dispose);
      final result = await api.recognize(Uint8List.fromList([1]));
      expect(result.kind, 'unknown');
      expect(
        result.referenceCandidates.map((item) => item.name),
        containsAll(['Petronas Twin Towers', 'Batu Caves']),
      );
    },
  );

  test(
    'Moderate landmark scores and landmark labels require confirmation',
    () async {
      for (final detections in [
        {
          'landmarks': [
            {'name': 'Petronas Twin Towers', 'score': 0.72},
          ],
        },
        {
          'labels': [
            {'name': 'Petronas Twin Towers', 'score': 0.95},
          ],
        },
      ]) {
        final api = service(
          MockClient((request) async {
            final operation = (jsonDecode(request.body) as Map)['operation'];
            return http.Response(
              jsonEncode(operation == 'recognize' ? detections : {}),
              200,
            );
          }),
        );
        addTearDown(api.dispose);
        final result = await api.recognize(Uint8List.fromList([1]));
        expect(result.kind, 'unknown');
        expect(result.referenceCandidates.single.name, 'Petronas Twin Towers');
      }
    },
  );

  test(
    'An uncorroborated local landmark is kept as a possible match',
    () async {
      const landmark = ReferenceSubject(
        id: 'petronas',
        name: 'Petronas Twin Towers',
        kind: 'landmark',
      );
      final api = service(
        MockClient((_) async => http.Response('{}', 200)),
        referenceLookup: (_) async =>
            const ReferenceImageMatch.identified(landmark),
      );
      addTearDown(api.dispose);
      final result = await api.recognize(Uint8List.fromList([1]));
      expect(result.kind, 'unknown');
      expect(result.referenceCandidates.single.id, landmark.id);
    },
  );

  test(
    'Multiple Vision names for the same known landmark resolve as one match',
    () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        expect((jsonDecode(request.body) as Map)['operation'], 'recognize');
        return http.Response(
          jsonEncode({
            'landmarks': [
              {'name': 'Petronas Twin Towers', 'score': 0.71},
              {'name': 'Petronas Towers', 'score': 0.91},
            ],
          }),
          200,
        );
      });
      final api = service(client);
      addTearDown(api.dispose);

      final result = await api.recognize(Uint8List.fromList([1]));

      expect(result.kind, 'landmark');
      expect(result.name, 'Petronas Twin Towers');
      expect(result.visionLandmarkName, 'Petronas Towers');
      expect(result.confidence, 0.91);
      expect(requests, 1);
    },
  );

  test(
    'A Vision server failure still allows a verified Gemini landmark candidate',
    () async {
      final operations = <String>[];
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        final operation = body['operation'] as String;
        operations.add(operation);
        return switch (operation) {
          'recognize' => http.Response('{}', 502),
          'recognize_context' => http.Response(
            '{"visualSuggestion":"Kinta Tin Mining Museum"}',
            200,
          ),
          'scan_places' => http.Response(
            jsonEncode({
              'places': [
                {
                  'id': 'museumPlaceId',
                  'displayName': {'text': 'Kinta Tin Mining Museum'},
                  'formattedAddress': 'Kampar, Perak, Malaysia',
                },
              ],
            }),
            200,
          ),
          _ => throw StateError('Unexpected operation: $operation'),
        };
      });
      final api = service(client);
      addTearDown(api.dispose);

      final result = await api.recognize(Uint8List.fromList([1]));

      expect(result.name, 'Possible matches');
      expect(result.referenceCandidates.single.name, 'Kinta Tin Mining Museum');
      expect(result.referenceCandidates.single.placeId, 'museumPlaceId');
      expect(operations, ['recognize', 'recognize_context', 'scan_places']);
    },
  );

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
      var lookupCalls = 0;
      final api = service(
        client,
        referenceLookup: (_) async {
          lookupCalls++;
          return null;
        },
      );
      final result = await api.recognize(Uint8List.fromList([1]));
      expect(result.name, 'Nasi Lemak');
      expect(result.kind, 'food');
      expect(result.source, RecognitionSource.vision);
      expect(lookupCalls, 0);
      client.close();
    },
  );

  const satay = ReferenceSubject(id: 'satay', name: 'Satay', kind: 'food');

  for (final (signal, name, listing) in [
    ('matching image', 'Khoo Kongsi', 'Leong San Tong Khoo Kongsi'),
    ('sign', 'Gua Kelam', 'Gua Kelam'),
  ]) {
    test('Offers an uncatalogued Malaysian place from a $signal', () async {
      final operations = <String>[];
      final api = service(
        MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          final operation = body['operation'] as String;
          operations.add(operation);
          final response = switch (operation) {
            'recognize_context' when signal == 'matching image' => {
              'names': [name],
              'pages': [
                {'domain': 'example.test', 'title': name, 'full': true},
              ],
            },
            'recognize_context' when signal == 'sign' => {
              'lines': [name],
            },
            'scan_places' => {
              'places': [
                {
                  'id': 'museumPlaceId',
                  'displayName': {'text': listing},
                },
              ],
            },
            _ => <String, dynamic>{},
          };
          if (operation == 'scan_places') {
            expect(body['query'], name);
            expect(body.containsKey('image'), isFalse);
          }
          return http.Response(jsonEncode(response), 200);
        }),
      );

      final result = await api.recognize(Uint8List.fromList([1]));
      expect(result.kind, 'unknown');
      expect(result.source, RecognitionSource.placeLookup);
      expect(operations.where((op) => op == 'scan_places'), hasLength(1));
      final candidate = result.referenceCandidates.single;
      expect(candidate.name, listing);
      final confirmed = api.confirmReference(result, candidate.id);
      expect(confirmed.name, listing);
      expect(
        RecognitionResult.fromJson(confirmed.toJson()).placeId,
        'museumPlaceId',
      );
    });
  }

  test('A similar listing cannot verify the name from a photo', () async {
    final api = service(
      MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        final response = switch (body['operation']) {
          'recognize_context' => {
            'names': ['Kinta Tin Mining Museum'],
            'pages': [
              {
                'title': 'Kinta Tin Mining Museum',
                'domain': 'one.test',
                'full': true,
              },
            ],
          },
          'scan_places' => {
            'places': [
              {
                'id': 'anotherPlaceId',
                'displayName': {'text': 'Perak Museum'},
              },
            ],
          },
          _ => <String, dynamic>{},
        };
        return http.Response(jsonEncode(response), 200);
      }),
    );
    final result = await api.recognize(Uint8List.fromList([1]));
    expect(result.kind, 'unknown');
    expect(result.referenceCandidates, isEmpty);
  });

  test(
    'Google landmark names and scores survive without catalog or place lookup',
    () async {
      final client = MockClient((request) async {
        if ((jsonDecode(request.body) as Map)['operation'] != 'recognize') {
          return http.Response('{}', 200);
        }
        return http.Response(
          jsonEncode({
            'landmarks': [
              {'name': 'Dataran Lang', 'score': 0.41},
              {'name': 'Kinta Tin Mining Museum', 'score': 0.89},
              {'name': 'Kinta Tin Mining Museum', 'score': 0.67},
            ],
          }),
          200,
        );
      });
      addTearDown(client.close);
      final api = service(client);
      final result = await api.recognize(Uint8List.fromList([1]));
      expect(result.name, 'Possible matches');
      expect(result.source, RecognitionSource.vision);
      final candidates = RecognitionResult.fromJson(
        result.toJson(),
      ).referenceCandidates;
      expect(candidates.map((subject) => subject.name), [
        'Kinta Tin Mining Museum',
        'Dataran Lang',
      ]);
      expect(candidates.map((subject) => subject.visionConfidence), [
        0.89,
        0.41,
      ]);
      expect(
        api.confirmReference(result, candidates.first.id).name,
        'Kinta Tin Mining Museum',
      );
    },
  );

  const roti = ReferenceSubject(
    id: 'roti_canai',
    name: 'Roti Canai',
    kind: 'food',
  );

  test('Corroborating visual labels only suggest a possible match', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map;
      return http.Response(
        jsonEncode(
          body['operation'] == 'recognize'
              ? {
                  'labels': [
                    {'name': 'Suspension bridge', 'score': 0.91},
                    {'name': 'Tropical forest', 'score': 0.86},
                  ],
                }
              : {},
        ),
        200,
      );
    });
    addTearDown(client.close);
    final result = await service(client).recognize(Uint8List.fromList([1]));
    expect(result.kind, 'unknown');
    expect(result.source, RecognitionSource.visualEvidence);
    expect(result.referenceCandidates.single.name, 'KL Forest Eco Park');
    expect(
      result.labels,
      containsAll(['Suspension bridge', 'Tropical forest']),
    );
    expect(result.confidence, isNull);
  });

  test(
    'One visual clue or a weak second clue cannot nominate a landmark',
    () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        return http.Response(
          jsonEncode(
            body['operation'] == 'recognize'
                ? {
                    'labels': [
                      {'name': 'Bridge', 'score': 0.95},
                      {'name': 'Trees', 'score': 0.22},
                    ],
                  }
                : {},
          ),
          200,
        );
      });
      addTearDown(client.close);
      final result = await service(client).recognize(Uint8List.fromList([1]));
      expect(result.name, 'Try another photo');
      expect(result.referenceCandidates, isEmpty);
    },
  );

  Map<String, Object> page(String title, String domain, {bool full = true}) => {
    'title': title,
    'domain': domain,
    'full': full,
  };

  test(
    'A visual suggestion is shown only after a matching place in the OCR area is found',
    () async {
      for (final (name, area) in [
        ('Mahsuri Tomb', 'Langkawi'),
        ('Paddy Museum', 'Kedah'),
      ]) {
        for (final address in ['$area, Malaysia', 'Penang, Malaysia']) {
          final client = MockClient((request) async {
            final body = jsonDecode(request.body) as Map;
            final response = switch (body['operation']) {
              'recognize' => {
                'labels': [
                  {'name': 'Tourist attraction', 'score': 0.86},
                ],
              },
              'recognize_context' => {
                'lines': [area],
                'visualSuggestion': name,
              },
              'scan_places' => {
                'places': [
                  {
                    'id': 'verifiedPlaceId',
                    'displayName': {'text': name},
                    'formattedAddress': address,
                  },
                ],
              },
              _ => <String, dynamic>{},
            };
            if (body['operation'] == 'recognize_context') {
              expect(body['include_visual_suggestion'], true);
            }
            if (body['query'] == 'tourist attractions in $area') {
              return http.Response('{"places":[]}', 200);
            }
            if (body['operation'] == 'scan_places') {
              expect(body['query'], '$name, $area');
            }
            return http.Response(jsonEncode(response), 200);
          });
          addTearDown(client.close);
          final result = await service(
            client,
          ).recognize(Uint8List.fromList([1]));
          expect(result.kind, 'unknown');
          expect(result.areaHint, area);
          if (address.startsWith(area)) {
            expect(result.referenceCandidates.single.name, name);
            expect(
              result.referenceCandidates.single.placeId,
              'verifiedPlaceId',
            );
          } else {
            expect(result.referenceCandidates, isEmpty);
            expect(result.name, 'Try another photo');
          }
        }
      }
    },
  );

  test(
    'Matching Vision and Gemini landmark evidence with a Places listing confirms the photo',
    () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        final response = switch (body['operation']) {
          'recognize' => {
            'landmarks': [
              {'name': 'Dataran Lang', 'score': 0.61},
            ],
          },
          'recognize_context' => {
            'visualSuggestion': 'Langkawi Eagle Square',
            'lines': ['Langkawi'],
          },
          'scan_places' => {
            'places': [
              {
                'id': 'eagleId',
                'displayName': {'text': 'Eagle Square'},
                'formattedAddress': 'Kuah, Langkawi, Malaysia',
              },
            ],
          },
          _ => <String, dynamic>{},
        };
        return http.Response(jsonEncode(response), 200);
      });
      addTearDown(client.close);
      final result = await service(client).recognize(Uint8List.fromList([1]));
      expect(result.name, 'Eagle Square (Dataran Lang)');
      expect(result.placeId, 'eagleId');
      expect(result.confidence, 0.61);
    },
  );

  test(
    'A catalogued Gemini landmark stays available as a candidate when Places fails',
    () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        return switch (body['operation']) {
          'recognize_context' => http.Response(
            '{"visualSuggestion":"Langkawi Eagle Square","lines":["Langkawi"]}',
            200,
          ),
          'scan_places' => http.Response('{}', 503),
          _ => http.Response('{}', 200),
        };
      });
      addTearDown(client.close);
      final result = await service(client).recognize(Uint8List.fromList([1]));
      expect(result.kind, 'unknown');
      expect(
        result.referenceCandidates.single.name,
        'Eagle Square (Dataran Lang)',
      );
      expect(result.source, RecognitionSource.visualEvidence);
    },
  );

  test(
    'An area-only scan automatically offers listings as area suggestions',
    () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        final response = switch (body['operation']) {
          'recognize' => {
            'labels': [
              {'name': 'Tourist attraction', 'score': 0.86},
            ],
          },
          'recognize_context' => {
            'lines': ['Langkawi'],
          },
          'scan_places' => {
            'places': [
              {
                'id': 'eagleSquareId',
                'displayName': {'text': 'Eagle Square'},
                'formattedAddress': 'Kuah, Langkawi, Malaysia',
              },
              {
                'id': 'otherPlaceId',
                'displayName': {'text': 'Langkawi Restaurant'},
                'formattedAddress': 'Kuala Lumpur, Malaysia',
              },
            ],
          },
          _ => <String, dynamic>{},
        };
        if (body['operation'] == 'scan_places') {
          expect(body['query'], 'tourist attractions in Langkawi');
        }
        return http.Response(jsonEncode(response), 200);
      });
      addTearDown(client.close);
      final api = service(client);
      final result = await api.recognize(Uint8List.fromList([1]));
      expect(result.kind, 'unknown');
      expect(result.source, RecognitionSource.areaLookup);
      expect(result.referenceCandidates.single.name, 'Eagle Square');
      final restored = RecognitionResult.fromJson(result.toJson());
      expect(restored.source, RecognitionSource.areaLookup);
      expect(
        api.confirmReference(restored, 'google:eagleSquareId').kind,
        'landmark',
      );
    },
  );

  test(
    'Weak Vision candidates still use context to resolve the landmark',
    () async {
      final client = MockClient((request) async {
        final operation = (jsonDecode(request.body) as Map)['operation'];
        final response = operation == 'recognize'
            ? {
                'landmarks': [
                  {'name': 'Dataran Lang', 'score': 0.61},
                ],
              }
            : {
                'names': ['Eagle Square'],
                'pages': [
                  page('Eagle Square Langkawi', 'site-a.test'),
                  page('Dataran Lang in Langkawi', 'site-b.test'),
                ],
              };
        return http.Response(jsonEncode(response), 200);
      });
      addTearDown(client.close);
      final result = await service(client).recognize(Uint8List.fromList([1]));
      expect(result.name, 'Eagle Square (Dataran Lang)');
      expect(result.source, RecognitionSource.web);
    },
  );

  test(
    'An OCR area and a web name can find a place without the Gemini suggestion',
    () async {
      const name = 'Lata Iskandar Waterfall';
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        final response = switch (body['operation']) {
          'recognize_context' => {
            'text': 'Perak',
            'names': [name],
          },
          'scan_places' => {
            'places': [
              {
                'id': 'waterfallPlaceId',
                'displayName': {'text': name},
                'formattedAddress': 'Tapah, Perak, Malaysia',
              },
            ],
          },
          _ => <String, dynamic>{},
        };
        if (body['operation'] == 'scan_places') {
          expect(body['query'], '$name, Perak');
        }
        return http.Response(jsonEncode(response), 200);
      });
      addTearDown(client.close);
      final result = await service(client).recognize(Uint8List.fromList([1]));
      expect(result.source, RecognitionSource.placeLookup);
      expect(result.areaHint, 'Perak');
      expect(result.referenceCandidates.single.name, name);
    },
  );

  test(
    'Matching sites identify several landmarks outside the image index',
    () async {
      for (final (name, titles) in [
        (
          'KL Forest Eco Park',
          ['KL Forest Eco Park canopy walk', 'Kuala Lumpur Forest Eco Park'],
        ),
        (
          'Telaga Tujuh Waterfall',
          [
            'Telaga Tujuh Waterfall, Langkawi',
            'Visiting Langkawi Telaga Tujuh Waterfall',
          ],
        ),
        (
          'Lata Iskandar Waterfall',
          ['Lata Iskandar Waterfall, Pahang', 'Pahang Lata Iskandar Waterfall'],
        ),
      ]) {
        final operations = <String>[];
        final client = MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          final operation = body['operation'] as String;
          operations.add(operation);
          expect(base64Decode(body['image'] as String), [1, 2, 3]);
          return http.Response(
            jsonEncode(
              operation == 'recognize'
                  ? {
                      'labels': [
                        {'name': 'Bridge', 'score': 0.9},
                      ],
                    }
                  : {
                      'names': [name],
                      'pages': [
                        page(titles.first, 'site-a.test'),
                        page(titles.last, 'site-b.test'),
                      ],
                    },
            ),
            200,
          );
        });
        addTearDown(client.close);
        final result = await service(
          client,
        ).recognize(Uint8List.fromList([1, 2, 3]));
        expect(operations, ['recognize', 'recognize_context']);
        expect(result.name, name);
        expect(result.source, RecognitionSource.web);
        expect(result.webSources, ['site-a.test', 'site-b.test']);
        expect(result.labels, ['Bridge']);
      }
    },
  );

  test(
    'A sign or one website yields a suggestion, and generic or foreign clues stay inconclusive',
    () async {
      const park = 'KL Forest Eco Park';
      for (final (clues, expected, suggestion)
          in <(Map<String, Object>, RecognitionSource, String?)>[
            (
              {'text': 'TAMAN EKO RIMBA KUALA LUMPUR'},
              RecognitionSource.sign,
              park,
            ),
            (
              {
                'names': ['Dataran Lang'],
              },
              RecognitionSource.web,
              'Eagle Square (Dataran Lang)',
            ),
            (
              {
                'pages': [page('Taman Tugu Malaysia', 'one.test', full: false)],
              },
              RecognitionSource.vision,
              null,
            ),
            (
              {
                'pages': [
                  page(park, 'one.test'),
                  page('Kuala Lumpur Forest Eco Park', 'one.test'),
                ],
              },
              RecognitionSource.web,
              park,
            ),
            (
              {
                'pages': [
                  page(park, 'one.test', full: false),
                  page(park, 'two.test', full: false),
                ],
              },
              RecognitionSource.web,
              park,
            ),
            (
              {
                'names': ['canopy walkway', 'Eiffel Tower'],
                'pages': [
                  page('A canopy walkway, Malaysia', 'one.test'),
                  page('Eiffel Tower trips from Malaysia', 'two.test'),
                  page('Eiffel Tower flights from Malaysia', 'three.test'),
                ],
              },
              RecognitionSource.vision,
              null,
            ),
          ]) {
        final client = MockClient(
          (request) async => http.Response(
            jsonEncode(
              (jsonDecode(request.body) as Map)['operation'] ==
                      'recognize_context'
                  ? clues
                  : {},
            ),
            200,
          ),
        );
        addTearDown(client.close);
        final result = await service(client).recognize(Uint8List.fromList([1]));
        expect(result.kind, 'unknown');
        expect(result.source, expected);
        expect(result.referenceCandidates.map((subject) => subject.name), [
          ?suggestion,
        ]);
        expect(result.toJson(), isNot(contains('text')));
      }
    },
  );

  test('An unavailable online fallback keeps a strong local result', () async {
    final client = MockClient(
      (request) async =>
          (jsonDecode(request.body) as Map)['operation'] == 'recognize_context'
          ? http.Response('{}', 503)
          : http.Response('{}', 200),
    );
    addTearDown(client.close);
    final result = await service(
      client,
      referenceLookup: (_) async => const ReferenceImageMatch.identified(satay),
    ).recognize(Uint8List.fromList([1]));
    expect(result.name, 'Satay');
    expect(result.source, RecognitionSource.reference);
  });

  test('An uncertain Vision response tries the original photo once', () async {
    final client = MockClient(
      (_) async =>
          http.Response('{"labels":[{"name":"Food","score":0.9}]}', 200),
    );
    addTearDown(client.close);
    final bytes = Uint8List.fromList([1, 2, 3]);
    var calls = 0;
    final api = service(
      client,
      referenceLookup: (photo) async {
        expect(photo, same(bytes));
        calls++;
        return const ReferenceImageMatch.identified(satay);
      },
    );
    final result = await api.recognize(bytes);
    expect(calls, 1);
    expect(result.name, 'Satay');
    expect(result.source, RecognitionSource.reference);
    expect(result.confidence, isNull);
    expect(result.labels, ['Food']);
  });

  test(
    'Possible matches round-trip and require an explicit selection',
    () async {
      final client = MockClient((_) async => http.Response('{}', 200));
      addTearDown(client.close);
      final api = service(
        client,
        referenceLookup: (_) async =>
            const ReferenceImageMatch.possible([satay, roti]),
      );
      final result = await api.recognize(Uint8List.fromList([1]));
      final restored = RecognitionResult.fromJson(
        jsonDecode(jsonEncode(result)),
      );
      expect(restored.name, 'Possible matches');
      expect(restored.kind, 'unknown');
      expect(restored.referenceCandidates.map((item) => item.id), [
        'satay',
        'roti_canai',
      ]);
      expect(api.confirmReference(restored, 'random'), same(restored));
      final confirmed = api.confirmReference(restored, 'roti_canai');
      expect(confirmed.name, 'Roti Canai');
      expect(confirmed.source, RecognitionSource.userConfirmedReference);
      expect(confirmed.recognizedAt, restored.recognizedAt);
      expect(confirmed.referenceCandidates, isEmpty);
    },
  );

  test('A model failure preserves the original no-match result', () async {
    final client = MockClient((_) async => http.Response('{}', 200));
    addTearDown(client.close);
    final api = service(
      client,
      referenceLookup: (_) async => throw StateError('Model unavailable'),
    );
    final result = await api.recognize(Uint8List.fromList([1]));
    expect(result.name, 'Try another photo');
    expect(result.source, RecognitionSource.vision);
  });

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
