import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/places/services/place_catalog_service.dart';
import 'package:smart_travel_planner/features/places/data/curated_attractions.dart';
import 'package:smart_travel_planner/features/places/data/attraction_metadata_resolver.dart';
import 'package:smart_travel_planner/features/places/utils/attraction_image_resolver.dart';
import 'package:smart_travel_planner/features/places/models/google_place_details.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';

void main() {
  test(
    'Catalog photo references survive conversion and distance copies for cards',
    () {
      final shape = PlaceCatalogService.asGoogleShape({
        'place_id': 'ChIJtest',
        'data_source': 'google',
        'name': 'Real place',
        'latitude': 3.1,
        'longitude': 101.6,
        'google_photos': [
          {
            'name': 'places/ChIJtest/photos/real',
            'authorAttributions': [
              {'displayName': 'Author'},
            ],
          },
          {'name': 'places/ChIJother/photos/wrong'},
        ],
      });
      final attraction = Attraction.fromGooglePlaceJson(
        shape,
        centerLat: 3.1,
        centerLon: 101.6,
      ).copyWith(distanceMeters: 200);
      expect(attraction.photoUrl, isNull);
      expect(
        attraction.googlePhotos.single.name,
        'places/ChIJtest/photos/real',
      );
      expect(
        attraction.googlePhotos.single.authors.single['displayName'],
        'Author',
      );
    },
  );
  test(
    'No curated attraction receives an invented category or landmark photo',
    () {
      for (final place in curatedMalaysianAttractions) {
        expect(AttractionImageResolver.resolveFallbackPhotoUrl(place), isNull);
        expect(AttractionMetadataResolver.resolveGallery(place), isEmpty);
      }
    },
  );
  test(
    'An explicit stock image is rejected instead of masquerading as the place',
    () {
      final place = Attraction(
        xid: 'local',
        name: 'Kwai Chai Hong',
        latitude: 3.1,
        longitude: 101.6,
        category: 'Artwork',
        photoUrl:
            'https://images.unsplash.com/photo-1565008447742-97f6f38c985c',
      );
      expect(AttractionImageResolver.resolvePhotoUrl(place), isNull);
    },
  );
  test(
    'Google gallery accepts only photo resources belonging to its exact place ID',
    () {
      final details = GooglePlaceDetails('ChIJtest', {
        'photos': [
          {'name': 'places/ChIJother/photos/a'},
          {
            'name': 'places/ChIJtest/photos/b',
            'authorAttributions': [
              {'displayName': 'Photographer'},
            ],
          },
        ],
      });
      expect(details.photos.length, 1);
      expect(details.photos.single.name, 'places/ChIJtest/photos/b');
      expect(
        details.photos.single.authors.single['displayName'],
        'Photographer',
      );
    },
  );
}
