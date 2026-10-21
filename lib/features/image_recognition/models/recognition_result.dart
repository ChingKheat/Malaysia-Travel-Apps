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
  });

  final String name;
  final String kind;
  final String description;
  final String location;
  final DateTime recognizedAt;
  final double? confidence;
  final String? sampleId;
  final List<String> labels;

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
    );
  }
}
