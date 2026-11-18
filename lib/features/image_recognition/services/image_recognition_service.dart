import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

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
  const ImageRecognitionException(this.message, {this.retryable = false});
  final String message;
  final bool retryable;
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
    var detections = <String, dynamic>{};
    ImageRecognitionException? primaryFailure;
    try {
      detections = await _request({'operation': 'recognize', 'image': image});
    } on ImageRecognitionException catch (error) {
      if (!error.retryable) rethrow;
      primaryFailure = error;
    }
    final vision = _parse(detections);
    if (vision.kind != 'unknown') {
      if (vision.kind == 'landmark') {
        final (reference, clues) = await (
          _referenceMatch(bytes),
          _onlineClues(image),
        ).wait;
        final expected = knownScanLandmark(vision.name);
        final visualClue = _visualClueSubject(clues);
        final conflicting =
            [?visualClue, ?reference?.identified, ...?reference?.candidates]
                .where(
                  (subject) =>
                      expected != null && !_agreesWith(expected, subject),
                )
                .toList();
        if (conflicting.isNotEmpty) {
          return _possibleMatches(
            vision,
            [
              ReferenceSubject(
                id: expected?.id ?? 'vision:${vision.name}',
                name: vision.name,
                kind: 'landmark',
                visionConfidence: vision.confidence,
              ),
              ...conflicting,
            ].take(3).toList(),
          );
        }
      }
      return vision;
    }

    final (reference, clues) = await (
      _referenceMatch(bytes),
      _onlineClues(image),
    ).wait;
    if (clues?.restaurantSuggestion case final restaurant?
        when vision.referenceCandidates.isEmpty &&
            reference?.identified == null) {
      final listing = await lookupPlace(restaurant, area: clues?.area);
      if (listing != null &&
          RegExp(
            r'restaurant|cafe|café|coffee|eatery|food|dining|bakery|bistro',
            caseSensitive: false,
          ).hasMatch(listing.category ?? '')) {
        return _possibleMatches(
          vision,
          [
            ReferenceSubject(
              id: 'google:${listing.id}',
              name: listing.name ?? restaurant,
              kind: 'restaurant',
            ),
          ],
          areaHint: clues?.area,
          source: RecognitionSource.placeLookup,
        );
      }
    }
    if (clues?.foodSuggestion case final dish?
        when clues?.identified == null &&
            reference?.identified?.kind != 'landmark' &&
            vision.referenceCandidates.every((item) => item.kind == 'food')) {
      final knownDish = knownScanFood(dish);
      final key = knownDish?.id ?? scanNameKey(dish);
      final local = reference?.identified;
      final visionFood = vision.referenceCandidates.firstOrNull;
      if (local?.kind == 'food' &&
          (knownScanFood(local!.name)?.id ?? scanNameKey(local.name)) == key) {
        return _referenceResult(local, vision, RecognitionSource.reference);
      }
      if (visionFood != null &&
          (knownScanFood(visionFood.name)?.id ??
                  scanNameKey(visionFood.name)) ==
              key) {
        return _referenceResult(
          knownDish ?? visionFood,
          vision,
          RecognitionSource.vision,
        );
      }
      return _possibleMatches(
        vision,
        [
          knownDish ??
              ReferenceSubject(id: 'food:$key', name: dish, kind: 'food'),
          for (final item in [?visionFood, ?local, ...?reference?.candidates])
            if (item.kind == 'food' &&
                (knownScanFood(item.name)?.id ?? scanNameKey(item.name)) != key)
              item,
        ].take(3).toList(),
        source: RecognitionSource.foodSuggestion,
      );
    }
    final proposed = [...vision.referenceCandidates, ...?reference?.candidates];
    if (clues?.identified case final subject?
        when _agreesWith(subject, reference?.identified) &&
            _agreesWithVision(subject, vision)) {
      return _referenceResult(
        subject,
        vision,
        RecognitionSource.web,
        webSources: clues!.domains,
      );
    }
    final suggestions = clues?.candidates ?? const <ReferenceSubject>[];
    final names = <String>{};
    final visualSuggestion = clues?.visualSuggestion;
    final candidateNames = {?visualSuggestion, ...?clues?.searchNames}
      ..removeWhere(
        (name) => suggestions.any(
          (subject) => scanNameKey(subject.name) == scanNameKey(name),
        ),
      );
    final verified = await Future.wait(
      candidateNames.take(2).map((name) => _verifyPlaceName(name, clues?.area)),
    );
    final verifiedVisual =
        visualSuggestion == null ||
            candidateNames.isEmpty ||
            candidateNames.first != visualSuggestion
        ? null
        : verified.first;
    final visionCandidates = vision.referenceCandidates;
    if (verifiedVisual != null && visionCandidates.length == 1) {
      final detection = visionCandidates.single;
      if ((detection.visionConfidence ?? 0) >= 0.55 &&
          _agreesWith(verifiedVisual, detection) &&
          _agreesWith(verifiedVisual, reference?.identified) &&
          suggestions.every((other) => _agreesWith(verifiedVisual, other))) {
        return _referenceResult(
          ReferenceSubject(
            id: verifiedVisual.id,
            name: detection.name,
            kind: detection.kind,
            visionConfidence: detection.visionConfidence,
          ),
          vision,
          RecognitionSource.vision,
        );
      }
    }
    final catalogue = verifiedVisual == null && visualSuggestion != null
        ? _catalogueSuggestion(visualSuggestion, clues?.area)
        : null;
    final online = [...suggestions, ...verified.nonNulls, ?catalogue];
    if (reference?.identified case final subject?
        when _agreesWithVision(subject, vision) &&
            (subject.kind != 'landmark' ||
                vision.referenceCandidates.isNotEmpty ||
                online.isNotEmpty) &&
            online.every((other) => _agreesWith(subject, other))) {
      return _referenceResult(subject, vision, RecognitionSource.reference);
    }
    final candidates = [
      for (final subject in [
        ...online,
        ?reference?.identified,
        ...proposed,
        ...suggestionsFromVisualEvidence(vision.labels),
      ])
        if (names.add(
          knownScanLandmark(subject.name)?.id ?? scanNameKey(subject.name),
        ))
          subject,
    ].take(3).toList();
    if (candidates.isEmpty) {
      final area = clues?.area;
      if (area == null) {
        if (primaryFailure != null) throw primaryFailure;
        return vision;
      }
      final nearby = await _suggestPlacesInArea(area, vision.labels);
      if (nearby.isNotEmpty) {
        return _possibleMatches(
          vision,
          nearby,
          areaHint: area,
          source: RecognitionSource.areaLookup,
        );
      }
      if (primaryFailure != null) throw primaryFailure;
      return RecognitionResult(
        name: vision.name,
        kind: vision.kind,
        description: vision.description,
        location: vision.location,
        recognizedAt: vision.recognizedAt,
        labels: vision.labels,
        areaHint: area,
      );
    }
    return _possibleMatches(
      vision,
      candidates,
      areaHint: clues?.area,
      source: suggestions.isNotEmpty
          ? (clues!.web ? RecognitionSource.web : RecognitionSource.sign)
          : verified.nonNulls.isNotEmpty
          ? RecognitionSource.placeLookup
          : catalogue != null
          ? RecognitionSource.visualEvidence
          : reference != null
          ? RecognitionSource.reference
          : vision.referenceCandidates.isNotEmpty
          ? RecognitionSource.vision
          : RecognitionSource.visualEvidence,
    );
  }

  RecognitionResult _possibleMatches(
    RecognitionResult vision,
    List<ReferenceSubject> candidates, {
    RecognitionSource source = RecognitionSource.vision,
    String? areaHint,
  }) => RecognitionResult(
    name: source == RecognitionSource.areaLookup
        ? 'Places in the area'
        : 'Possible matches',
    kind: 'unknown',
    description: '',
    location: '',
    recognizedAt: vision.recognizedAt,
    labels: vision.labels,
    source: source,
    referenceCandidates: candidates,
    areaHint: areaHint,
  );

  Future<List<GooglePlaceDetails>> searchPlaces(
    String query, {
    LatLng? near,
  }) async {
    final name = query.trim();
    if (name.isEmpty || name.length > 120) return const [];
    try {
      final response = await _request(
        {
          'operation': 'scan_places',
          'query': name,
          if (near != null) 'latitude': near.latitude,
          if (near != null) 'longitude': near.longitude,
        },
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

  bool _agreesWith(ReferenceSubject a, ReferenceSubject? b) {
    if (b == null) return true;
    if (a.kind != b.kind) return false;
    if (a.id == b.id || scanNameKey(a.name) == scanNameKey(b.name)) {
      return true;
    }
    final known = knownScanLandmark(a.name);
    return known != null && known.id == knownScanLandmark(b.name)?.id;
  }

  bool _agreesWithVision(ReferenceSubject subject, RecognitionResult vision) =>
      vision.referenceCandidates.every((other) => _agreesWith(subject, other));

  ReferenceSubject? _visualClueSubject(ClueMatch? clues) {
    final food = clues?.foodSuggestion;
    if (food != null) {
      return knownScanFood(food) ??
          ReferenceSubject(
            id: 'food:${scanNameKey(food)}',
            name: food,
            kind: 'food',
          );
    }
    final restaurant = clues?.restaurantSuggestion;
    if (restaurant != null) {
      return ReferenceSubject(
        id: 'restaurant:${scanNameKey(restaurant)}',
        name: restaurant,
        kind: 'restaurant',
      );
    }
    final landmark = clues?.visualSuggestion;
    if (landmark == null) return null;
    return knownScanLandmark(landmark) ??
        ReferenceSubject(
          id: 'visual:${scanNameKey(landmark)}',
          name: landmark,
          kind: 'landmark',
        );
  }

  ReferenceSubject? _catalogueSuggestion(String name, String? area) {
    final areaKey = scanNameKey(area ?? '');
    final key = scanNameKey(name);
    final subject =
        knownScanLandmark(name) ??
        (areaKey.isEmpty
            ? null
            : knownScanLandmark(
                ' $key '.replaceFirst(' $areaKey ', ' ').trim(),
              ));
    if (subject == null || areaKey.isEmpty) return subject;
    final attraction = scanLandmarkByName(subject.name);
    final preset = recognitionPresets
        .where((item) => item.id == subject.id)
        .firstOrNull;
    final location = scanNameKey(
      '${subject.name} ${subject.id} '
      '${attraction?.description ?? ''} ${preset?.location ?? ''}',
    );
    return ' $location '.contains(' $areaKey ') ? subject : null;
  }

  Future<GooglePlaceDetails?> lookupPlace(String name, {String? area}) async {
    final key = scanNameKey(name);
    final areaKey = area == null ? '' : scanNameKey(area);
    final query = area == null || ' $key '.contains(' $areaKey ')
        ? name
        : '$name, $area';
    final places = (await searchPlaces(
      query,
    )).where((place) => _isInArea(place, areaKey)).toList();
    String withoutArea(String value) {
      final normalized = scanNameKey(value);
      if (areaKey.isEmpty) return normalized;
      return ' $normalized '.replaceFirst(' $areaKey ', ' ').trim();
    }

    final subject =
        knownScanLandmark(name) ?? knownScanLandmark(withoutArea(name));
    final shortName = withoutArea(name);
    final matches = places.where((place) {
      final label = place.name ?? '';
      final known =
          knownScanLandmark(label) ?? knownScanLandmark(withoutArea(label));
      return key.isEmpty
          ? label.trim().toLowerCase() == name.trim().toLowerCase()
          : scanNameKey(label) == key ||
                (shortName.isNotEmpty && withoutArea(label) == shortName) ||
                (subject != null && known?.id == subject.id);
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

  bool _isInArea(GooglePlaceDetails place, String areaKey) {
    final address = scanNameKey(place.address ?? '');
    final location = address.isEmpty ? scanNameKey(place.name ?? '') : address;
    return areaKey.isEmpty || ' $location '.contains(' $areaKey ');
  }

  Future<List<ReferenceSubject>> _suggestPlacesInArea(
    String area,
    List<String> labels,
  ) async {
    final areaKey = scanNameKey(area);
    final type =
        labels
            .map(scanNameKey)
            .where(
              const {
                'temple',
                'mosque',
                'museum',
                'waterfall',
                'beach',
                'monument',
                'statue',
                'bridge',
                'tower',
                'garden',
                'park',
                'cave',
                'church',
              }.contains,
            )
            .firstOrNull ??
        'tourist attractions';
    final places = await searchPlaces('$type in $area');
    final seen = <String>{};
    return [
      for (final place in places)
        if (place.name case final name?
            when name.trim().isNotEmpty &&
                _isInArea(place, areaKey) &&
                place.id.isNotEmpty &&
                seen.add(place.id))
          ReferenceSubject(
            id: 'google:${place.id}',
            name: name,
            kind: 'landmark',
          ),
    ].take(3).toList();
  }

  Future<ReferenceSubject?> _verifyPlaceName(String name, String? area) async {
    final place = await lookupPlace(name, area: area);
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
        {
          'operation': 'recognize_context',
          'image': image,
          'include_visual_suggestion': true,
          'include_food_suggestion': true,
        },
        endpoint: _contextEndpoint,
        timeout: const Duration(seconds: 26),
      );
      return matchPhotoClues(data);
    } on ImageRecognitionException catch (error) {
      developer.log(error.message, name: 'ImageRecognition.context');
      return null;
    } catch (_) {
      developer.log('Invalid clue response', name: 'ImageRecognition.context');
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
        'Sign in with an online account to recognize your photo.',
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
          503 => 'Recognition or translation is unavailable. Try again later.',
          400 =>
            'This request could not be read. For photos, try JPEG, PNG or WebP.',
          _ => 'Recognition is unavailable. Try again later.',
        };
        throw ImageRecognitionException(
          message,
          retryable: response.statusCode >= 500,
        );
      }
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } on ImageRecognitionException {
      rethrow;
    } catch (_) {
      throw const ImageRecognitionException(
        'Unable to reach recognition or translation. Check your connection and try again.',
        retryable: true,
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
      name: 'Try another photo',
      kind: 'unknown',
      description:
          'Show the dish clearly, or include a readable restaurant sign or a wider landmark view.',
      location: '',
      recognizedAt: DateTime.now(),
      labels: labelNames,
    );
    landmarks.sort((a, b) => score(b).compareTo(score(a)));
    final namedLandmarks = <String, ReferenceSubject>{};
    for (final detection in landmarks) {
      final rawName = detection['name'];
      if (rawName is! String) continue;
      final name = rawName.trim();
      if (name.isEmpty) continue;
      final id = knownScanLandmark(name)?.id ?? 'vision:${name.toLowerCase()}';
      namedLandmarks.putIfAbsent(
        id,
        () => ReferenceSubject(
          id: 'vision:$name',
          name: name,
          kind: 'landmark',
          visionConfidence: score(detection),
        ),
      );
    }
    if (namedLandmarks.isNotEmpty) {
      final first = namedLandmarks.values.first;
      final known = knownScanLandmark(first.name);
      if (namedLandmarks.length == 1 &&
          known != null &&
          first.visionConfidence! >= 0.80) {
        return _referenceResult(first, noMatch, RecognitionSource.vision);
      }
      return _possibleMatches(noMatch, namedLandmarks.values.toList());
    }

    // Generic labels such as "rice" or "tower" do not identify an exact dish
    // or landmark.
    final landmarkHints = <String, ReferenceSubject>{};
    for (final detection in [...entities, ...labels]) {
      final rawName = detection['name'];
      if (rawName is! String) continue;
      final name = scanNameKey(rawName);
      if (score(detection) < 0.65) continue;
      final landmark = knownScanLandmark(name);
      if (landmark != null && name.contains(' ')) {
        landmarkHints[landmark.id] = landmark;
      }
      for (final preset in recognitionPresets) {
        if (preset.kind == 'landmark') continue;
        if (score(detection) < 0.8 ||
            !preset.aliases.any((alias) => name == scanNameKey(alias))) {
          continue;
        }
        return _possibleMatches(noMatch, [
          ReferenceSubject(
            id: preset.id,
            name: preset.name,
            kind: 'food',
            visionConfidence: score(detection),
          ),
        ]);
      }
    }
    return landmarkHints.isEmpty
        ? noMatch
        : _possibleMatches(noMatch, landmarkHints.values.toList());
  }

  void dispose() => _client.close();
}
