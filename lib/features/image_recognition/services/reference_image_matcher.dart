import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_litert/flutter_litert.dart';
import 'package:smart_travel_planner/features/image_recognition/models/recognition_result.dart';

class ReferenceImageMatch {
  const ReferenceImageMatch.identified(ReferenceSubject subject)
    : identified = subject,
      candidates = const [];

  const ReferenceImageMatch.possible(this.candidates) : identified = null;

  final ReferenceSubject? identified;
  final List<ReferenceSubject> candidates;
}

typedef ReferenceImageLookup =
    Future<ReferenceImageMatch?> Function(Uint8List photo);

class ReferenceImageMatcher {
  static const _assets = 'assets/recognition/reference';
  static const _inputSize = 224;
  static Future<({Uint8List model, ReferenceIndex index})>? _bundled;

  static Future<ReferenceImageMatch?> match(Uint8List photo) async {
    final inputs = await _imageInputs(photo);
    final assets = await (_bundled ??= _loadAssets());
    return compute(_runMatch, (
      model: assets.model,
      index: assets.index,
      inputs: inputs,
    ), debugLabel: 'reference-image-match');
  }

  static Future<({Uint8List model, ReferenceIndex index})> _loadAssets() async {
    final manifest = await rootBundle.loadString(
      '$_assets/reference_index.json',
    );
    final vectors = await rootBundle.load('$_assets/reference_vectors.bin');
    final model = await rootBundle.load('$_assets/mobilenet_v3_large.tflite');
    return (
      model: Uint8List.sublistView(model),
      index: ReferenceIndex.decode(manifest, Int8List.sublistView(vectors)),
    );
  }

  static Future<List<Float32List>> _imageInputs(Uint8List photo) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(photo);
    final codec = await ui.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: (width, height) {
        // A small intermediate image bounds decode memory for large gallery files.
        if (width > 640 && width >= height) {
          return const ui.TargetImageSize(width: 640);
        }
        if (height > 640) return const ui.TargetImageSize(height: 640);
        return const ui.TargetImageSize();
      },
    );
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final full = ui.Rect.fromLTWH(
          0,
          0,
          image.width.toDouble(),
          image.height.toDouble(),
        );
        final x = (image.width ~/ 10).toDouble();
        final y = (image.height ~/ 10).toDouble();
        final zoom = ui.Rect.fromLTRB(x, y, full.right - x, full.bottom - y);
        return [await _resize(image, full), await _resize(image, zoom)];
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  static Future<Float32List> _resize(ui.Image image, ui.Rect crop) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      image,
      crop,
      const ui.Rect.fromLTWH(0, 0, _inputSize * 1.0, _inputSize * 1.0),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    final picture = recorder.endRecording();
    try {
      final scaled = await picture.toImage(_inputSize, _inputSize);
      try {
        final pixels = (await scaled.toByteData())!.buffer.asUint8List();
        final input = Float32List(_inputSize * _inputSize * 3);
        for (var pixel = 0; pixel < pixels.length ~/ 4; pixel++) {
          for (var channel = 0; channel < 3; channel++) {
            input[pixel * 3 + channel] = pixels[pixel * 4 + channel] / 255.0;
          }
        }
        return input;
      } finally {
        scaled.dispose();
      }
    } finally {
      picture.dispose();
    }
  }
}

Future<ReferenceImageMatch?> _runMatch(
  ({Uint8List model, ReferenceIndex index, List<Float32List> inputs}) request,
) async {
  if (kIsWeb) await initializeWeb();
  final interpreter = await Interpreter.fromBytes(request.model);
  try {
    final embeddings = <Float32List>[];
    for (final input in request.inputs) {
      final output = Float32List(request.index.dimensions);
      interpreter.run(input.buffer.asUint8List(), output.buffer.asUint8List());
      embeddings.add(output);
    }
    return request.index.match(embeddings);
  } finally {
    interpreter.close();
  }
}

class ReferenceIndex {
  ReferenceIndex.decode(String manifest, Int8List vectors)
    : _vectors = vectors {
    final data = jsonDecode(manifest) as Map<String, dynamic>;
    dimensions = data['dimensions'] as int;
    var start = 0;
    final ids = <String>{};
    for (final entry
        in (data['subjects'] as List).cast<Map<String, dynamic>>()) {
      final subject = ReferenceSubject.fromJson(entry);
      final count = entry['count'] as int;
      if (count < 1 || !ids.add(subject.id)) {
        throw const FormatException('Invalid reference subject');
      }
      _subjects.add((subject: subject, start: start, count: count));
      start += count;
    }
    if (dimensions < 1 || start * dimensions != vectors.length) {
      throw const FormatException('Reference index size mismatch');
    }
  }

  late final int dimensions;
  final Int8List _vectors;
  final _subjects = <({ReferenceSubject subject, int start, int count})>[];

  ReferenceImageMatch? match(List<Float32List> embeddings) {
    final normalized = embeddings.map(_normalize).nonNulls.toList();
    if (normalized.isEmpty || _subjects.length < 2) return null;

    final scores = [
      for (final group in _subjects)
        (
          subject: group.subject,
          score: normalized
              .map((embedding) {
                final similarities = [
                  for (var i = group.start; i < group.start + group.count; i++)
                    _similarity(embedding, i * dimensions),
                ]..sort((a, b) => b.compareTo(a));
                final count = math.min(3, similarities.length);
                final average =
                    similarities
                        .take(count)
                        .fold<double>(0, (sum, value) => sum + value) /
                    count;
                return 0.7 * similarities.first + 0.3 * average;
              })
              .reduce(math.max),
        ),
    ]..sort((a, b) => b.score.compareTo(a.score));

    final first = scores.first;
    if (first.score >= 0.70 && first.score - scores[1].score >= 0.04) {
      return ReferenceImageMatch.identified(first.subject);
    }
    if (first.score < 0.58) return null;
    return ReferenceImageMatch.possible([
      for (final item in scores.take(3))
        if (item.score >= 0.50 && first.score - item.score <= 0.10)
          item.subject,
    ]);
  }

  Float32List? _normalize(Float32List query) {
    if (query.length != dimensions) return null;
    final sum = query.fold<double>(0, (sum, value) => sum + value * value);
    if (sum == 0 || !sum.isFinite) return null;
    final norm = math.sqrt(sum);
    return Float32List.fromList([for (final value in query) value / norm]);
  }

  double _similarity(Float32List query, int offset) {
    var dot = 0.0;
    var square = 0;
    for (var i = 0; i < dimensions; i++) {
      final value = _vectors[offset + i];
      square += value * value;
      dot += query[i] * value;
    }
    return square == 0 ? 0 : dot / math.sqrt(square);
  }
}
