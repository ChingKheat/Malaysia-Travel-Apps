import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:smart_travel_planner/core/config/supabase_config.dart';
import 'package:smart_travel_planner/features/image_recognition/data/recognition_presets.dart';
import 'package:smart_travel_planner/features/image_recognition/data/scan_visual_evidence.dart';
import 'package:smart_travel_planner/features/image_recognition/data/visual_scan_results.dart';
import 'package:smart_travel_planner/features/image_recognition/models/recognition_result.dart';
import 'package:smart_travel_planner/features/image_recognition/services/reference_image_matcher.dart';
import 'package:smart_travel_planner/features/image_recognition/services/recognition_clues.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/places/models/google_place_details.dart';

class ImageRecognitionException implements Exception {
  const ImageRecognitionException(this.message);
  final String message;
}

class ImageRecognitionService {
  ImageRecognitionService({
    http.Client? client,
    this.accessToken,
    String? endpoint,
    ReferenceImageLookup? referenceLookup,
  }) : _client = client ?? http.Client(),
       _referenceLookup = referenceLookup ?? ReferenceImageMatcher.match,
       _endpoint =
           endpoint ??
           '${SupabaseConfig.supabaseUrl}/functions/v1/image-recognition',
       _contextEndpoint =
           endpoint ??
           '${SupabaseConfig.supabaseUrl}/functions/v1/image-recognition-context-yh';

  final http.Client _client;
  final String _endpoint;
  final String _contextEndpoint;
  final ReferenceImageLookup _referenceLookup;
  final String? accessToken;
  static const maxImageBytes = 4 * 1024 * 1024;

  Future<RecognitionResult> recognize(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maxImageBytes) {
      throw const ImageRecognitionException(
        'Choose an image smaller than 4 MB.',
      );
    }
    final image = base64Encode(bytes);
    final detections = await _request({
      'operation': 'recognize',
      'image': image,
    });
    final vision = _parse(detections);
    if (vision.kind != 'unknown' || vision.referenceCandidates.isNotEmpty) {
      return vision;
    }

