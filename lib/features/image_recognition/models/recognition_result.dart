enum RecognitionSource {
  vision,
  reference,
  userConfirmedReference,
  web,
  sign,
  visualEvidence,
  placeLookup,
  areaLookup,
  foodSuggestion,
  userConfirmedClue,
}

class ReferenceSubject {
  const ReferenceSubject({
    required this.id,
    required this.name,
    required this.kind,
    this.visionConfidence,
  });

  final String id;
  final String name;
  final String kind;
  final double? visionConfidence;
  String? get placeId => id.startsWith('google:') ? id.substring(7) : null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': name,
    'kind': kind,
    if (visionConfidence != null) 'visionConfidence': visionConfidence,
  };

  factory ReferenceSubject.fromJson(Map<String, dynamic> json) =>
      ReferenceSubject(
        id: json['id'] as String,
        name: json['label'] as String,
        kind: json['kind'] as String,
        visionConfidence: (json['visionConfidence'] as num?)?.toDouble(),
      );
}

class RecognitionResult {
  const RecognitionResult({
    required this.name,
    required this.kind,
    required this.description,
    required this.location,
    required this.recognizedAt,
    this.confidence,
    this.sampleId,
    this.labels = const [],
    this.source = RecognitionSource.vision,
    this.referenceCandidates = const [],
    this.webSources = const [],
    this.placeId,
    this.visionLandmarkName,
    this.areaHint,
  });

  final String name;
  final String kind;
  final String description;
  final String location;
  final DateTime recognizedAt;
  final double? confidence;
  final String? sampleId;
  final List<String> labels;
  final RecognitionSource source;
  final List<ReferenceSubject> referenceCandidates;
  final List<String> webSources;
  final String? placeId;
  final String? visionLandmarkName;
  final String? areaHint;

  bool get isSample => sampleId != null;

  Map<String, dynamic> toJson() => {
    'name': name,
    'kind': kind,
    'description': description,
    'location': location,
    'recognizedAt': recognizedAt.toIso8601String(),
    'confidence': confidence,
    'sampleId': sampleId,
    'labels': labels,
    if (source != RecognitionSource.vision) 'source': source.name,
    if (referenceCandidates.isNotEmpty)
      'referenceCandidates': referenceCandidates
          .map((item) => item.toJson())
          .toList(),
    if (webSources.isNotEmpty) 'webSources': webSources,
    if (placeId != null) 'placeId': placeId,
    if (visionLandmarkName != null) 'visionLandmarkName': visionLandmarkName,
    if (areaHint != null) 'areaHint': areaHint,
  };

  factory RecognitionResult.fromJson(Map<String, dynamic> json) {
    final confidence = (json['confidence'] as num?)?.toDouble();
    return RecognitionResult(
      name: json['name'] as String,
      kind: json['kind'] as String,
      description: json['description'] as String,
      location: json['location'] as String,
      recognizedAt: DateTime.parse(json['recognizedAt'] as String),
      confidence: confidence != null && confidence.isFinite
          ? confidence.clamp(0, 1)
          : null,
      sampleId: json['sampleId'] as String?,
      labels: (json['labels'] as List? ?? []).whereType<String>().toList(),
      source:
          RecognitionSource.values
              .where((source) => source.name == json['source'])
              .firstOrNull ??
          RecognitionSource.vision,
      referenceCandidates: (json['referenceCandidates'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ReferenceSubject.fromJson)
          .toList(),
      webSources: (json['webSources'] as List? ?? [])
          .whereType<String>()
          .toList(),
      placeId: json['placeId'] as String?,
      visionLandmarkName: json['visionLandmarkName'] as String?,
      areaHint: json['areaHint'] as String?,
    );
  }
}
