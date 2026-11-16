import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/image_recognition/services/reference_image_matcher.dart';

void main() {
  const manifest = '''
    {"dimensions":3,"subjects":[
      {"id":"satay","label":"Satay","kind":"food","count":2},
      {"id":"roti_canai","label":"Roti Canai","kind":"food","count":1}
    ]}
  ''';
  final index = ReferenceIndex.decode(
    manifest,
    Int8List.fromList([127, 0, 0, 127, 0, 0, 0, 127, 0]),
  );

  test('the same subject cannot serve as its own runner-up', () {
    final result = index.match([
      Float32List.fromList([1, 0, 0]),
    ]);
    expect(result?.identified?.id, 'satay');
    expect(result?.candidates, isEmpty);
  });

  test('similar subjects remain choices even with high individual scores', () {
    final result = index.match([
      Float32List.fromList([1, 1, 0]),
    ]);
    expect(result?.identified, isNull);
    expect(result?.candidates.map((item) => item.id).toSet(), {
      'satay',
      'roti_canai',
    });
  });

  test('unrelated and invalid embeddings leave the photo unmatched', () {
    expect(
      index.match([
        Float32List.fromList([0, 0, 1]),
      ]),
      isNull,
    );
    expect(index.match([Float32List(3), Float32List(2)]), isNull);
  });

  test('rejects a truncated index', () {
    expect(
      () => ReferenceIndex.decode(manifest, Int8List(3)),
      throwsFormatException,
    );
  });
}
