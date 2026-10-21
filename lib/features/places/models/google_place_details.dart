/// Live Google data, used only while displaying a place. Never serialize this
/// object into saved itineraries or the permanent place catalog.
class GooglePlaceDetails {
  const GooglePlaceDetails(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
  factory GooglePlaceDetails.fromApi(Map<String, dynamic> data) =>
      GooglePlaceDetails(data['id']?.toString() ?? '', data);
  String? get name => (data['displayName'] as Map?)?['text'] as String?;
  String? get address => data['formattedAddress'] as String?;
  String? get category =>
      (data['primaryTypeDisplayName'] as Map?)?['text'] as String?;
  String? get description =>
      (data['editorialSummary'] as Map?)?['text'] as String?;
  double? get rating => (data['rating'] as num?)?.toDouble();
  int? get reviewCount => (data['userRatingCount'] as num?)?.toInt();
  String? get website => data['websiteUri'] as String?;
  String? get phone => data['nationalPhoneNumber'] as String?;
  String? get mapsUri => data['googleMapsUri'] as String?;
  Map<String, dynamic> get hours =>
      Map<String, dynamic>.from(data['regularOpeningHours'] as Map? ?? {});
  double? get latitude =>
      ((data['location'] as Map?)?['latitude'] as num?)?.toDouble();
  double? get longitude =>
      ((data['location'] as Map?)?['longitude'] as num?)?.toDouble();
  List<GooglePlacePhoto> get photos => (data['photos'] as List? ?? [])
      .whereType<Map>()
      .map((p) => GooglePlacePhoto.fromApi(Map<String, dynamic>.from(p)))
      .where((p) => p.name.isNotEmpty)
      .take(5)
      .toList();
  List<Map<String, dynamic>> get attributions =>
      (data['attributions'] as List? ?? [])
          .whereType<Map>()
          .map((a) => Map<String, dynamic>.from(a))
          .toList();
}

class GooglePlacePhoto {
  const GooglePlacePhoto(this.name, this.authors);
  final String name;
  final List<Map<String, dynamic>> authors;
  factory GooglePlacePhoto.fromApi(Map<String, dynamic> data) =>
      GooglePlacePhoto(
        data['name']?.toString() ?? '',
        (data['authorAttributions'] as List? ?? [])
            .whereType<Map>()
            .map((a) => Map<String, dynamic>.from(a))
            .toList(),
      );
}
