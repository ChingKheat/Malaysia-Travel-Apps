import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/places/services/place_catalog_service.dart';
import 'package:smart_travel_planner/features/places/data/curated_attractions.dart';
import 'package:smart_travel_planner/features/places/data/attraction_metadata_resolver.dart';
import 'package:smart_travel_planner/features/places/utils/attraction_image_resolver.dart';
import 'package:smart_travel_planner/features/places/models/google_place_details.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Explore photos decode from the bundled assets for their exact places',
    () async {
      for (final (id, filename) in [
        ('curated_kl_03', 'central_market.jpg'),
        ('curated_kl_04', 'jalan_alor.jpg'),
        ('curated_kl_05', 'thean_hou_temple.jpg'),
        ('curated_kl_06', 'kl_tower.jpg'),
        ('curated_kl_07', 'petaling_street.jpg'),
        ('curated_kl_08', 'pavilion_kl.jpg'),
        ('curated_kl_09', 'perdana_botanical_gardens.jpg'),
        ('curated_kl_11', 'aquaria_klcc.jpg'),
        ('curated_kl_12', 'merdeka_square.jpg'),
        ('curated_kl_14', 'saloma_link_bridge.jpg'),
        ('curated_kl_15', 'kwai_chai_hong.jpg'),
        ('curated_johor_01', 'legoland_malaysia.jpg'),
        ('curated_johor_02', 'tan_hiok_nee.jpg'),
        ('curated_johor_03', 'sultan_abu_bakar_mosque.jpg'),
        ('curated_johor_04', 'rajakaliamman_glass_temple.jpg'),
        ('curated_johor_05', 'johor_zoo.jpg'),
        ('curated_johor_06', 'danga_bay_waterfront.jpg'),
        ('curated_johor_07', 'pasar_karat.jpg'),
        ('curated_johor_08', 'johor_heritage_food_trail.jpg'),
        ('curated_johor_09', 'puteri_harbour.jpg'),
        ('curated_johor_10', 'kota_tinggi_waterfalls.jpg'),
        ('curated_johor_11', 'desaru_beach.jpg'),
        ('curated_johor_12', 'johor_premium_outlets.jpg'),
        ('curated_johor_13', 'mid_valley_southkey.jpg'),
        ('curated_johor_14', 'johor_chinese_heritage_museum.jpg'),
        ('curated_johor_15', 'johor_bahru_city_square.jpg'),
      ]) {
        final attraction = curatedMalaysianAttractions.singleWhere(
          (place) => place.xid == id,
        );
        final asset = 'assets/recognition/$filename';
        expect(AttractionImageResolver.resolveAsset(attraction), asset);
        if (id.startsWith('curated_johor_')) {
          expect(AttractionImageResolver.photoCredit(attraction), isNotNull);
        }
        final bytes = await rootBundle.load(asset);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 960);
        frame.image.dispose();
        codec.dispose();
      }
    },
  );

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
