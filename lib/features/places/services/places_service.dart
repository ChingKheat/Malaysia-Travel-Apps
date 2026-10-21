import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:smart_travel_planner/features/places/data/curated_attractions.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';
import 'place_catalog_service.dart';

class PlacesService {
  PlacesService({http.Client? client, PlaceCatalogService? catalog})
    : _catalog = catalog ?? PlaceCatalogService();
  final PlaceCatalogService _catalog;
  Future<List<Attraction>> fetchPlacesNearLocation({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
    int limit = 20,
  }) async {
    final rows = await _catalog.load();
    final results = rows
        .map(
          (r) => Attraction.fromGooglePlaceJson(
            PlaceCatalogService.asGoogleShape(r),
            centerLat: latitude,
            centerLon: longitude,
          ),
        )
        .where((a) => (a.distanceMeters ?? double.infinity) <= radiusMeters)
        .toList();
    results.sort(
      (a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0),
    );
    return results.isNotEmpty
        ? results.take(limit).toList()
        : _fallback(latitude, longitude, limit);
  }

  Future<List<Attraction>> fetchPlacesByQuery({
    required String query,
    double? latitude,
    double? longitude,
    int limit = 20,
  }) async {
    final lat = latitude ?? 3.139, lng = longitude ?? 101.6869;
    final rows = await _catalog.load();
    final terms = query.toLowerCase().trim();
    return rows
        .where(
          (r) => '${r['name']} ${r['state']} ${r['category']}'
              .toLowerCase()
              .contains(terms),
        )
        .take(limit)
        .map(
          (r) => Attraction.fromGooglePlaceJson(
            PlaceCatalogService.asGoogleShape(r),
            centerLat: lat,
            centerLon: lng,
          ),
        )
        .toList();
  }

  List<Attraction> _fallback(double latitude, double longitude, int limit) {
    final rows = curatedMalaysianAttractions
        .map(
          (a) => a.copyWith(
            distanceMeters: const Distance().as(
              LengthUnit.Meter,
              LatLng(latitude, longitude),
              a.point,
            ),
          ),
        )
        .toList();
    rows.sort(
      (a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0),
    );
    return rows
        .where((a) => (a.distanceMeters ?? double.infinity) <= 50000)
        .take(limit)
        .toList();
  }
}
