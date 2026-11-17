import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/places/data/curated_attractions.dart';
import 'package:smart_travel_planner/features/places/utils/attraction_image_resolver.dart';
import 'package:smart_travel_planner/features/places/services/verified_catalog_service.dart';
import 'package:smart_travel_planner/features/places/services/place_catalog_service.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reviewed import contains usable real-source records with no invented ratings',
    () {
      final rows =
          jsonDecode(
                File(
                  'docs/data/wikidata_kl/catalog_reviewed.json',
                ).readAsStringSync(),
              )
              as List;
      expect(rows, hasLength(9));
      for (final row in rows) {
        final data = Map<String, dynamic>.from(row as Map)
          ..['catalog_status'] = 'published';
        expect(VerifiedCatalogService.usable(data), true);
        final place = Attraction.fromGooglePlaceJson(
          PlaceCatalogService.asGoogleShape(data),
          centerLat: 3.14,
          centerLon: 101.69,
        );
        expect(place.googlePlaceId, isNull);
        expect(place.rating, isNull);
        expect(place.distanceMeters, lessThan(5000));
        if ([
          'wikidata_Q2660049',
          'wikidata_Q3330187',
          'wikidata_Q83063',
        ].contains(place.xid)) {
          expect(AttractionImageResolver.resolveAsset(place), isNotNull);
        }
      }
    },
  );

  test(
    'Bird Park and museum photos decode from the offline asset bundle',
    () async {
      for (final id in ['curated_kl_10', 'curated_kl_13']) {
        final place = curatedMalaysianAttractions.singleWhere(
          (p) => p.xid == id,
        );
        final path = AttractionImageResolver.resolveAsset(place);
        expect(path, isNotNull);
        final bytes = await rootBundle.load(path!);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0));
        expect(frame.image.height, greaterThan(0));
        frame.image.dispose();
        codec.dispose();
      }
    },
  );
}
