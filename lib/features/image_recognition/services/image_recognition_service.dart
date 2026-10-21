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
  ImageRecognitionService({http.Client? client, this.accessToken, String? endpoint})
    : _client = client ?? http.Client(),
      _endpoint = endpoint ??
          '${SupabaseConfig.supabaseUrl}/functions/v1/image-recognition';

  final http.Client _client;
  final String _endpoint;
  final String? accessToken;
  static const maxImageBytes = 4 * 1024 * 1024;

  Future<RecognitionResult> recognize(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maxImageBytes) {
      throw const ImageRecognitionException('Choose an image smaller than 4 MB.');
    }
    final session = SupabaseConfig.client?.auth.currentSession;
    final token = accessToken ??
        (!AuthService().isGuest && session?.user.id == AuthService().currentUser?.uid
            ? session?.accessToken
            : null);
    if (token == null) {
      throw const ImageRecognitionException(
        'Sign in with an online account to recognize your photo. '
        'You can explore the sample presets offline.',
      );
    }
    try {
      final response = await _client.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'apikey': SupabaseConfig.supabaseAnonKey,
        },
        body: jsonEncode({'image': base64Encode(bytes)}),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        final message = switch (response.statusCode) {
          401 || 403 => 'Sign in again to recognize your photo.',
          413 => 'Choose an image smaller than 4 MB.',
          429 => 'Too many scans. Please try again in a minute.',
          503 => 'Photo recognition is not configured yet. Try an offline sample.',
          400 => 'This image could not be read. Try a JPEG or PNG photo.',
          _ => 'Recognition is unavailable. Try again later or use a sample.',
        };
        throw ImageRecognitionException(message);
      }
      return _parse(Map<String, dynamic>.from(jsonDecode(response.body) as Map));
    } on ImageRecognitionException {
      rethrow;
    } catch (_) {
      throw const ImageRecognitionException(
        'Unable to recognize this photo. Check your connection or try an offline sample.',
      );
    }
  }

  RecognitionResult _parse(Map<String, dynamic> data) {
    final landmarks = (data['landmarks'] as List? ?? []).whereType<Map>().toList();
    final labels = (data['labels'] as List? ?? []).whereType<Map>().toList();
    final entities = (data['entities'] as List? ?? []).whereType<Map>().toList();
    double score(Map item) {
      final value = (item['score'] as num?)?.toDouble() ?? 0;
      return value.isFinite ? value.clamp(0, 1) : 0;
    }
    landmarks.sort((a, b) => score(b).compareTo(score(a)));
    final descriptions = [...landmarks, ...entities, ...labels];
    final labelNames = labels.map((item) => item['name']).whereType<String>().take(8).toList();
    // Exact tourism names or aliases are required; generic "rice" or "tower"
    // labels must never be presented as a confidently identified Malaysian item.
    for (final detection in descriptions) {
      final name = (detection['name'] as String? ?? '').toLowerCase();
      if (score(detection) < 0.65) continue;
      for (final preset in recognitionPresets) {
        if (!preset.aliases.any((alias) => name == alias || name.contains(alias))) continue;
        return RecognitionResult(
          name: preset.name,
          kind: preset.kind,
          description: preset.description,
          location: preset.location,
          confidence: landmarks.contains(detection) || labels.contains(detection)
              ? score(detection) : null,
          recognizedAt: DateTime.now(),
          labels: labelNames,
        );
      }
    }
    for (final landmark in landmarks.where((item) => score(item) >= 0.65)) {
      final name = landmark['name'] as String? ?? '';
      for (final attraction in curatedMalaysianAttractions) {
        final localName = attraction.name.toLowerCase();
        if (name.length < 5 || !localName.contains(name.toLowerCase())) continue;
        return RecognitionResult(
          name: attraction.name,
          kind: 'landmark',
          description: attraction.description ?? 'An attraction in the Malaysian tourism guide.',
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
      description: 'We could not confidently identify a Malaysian landmark or dish. '
          'Try a closer, well-lit photo with one clear subject.',
      location: '',
      recognizedAt: DateTime.now(),
      labels: labelNames,
    );
  }

  void dispose() => _client.close();
}
