import 'package:latlong2/latlong.dart';

class Attraction {
  const Attraction({
    required this.xid,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.category,
    this.description,
    this.distanceMeters,
  });

  final String xid;
  final String name;
  final double latitude;
  final double longitude;
  final String category;
  final String? description;
  final double? distanceMeters;

  LatLng get point => LatLng(latitude, longitude);

  Attraction copyWith({String? description, double? distanceMeters}) {
    return Attraction(
      xid: xid,
      name: name,
      latitude: latitude,
      longitude: longitude,
      category: category,
      description: description ?? this.description,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }

  factory Attraction.fromOpenTripMapJson(Map<String, dynamic> json) {
    final point = json['point'] as Map<String, dynamic>? ?? {};
    final name = (json['name'] as String?)?.trim();

    return Attraction(
      xid: (json['xid'] as String?) ?? '',
      name: name == null || name.isEmpty ? 'Unnamed attraction' : name,
      latitude: (point['lat'] as num?)?.toDouble() ?? 0,
      longitude: (point['lon'] as num?)?.toDouble() ?? 0,
      category: _cleanCategory(json['kinds'] as String?),
      distanceMeters: (json['dist'] as num?)?.toDouble(),
    );
  }

  factory Attraction.fromOpenTripMapDetails(
    Attraction base,
    Map<String, dynamic> json,
  ) {
    final wikipedia = json['wikipedia_extracts'] as Map<String, dynamic>?;
    final info = json['info'] as Map<String, dynamic>?;
    final description =
        (wikipedia?['text'] as String?) ??
        (info?['descr'] as String?) ??
        base.description;

    return base.copyWith(description: description);
  }

  static String _cleanCategory(String? rawKinds) {
    if (rawKinds == null || rawKinds.isEmpty) return 'Tourist attraction';
    return rawKinds
        .split(',')
        .take(2)
        .map((kind) => kind.replaceAll('_', ' '))
        .join(', ');
  }
}
