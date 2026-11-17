import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/places/services/place_catalog_service.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';
import 'package:smart_travel_planner/features/places/services/places_service.dart';

class _Catalog extends PlaceCatalogService {
  _Catalog(this.rows);
  final List<Map<String, dynamic>> rows;
  @override
  Future<List<Map<String, dynamic>>> load({String? state}) async => rows;
}

class _UnavailableGoogle extends GooglePlacesService {
  @override
  Future<List<Map<String, dynamic>>> hydrateRows(
    Iterable<Map<String, dynamic>> rows, {
    bool full = false,
    int limit = 20,
    bool Function()? shouldContinue,
  }) async => [
    for (final row in rows)
      {
        ...row,
        '_live': false,
        '_loadError': 'Sign in with a registered account',
      },
  ];
}

void main() {
  test(
    'An empty real catalog does not substitute bundled attractions',
    () async {
      final page = await PlacesService(
        catalog: _Catalog([]),
      ).fetchPage(latitude: 3.143, longitude: 101.6883);
      expect(page.items, isEmpty);
      expect(page.failure, PlacesFailure.emptyCatalog);
    },
  );

  test(
    'Reference-only catalog stays empty without requesting Google hydration',
    () async {
      final page = await PlacesService(
        catalog: _Catalog([
          {
            'place_id': 'ChI-example',
            'data_source': 'google',
            'state': 'Kuala Lumpur',
          },
        ]),
        google: _UnavailableGoogle(),
      ).fetchPage(latitude: 3.143, longitude: 101.6883);
      expect(page.items, isEmpty);
      expect(page.failure, PlacesFailure.emptyCatalog);
    },
  );
}