    final (reference, clues) = await (
      _referenceMatch(bytes),
      _onlineClues(image),
    ).wait;
    if (clues?.identified case final subject?) {
      return _referenceResult(
        subject,
        vision,
        RecognitionSource.web,
        webSources: clues!.domains,
      );
    }
    final suggestions = clues?.candidates ?? const <ReferenceSubject>[];
    final names = <String>{};
    final candidateNames = {...?clues?.searchNames}
      ..removeWhere(
        (name) => suggestions.any(
          (subject) => scanNameKey(subject.name) == scanNameKey(name),
        ),
      );
    final verified = await Future.wait(
      candidateNames.take(2).map(_verifyPlaceName),
    );
    final online = [...suggestions, ...verified.nonNulls];
    if (reference?.identified case final subject?
        when online.every(
          (other) =>
              other.id == subject.id ||
              scanNameKey(other.name) == scanNameKey(subject.name),
        )) {
      return _referenceResult(subject, vision, RecognitionSource.reference);
    }
    final candidates = [
      for (final subject in [
        ...online,
        ?reference?.identified,
        ...?reference?.candidates,
        ...suggestionsFromVisualEvidence(vision.labels),
      ])
        if (names.add(scanNameKey(subject.name))) subject,
    ].take(3).toList();
    if (candidates.isEmpty) {
      if (clues?.area == null) return vision;
      return RecognitionResult(
        name: vision.name,
        kind: vision.kind,
        description: vision.description,
        location: vision.location,
        recognizedAt: vision.recognizedAt,
        labels: vision.labels,
        areaHint: clues!.area,
      );
    }
    return _possibleMatches(
      vision,
      candidates,
      areaHint: clues?.area,
      source: suggestions.isNotEmpty
          ? (clues!.web ? RecognitionSource.web : RecognitionSource.sign)
          : online.isNotEmpty
          ? RecognitionSource.placeLookup
          : reference != null
          ? RecognitionSource.reference
          : RecognitionSource.visualEvidence,
    );
  }

  RecognitionResult _possibleMatches(
    RecognitionResult vision,
    List<ReferenceSubject> candidates, {
    RecognitionSource source = RecognitionSource.vision,
    String? areaHint,
  }) => RecognitionResult(
    name: 'Possible matches',
    kind: 'unknown',
    description: '',
    location: '',
    recognizedAt: vision.recognizedAt,
    labels: vision.labels,
    source: source,
    referenceCandidates: candidates,
    areaHint: areaHint,
  );

  Future<List<GooglePlaceDetails>> searchPlaces(String query) async {
    final name = query.trim();
    if (name.isEmpty || name.length > 120) return const [];
    try {
      final response = await _request(
        {'operation': 'scan_places', 'query': name},
        endpoint: _contextEndpoint,
        timeout: const Duration(seconds: 23),
      );
      return [
        for (final row
            in (response['places'] as List? ?? const [])
                .whereType<Map<String, dynamic>>())
          if (row['id'] is String && row['displayName'] is Map)
            GooglePlaceDetails.fromApi(row),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<GooglePlaceDetails?> lookupPlace(String name) async {
    final key = scanNameKey(name);
    final places = await searchPlaces(name);
    final matches = places.where((place) {
      final label = place.name ?? '';
      return key.isEmpty
          ? label.trim().toLowerCase() == name.trim().toLowerCase()
          : scanNameKey(label) == key;
    }).toList();
    if (matches.isNotEmpty) return matches.length == 1 ? matches.single : null;

    // A sign or image label may omit part of a listing's official name.
    final words = key.split(' ');
    if (words.length < 2 || key.length < 8) return null;
    final expanded = places.where((place) {
      final listed = scanNameKey(place.name ?? '');
      return listed.split(' ').length <= words.length + 3 &&
          ' $listed '.contains(' $key ');
    }).toList();
    return expanded.length == 1 ? expanded.single : null;
  }

  Future<ReferenceSubject?> _verifyPlaceName(String name) async {
    final place = await lookupPlace(name);
    if (place == null) return null;
    return ReferenceSubject(
      id: 'google:${place.id}',
      name: place.name ?? name,
      kind: 'landmark',
    );
  }

  Future<ReferenceImageMatch?> _referenceMatch(Uint8List bytes) async {
    try {
      return await _referenceLookup(bytes).timeout(const Duration(seconds: 8));
    } catch (_) {
      return null;
    }
  }

  Future<ClueMatch?> _onlineClues(String image) async {
    try {
      final data = await _request(
        {'operation': 'recognize_context', 'image': image},
        endpoint: _contextEndpoint,
        timeout: const Duration(seconds: 26),
      );
      return matchPhotoClues(data);
    } catch (_) {
      // Context detection is optional, including on older hosted functions.
      return null;
    }
  }

  RecognitionResult confirmReference(RecognitionResult result, String id) {
    final subject = result.referenceCandidates
        .where((candidate) => candidate.id == id)
        .firstOrNull;
    return subject == null
        ? result
        : _referenceResult(
            subject,
            result,
            result.source == RecognitionSource.reference
                ? RecognitionSource.userConfirmedReference
                : RecognitionSource.userConfirmedClue,
          );
  }

  RecognitionResult _referenceResult(
    ReferenceSubject subject,
    RecognitionResult original,
    RecognitionSource source, {
    List<String> webSources = const [],
  }) {
    final known = subject.kind == 'landmark'
        ? knownScanLandmark(subject.name)
        : null;
    final preset = recognitionPresets
        .where((entry) => entry.id == (known?.id ?? subject.id))
        .firstOrNull;
    final identity = RecognitionResult(
      name: preset?.name ?? known?.name ?? subject.name,
      kind: subject.kind,
      description: '',
      location: preset?.location ?? '',
      recognizedAt: original.recognizedAt,
    );
    final attraction = scanLandmark(identity);
    return RecognitionResult(
      name: identity.name,
      kind: identity.kind,
      description: preset?.description ?? attraction?.description ?? '',
      location: identity.location,
      recognizedAt: identity.recognizedAt,
      labels: original.labels,
      confidence: subject.visionConfidence,
      visionLandmarkName: subject.visionConfidence == null
          ? null
          : subject.name,
      source: source,
      webSources: webSources,
      placeId: subject.placeId,
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
      source: result.source,
      referenceCandidates: result.referenceCandidates,
      webSources: result.webSources,
      placeId: result.placeId,
      visionLandmarkName: result.visionLandmarkName,
      areaHint: result.areaHint,
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

  Future<Map<String, dynamic>> _request(
    Map<String, dynamic> body, {
    String? endpoint,
    Duration timeout = const Duration(seconds: 40),
  }) async {
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
            Uri.parse(endpoint ?? _endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'apikey': SupabaseConfig.supabaseAnonKey,
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
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

    final labelNames = labels
        .where((item) => score(item) >= 0.55)
        .map((item) => item['name'])
        .whereType<String>()
        .take(8)
        .toList();
    final noMatch = RecognitionResult(
      name: 'No confident match',
      kind: 'unknown',
      description:
          'Google Vision did not identify a specific landmark or dish. '
          'Use the visual clues below or search for the place by name.',
      location: '',
      recognizedAt: DateTime.now(),
      labels: labelNames,
    );
    landmarks.sort((a, b) => score(b).compareTo(score(a)));
    final seen = <String>{};
    final namedLandmarks = [
      for (final detection in landmarks)
        if (detection['name'] case final String name
            when name.trim().isNotEmpty && seen.add(name.trim().toLowerCase()))
          ReferenceSubject(
            id: 'vision:${name.trim()}',
            name: name.trim(),
            kind: 'landmark',
            visionConfidence: score(detection),
          ),
    ];
    if (namedLandmarks.isNotEmpty) {
      final first = namedLandmarks.first;
      final known = knownScanLandmark(first.name);
      if (namedLandmarks.length == 1 &&
          known != null &&
          first.visionConfidence! >= 0.65) {
        return _referenceResult(first, noMatch, RecognitionSource.vision);
      }
      return _possibleMatches(noMatch, namedLandmarks);
    }

    // Generic labels such as "rice" or "tower" do not identify an exact dish
    // or landmark.
    for (final detection in [...entities, ...labels]) {
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
          confidence: labels.contains(detection) ? score(detection) : null,
          recognizedAt: DateTime.now(),
          labels: labelNames,
        );
      }
    }
    return noMatch;
  }

  void dispose() => _client.close();
}
