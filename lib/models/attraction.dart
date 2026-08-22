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

  factory Attraction.fromOverpassJson(
    Map<String, dynamic> json, {
    required double centerLat,
    required double centerLon,
  }) {
    final tags = json['tags'] as Map<String, dynamic>? ?? {};
    final id = json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    final name = (tags['name'] as String?) ??
        (tags['name:en'] as String?) ??
        (tags['brand'] as String?) ??
        'Local Spot';

    final lat = (json['lat'] as num?)?.toDouble() ?? centerLat;
    final lon = (json['lon'] as num?)?.toDouble() ?? centerLon;

    final category = _determineOverpassCategory(tags);
    final description = (tags['description'] as String?) ??
        (tags['opening_hours'] != null ? 'Opening hours: ${tags['opening_hours']}' : null) ??
        (tags['cuisine'] != null ? 'Cuisine: ${tags['cuisine']}' : null) ??
        'Points of interest in Malaysia';

    final distance = const Distance().as(
      LengthUnit.Meter,
      LatLng(centerLat, centerLon),
      LatLng(lat, lon),
    );

    return Attraction(
      xid: 'osm_$id',
      name: name,
      latitude: lat,
      longitude: lon,
      category: category,
      description: description,
      distanceMeters: distance,
    );
  }

  static String _determineOverpassCategory(Map<String, dynamic> tags) {
    if (tags.containsKey('tourism')) {
      final t = tags['tourism'].toString();
      if (t == 'hotel' || t == 'hostel') return 'Accommodation, Hotel';
      if (t == 'museum' || t == 'artwork') return 'Culture, Museum, Sights';
      if (t == 'attraction' || t == 'viewpoint') return 'Sights, Landmark';
      return 'Tourism, Sights';
    }
    if (tags.containsKey('amenity')) {
      final a = tags['amenity'].toString();
      if (a == 'restaurant' || a == 'cafe' || a == 'fast_food' || a == 'food_court') {
        final cuisine = tags['cuisine'] != null ? ' (${tags['cuisine']})' : '';
        return 'Foods, Dining$cuisine';
      }
      if (a == 'place_of_worship') return 'Religion, Cultural, Historic';
    }
    if (tags.containsKey('shop') || tags.containsKey('marketplace')) {
      return 'Shops, Shopping, Market';
    }
    if (tags.containsKey('historic')) {
      return 'Historic, Cultural, Sights';
    }
    if (tags.containsKey('leisure') || tags.containsKey('park')) {
      return 'Park, Nature, Outdoor';
    }
    return 'Tourist attraction, Sights';
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
