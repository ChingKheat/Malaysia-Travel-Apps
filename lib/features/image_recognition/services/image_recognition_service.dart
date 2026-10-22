import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:smart_travel_planner/core/config/supabase_config.dart';
import 'package:smart_travel_planner/features/places/data/curated_attractions.dart';
import 'package:smart_travel_planner/features/image_recognition/data/recognition_presets.dart';
import 'package:smart_travel_planner/features/image_recognition/models/recognition_result.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';

class ImageRecognitionException implements Exception {
  const ImageRecognitionException(this.message);
  final String message;
}

class ImageRecognitionService {
  ImageRecognitionService({
    http.Client? client,
    this.accessToken,
    String? endpoint,
  }) : _client = client ?? http.Client(),
       _endpoint =
           endpoint ??
           '${SupabaseConfig.supabaseUrl}/functions/v1/image-recognition';

  final http.Client _client;
  final String _endpoint;
  final String? accessToken;
  static const maxImageBytes = 4 * 1024 * 1024;

  Future<RecognitionResult> recognize(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maxImageBytes) {
      throw const ImageRecognitionException(
        'Choose an image smaller than 4 MB.',
      );
    }
    return _parse(
      await _request({'operation': 'recognize', 'image': base64Encode(bytes)}),
    );
  }

  /// Translates display text only. The original English result stays in history.
  Future<RecognitionResult> translate(
    RecognitionResult result,
    String target,
  ) async {
    if (!const ['en', 'ms', 'zh-CN'].contains(target)) {
      throw const ImageRecognitionException(
        'Choose English, Malay or Chinese.',
      );
    }
    if (target == 'en') return result;
    final source = [
      result.name,
      result.description,
      result.location,
      ...result.labels,
    ];
    final indexes = [
      for (var i = 0; i < source.length; i++)
        if (source[i].trim().isNotEmpty) i,
    ];
    final data = await _request({
      'operation': 'translate',
      'texts': [for (final i in indexes) source[i]],
      'target': target,
    });
    final values = data['translations'];
    if (values is! List ||
        values.length != indexes.length ||
        values.any((item) => item is! String)) {
      throw const ImageRecognitionException(
        'Translation is unavailable. Your original result is still available.',
      );
    }
    for (var i = 0; i < indexes.length; i++) {
      source[indexes[i]] = _decodeEntities(values[i] as String);
    }
    return RecognitionResult(
      name: source[0],
      kind: result.kind,
      description: source[1],
      location: source[2],
      recognizedAt: result.recognizedAt,
      confidence: result.confidence,
      sampleId: result.sampleId,
      labels: source.skip(3).toList(),
    );
  }

  static String _decodeEntities(String value) => value.replaceAllMapped(
    RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|amp|lt|gt|quot|apos);'),
    (match) {
      final entity = match[1]!;
      final known = {
        'amp': '&',
        'lt': '<',
        'gt': '>',
        'quot': '"',
        'apos': "'",
      };
      if (known.containsKey(entity)) return known[entity]!;
      final code = entity.startsWith('#x')
          ? int.tryParse(entity.substring(2), radix: 16)
          : int.tryParse(entity.substring(1));
      return code != null &&
              code >= 0 &&
              code <= 0x10ffff &&
              !(code >= 0xd800 && code <= 0xdfff)
          ? String.fromCharCode(code)
          : match[0]!;
    },
  );

  Future<Map<String, dynamic>> _request(Map<String, dynamic> body) async {
    final session = SupabaseConfig.client?.auth.currentSession;
    final token =
        accessToken ??
        (!AuthService().isGuest &&
                session?.user.id == AuthService().currentUser?.uid
            ? session?.accessToken
            : null);
    if (token == null) {
      throw const ImageRecognitionException(
        'Sign in with an online account to recognize your photo. '
        'You can explore the sample presets offline.',
      );
    }
    try {
      final response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'apikey': SupabaseConfig.supabaseAnonKey,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 40));
      if (response.statusCode != 200) {
        final message = switch (response.statusCode) {
          401 ||
          403 => 'Sign in with an online account to recognize or translate.',
          413 => 'Choose an image smaller than 4 MB.',
          429 => 'Too many scans. Please try again in a minute.',
          503 =>
            'Recognition or translation is unavailable. Try an offline sample.',
          400 =>
            'This request could not be read. For photos, try JPEG, PNG or WebP.',
          _ => 'Recognition is unavailable. Try again later or use a sample.',
        };
        throw ImageRecognitionException(message);
      }
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } on ImageRecognitionException {
      rethrow;
    } catch (_) {
      throw const ImageRecognitionException(
        'Unable to reach recognition or translation. Your original results and offline samples are still available.',
      );
    }
  }

  RecognitionResult _parse(Map<String, dynamic> data) {
    final landmarks = (data['landmarks'] as List? ?? [])
        .whereType<Map>()
        .toList();
    final labels = (data['labels'] as List? ?? []).whereType<Map>().toList();
    final entities = (data['entities'] as List? ?? [])
        .whereType<Map>()
        .toList();
    double score(Map item) {
      final value = (item['score'] as num?)?.toDouble() ?? 0;
      return value.isFinite ? value.clamp(0, 1) : 0;
    }

    landmarks.sort((a, b) => score(b).compareTo(score(a)));
    final descriptions = [...landmarks, ...entities, ...labels];
    final labelNames = labels
        .map((item) => item['name'])
        .whereType<String>()
        .take(8)
        .toList();
    // Exact tourism names or aliases are required; generic "rice" or "tower"
    // labels must never be presented as a confidently identified Malaysian item.
    for (final detection in descriptions) {
      final name = (detection['name'] as String? ?? '').toLowerCase();
      if (score(detection) < 0.65) continue;
      for (final preset in recognitionPresets) {
        if (!preset.aliases.any(
          (alias) => name == alias || name.contains(alias),
        )) {
          continue;
        }
        return RecognitionResult(
          name: preset.name,
          kind: preset.kind,
          description: preset.description,
          location: preset.location,
          confidence:
              landmarks.contains(detection) || labels.contains(detection)
              ? score(detection)
              : null,
          recognizedAt: DateTime.now(),
          labels: labelNames,
        );
      }
    }
    for (final landmark in landmarks.where((item) => score(item) >= 0.65)) {
      final name = landmark['name'] as String? ?? '';
      for (final attraction in curatedMalaysianAttractions) {
        final localName = attraction.name.toLowerCase();
        if (name.length < 5 || !localName.contains(name.toLowerCase())) {
          continue;
        }
        return RecognitionResult(
          name: attraction.name,
          kind: 'landmark',
          description:
              attraction.description ??
              'An attraction in the Malaysian tourism guide.',
          location: 'Malaysia',
          confidence: score(landmark),
          recognizedAt: DateTime.now(),
          labels: labelNames,
        );
      }
    }
    return RecognitionResult(
      name: 'No confident match',
      kind: 'unknown',
      description:
          'We could not confidently identify a Malaysian landmark or dish. '
          'Try a closer, well-lit photo with one clear subject.',
      location: '',
      recognizedAt: DateTime.now(),
      labels: labelNames,
    );
  }

  void dispose() => _client.close();
}
