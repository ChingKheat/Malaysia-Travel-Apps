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
    this.rating,
    this.userRatingsTotal,
    this.isIndoor,
    this.photoUrl,
  });

  final String xid;
  final String name;
  final double latitude;
  final double longitude;
  final String category;
  final String? description;
  final double? distanceMeters;
  final double? rating;
  final int? userRatingsTotal;
  final bool? isIndoor;
  final String? photoUrl;

  LatLng get point => LatLng(latitude, longitude);

  Attraction copyWith({
    String? description,
    double? distanceMeters,
    double? rating,
    int? userRatingsTotal,
    bool? isIndoor,
    String? photoUrl,
  }) {
    return Attraction(
      xid: xid,
      name: name,
      latitude: latitude,
      longitude: longitude,
      category: category,
      description: description ?? this.description,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      rating: rating ?? this.rating,
      userRatingsTotal: userRatingsTotal ?? this.userRatingsTotal,
      isIndoor: isIndoor ?? this.isIndoor,
      photoUrl: photoUrl ?? this.photoUrl,
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

  factory Attraction.fromGooglePlaceJson(
    Map<String, dynamic> json, {
    required double centerLat,
    required double centerLon,
  }) {
    final id = json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    final displayName = json['displayName'];
    final name = (displayName is Map ? displayName['text'] as String? : null) ??
        (json['name'] as String?) ??
        'Local Spot';

    final location = json['location'] as Map<String, dynamic>? ?? {};
    final lat = (location['latitude'] as num?)?.toDouble() ?? centerLat;
    final lon = (location['longitude'] as num?)?.toDouble() ?? centerLon;

    final primaryTypeDisplayName = json['primaryTypeDisplayName'];
    final category = (primaryTypeDisplayName is Map ? primaryTypeDisplayName['text'] as String? : null) ??
        _formatGoogleType((json['types'] as List?)?.firstOrNull?.toString()) ??
        'Tourism, Sights';

    final editorialSummary = json['editorialSummary'];
    final description = (editorialSummary is Map ? editorialSummary['text'] as String? : null) ??
        (json['formattedAddress'] as String?) ??
        'Points of interest in Malaysia';

    final distance = const Distance().as(
      LengthUnit.Meter,
      LatLng(centerLat, centerLon),
      LatLng(lat, lon),
    );

    final rating = (json['rating'] as num?)?.toDouble();
    final userRatingsTotal = (json['userRatingCount'] as num?)?.toInt() ??
        (json['user_ratings_total'] as num?)?.toInt();
    final isIndoor = json['is_indoor'] as bool?;
    final photoUrl = json['photo_url'] as String?;

    return Attraction(
      xid: 'google_$id',
      name: name,
      latitude: lat,
      longitude: lon,
      category: category,
      description: description,
      distanceMeters: distance,
      rating: rating,
      userRatingsTotal: userRatingsTotal,
      isIndoor: isIndoor,
      photoUrl: photoUrl,
    );
  }

  static String? _formatGoogleType(String? type) {
    if (type == null) return null;
    return type
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
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
