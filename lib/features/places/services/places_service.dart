import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:smart_travel_planner/features/places/data/curated_attractions.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';
import 'place_catalog_service.dart';
import 'google_places_service.dart';
import 'package:smart_travel_planner/shared/data/malaysia_states.dart';

class PlacesService {
  PlacesService({
    http.Client? client,
    PlaceCatalogService? catalog,
    GooglePlacesService? google,
  }) : _catalog = catalog ?? PlaceCatalogService(),
       _google = google ?? GooglePlacesService(client: client);
  final PlaceCatalogService _catalog;
  final GooglePlacesService _google;
  bool hasMore = false;
  List<Map<String, dynamic>> attributions = [];
  String? get lastError => _google.lastError;

  static String nearestState(double latitude, double longitude) {
    var best = double.infinity;
    var state = 'Kuala Lumpur';
    for (final candidate in malaysiaStatesData) {
      for (final area in candidate.areas) {
        final distance = const Distance().as(
          LengthUnit.Meter,
          LatLng(latitude, longitude),
          LatLng(area.latitude, area.longitude),
        );
        if (distance < best) {
          best = distance;
          state = candidate.name;
        }
      }
    }
    return state;
  }

  Future<PlacesPage> fetchPage({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
    int offset = 0,
    int limit = 20,
    String? state,
    bool Function()? shouldContinue,
  }) async {
    final references = await _catalog.load(
      state: state ?? nearestState(latitude, longitude),
    );
    final pageSize = limit.clamp(1, 20);
    final selected = references.skip(offset).take(pageSize).toList();
    final next = offset + selected.length;
    final rows = await _google.hydrateRows(
      selected,
      shouldContinue: shouldContinue,
    );
    if (shouldContinue != null && !shouldContinue()) {
      return const PlacesPage(
        items: [],
        nextOffset: 0,
        hasMore: false,
        source: 'Cancelled',
      );
    }
    final failures = rows
        .where(
          (r) => PlaceCatalogService.isGoogleReference(r) && r['_live'] != true,
        )
        .toList();
    final message = failures
        .map((r) => r['_loadError']?.toString())
        .whereType<String>()
        .firstOrNull;
    final status = failures.isNotEmpty
        ? PlacesPage.failureFor(message)
        : references.isEmpty
        ? (_catalog.lastLoadOffline
              ? PlacesFailure.offline
              : PlacesFailure.emptyCatalog)
        : PlacesFailure.none;
    final items =
        rows
            .where(
              (r) =>
                  !PlaceCatalogService.isGoogleReference(r) ||
                  r['_live'] == true,
            )
            .map(
              (r) => Attraction.fromGooglePlaceJson(
                PlaceCatalogService.asGoogleShape(r),
                centerLat: latitude,
                centerLon: longitude,
              ),
            )
            .where((a) => (a.distanceMeters ?? double.infinity) <= radiusMeters)
            .toList()
          ..sort(
            (a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0),
          );
    final fallback =
        items.isEmpty && (failures.isNotEmpty || references.isEmpty);
    final result = PlacesPage(
      items: fallback
          ? _fallback(latitude, longitude, pageSize, radiusMeters)
          : items,
      nextOffset: next,
      hasMore: next < references.length,
      source: fallback
          ? 'Local offline guide'
          : _catalog.lastLoadOffline
          ? 'Saved catalog · live Google details'
          : 'Catalog · live place details',
      failure: status,
      message: message,
      failedCount: failures.length,
      attributions: [
        for (final r in rows)
          ...((r['attributions'] as List?) ?? []).whereType<Map>().map(
            (a) => Map<String, dynamic>.from(a),
          ),
      ],
    );
    hasMore = result.hasMore;
    return result;
  }

  // Compatibility for existing callers. New UI uses the complete page result.
  Future<List<Attraction>> fetchPlacesNearLocation({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
    int limit = 20,
    int offset = 0,
    String? state,
    bool Function()? shouldContinue,
  }) async => (await fetchPage(
    latitude: latitude,
    longitude: longitude,
    radiusMeters: radiusMeters,
    limit: limit,
    offset: offset,
    state: state,
    shouldContinue: shouldContinue,
  )).items;

  Future<List<Attraction>> fetchPlacesByQuery({
    required String query,
    double? latitude,
    double? longitude,
    int limit = 20,
  }) async {
    final lat = latitude ?? 3.139, lng = longitude ?? 101.6869;
    final references = await _catalog.load(state: nearestState(lat, lng));
    final rows = await _google.hydrateRows(references.take(limit.clamp(1, 20)));
    final terms = query.toLowerCase().trim();
    return rows
        .where(
          (r) =>
              !PlaceCatalogService.isGoogleReference(r) || r['_live'] == true,
        )
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

  List<Attraction> _fallback(
    double latitude,
    double longitude,
    int limit,
    int radiusMeters,
  ) {
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
        .where((a) => (a.distanceMeters ?? double.infinity) <= radiusMeters)
        .take(limit)
        .toList();
  }
}

enum PlacesFailure { none, emptyCatalog, signIn, allowance, offline, service }

class PlacesPage {
  const PlacesPage({
    required this.items,
    required this.nextOffset,
    required this.hasMore,
    required this.source,
    this.failure = PlacesFailure.none,
    this.message,
    this.failedCount = 0,
    this.attributions = const [],
  });
  final List<Attraction> items;
  final int nextOffset;
  final bool hasMore;
  final String source;
  final PlacesFailure failure;
  final String? message;
  final int failedCount;
  final List<Map<String, dynamic>> attributions;
  static PlacesFailure failureFor(String? message) {
    final text = (message ?? '').toLowerCase();
    if (text.contains('sign in') ||
        text.contains('registered account') ||
        text.contains('401')) {
      return PlacesFailure.signIn;
    }
    if (text.contains('allowance') ||
        text.contains('429') ||
        text.contains('too many')) {
      return PlacesFailure.allowance;
    }
    if (text.contains('reach') || text.contains('network')) {
      return PlacesFailure.offline;
    }
    return PlacesFailure.service;
  }

  String get notice => switch (failure) {
    PlacesFailure.none => 'Results within 5 km from loaded records only.',
    PlacesFailure.emptyCatalog =>
      'No catalog for this area. An administrator can import places.',
    PlacesFailure.signIn =>
      'Sign in again to load Google places. Local guide shown when available.',
    PlacesFailure.allowance =>
      'Google allowance or request limit reached. Try again later.',
    PlacesFailure.offline =>
      'Connection unavailable. Showing available local information.',
    PlacesFailure.service =>
      message ?? 'Some place details could not be loaded.',
  };
}
