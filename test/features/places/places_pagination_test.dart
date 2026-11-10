import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/places/services/place_catalog_service.dart';
import 'package:smart_travel_planner/features/places/services/places_service.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';
import 'package:smart_travel_planner/features/places/models/google_place_details.dart';

class Catalog extends PlaceCatalogService {
  Catalog(this.rows);
  final List<Map<String, dynamic>> rows;
  @override
  Future<List<Map<String, dynamic>>> load({String? state}) async => rows;
}

class UnavailableGoogle extends GooglePlacesService {
  UnavailableGoogle(this.error);
  final String error;
  @override
  Future<GooglePlaceDetails?> fetchDetails(
    String placeId, {
    bool basic = false,
  }) async {
    lastError = error;
    return null;
  }
}

void main() {
  test(
    'empty nearby first page retains cursor to nearby second page',
    () async {
      final rows = List.generate(
        21,
        (i) => <String, dynamic>{
          'place_id': 'local-$i',
          'name': 'Place $i',
          'state': 'Penang',
          'category': 'Nature',
          'data_source': 'local',
          'latitude': i == 20 ? 5.414 : 5.1,
          'longitude': 100.329,
        },
      );
      final service = PlacesService(catalog: Catalog(rows));
      final first = await service.fetchPage(
        latitude: 5.414,
        longitude: 100.329,
      );
      expect(first.items, isEmpty);
      expect(first.hasMore, isTrue);
      expect(first.nextOffset, 20);
      final second = await service.fetchPage(
        latitude: 5.414,
        longitude: 100.329,
        offset: first.nextOffset,
      );
      expect(second.items.single.name, 'Place 20');
      expect(second.hasMore, isFalse);
    },
  );
  test(
    'auth, quota and offline failures remain visible with fallback',
    () async {
      for (final (error, expected) in [
        ('Sign in again', PlacesFailure.signIn),
        ('Google allowance exhausted', PlacesFailure.allowance),
        ('Unable to reach service', PlacesFailure.offline),
      ]) {
        final service = PlacesService(
          catalog: Catalog([
            {
              'place_id': 'ChITest123',
              'state': 'Penang',
              'data_source': 'google',
            },
          ]),
          google: UnavailableGoogle(error),
        );
        final result = await service.fetchPage(
          latitude: 5.414,
          longitude: 100.329,
        );
        expect(result.failure, expected);
        expect(result.failedCount, 1);
        expect(result.source, 'Local offline guide');
      }
    },
  );
  test('cancelled request does not expose old region results', () async {
    final service = PlacesService(catalog: Catalog([]));
    final result = await service.fetchPage(
      latitude: 5.414,
      longitude: 100.329,
      shouldContinue: () => false,
    );
    expect(result.source, 'Cancelled');
    expect(result.items, isEmpty);
  });
}
