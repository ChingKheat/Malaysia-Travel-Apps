import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';
import 'place_catalog_service.dart';
import 'google_places_service.dart';
import 'verified_catalog_service.dart';
import 'package:smart_travel_planner/shared/data/malaysia_states.dart';

class PlacesService {
  PlacesService({
    http.Client? client,
    PlaceCatalogService? catalog,
    GooglePlacesService? google,
  }) : _catalog = catalog ?? VerifiedCatalogService();
  final PlaceCatalogService _catalog;

  bool hasMore = false;
  List<Map<String, dynamic>> attributions = [];
  String? get lastError =>
      _catalog is VerifiedCatalogService ? _catalog.loadError : null;

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
    int? radiusMeters = 5000,
    int offset = 0,
    int limit = 20,
    String? state,
    String query = '',
    String category = 'All',
    bool Function()? shouldContinue,
  }) async {
    final selectedState = state ?? nearestState(latitude, longitude);
    final rows = await _catalog.load(state: selectedState);
    if (shouldContinue != null && !shouldContinue()) {
      return const PlacesPage(
        items: [],
        nextOffset: 0,
        hasMore: false,
        source: 'Cancelled',
      );
    }
    final byId = <String, Attraction>{};
    for (final row in rows.where(VerifiedCatalogService.usable)) {
      if (radiusMeters == null && row['state'] != selectedState) continue;
      if (!matchesCategory(row['category'].toString(), category)) continue;
      if (!row['name'].toString().toLowerCase().contains(
        query.trim().toLowerCase(),
      )) {
        continue;
      }
      final item = Attraction.fromGooglePlaceJson(
        PlaceCatalogService.asGoogleShape(row),
        centerLat: latitude,
        centerLon: longitude,
      );
      if (radiusMeters == null ||
          (item.distanceMeters ?? double.infinity) <= radiusMeters) {
        byId[item.xid] = item;
      }
    }
    final items = byId.values.toList()
      ..sort((a, b) {
        final distance = (a.distanceMeters ?? 0).compareTo(
          b.distanceMeters ?? 0,
        );
        return distance != 0 ? distance : a.xid.compareTo(b.xid);
      });
    final start = offset.clamp(0, items.length);
    final pageItems = items.skip(start).take(limit.clamp(1, 20)).toList();
    final next = start + pageItems.length;
    hasMore = next < items.length;
    return PlacesPage(
      items: pageItems,
      nextOffset: next,
      hasMore: hasMore,
      source: _catalog.lastLoadOffline
          ? 'Saved verified catalog'
          : 'Verified database catalog',
      failure:
          items.isEmpty && rows.where(VerifiedCatalogService.usable).isEmpty
          ? (_catalog is VerifiedCatalogService && _catalog.setupRequired
                ? PlacesFailure.service
                : _catalog.lastLoadOffline
                ? PlacesFailure.offline
                : PlacesFailure.emptyCatalog)
          : PlacesFailure.none,
      message: _catalog is VerifiedCatalogService ? _catalog.loadError : null,
      savedAt: _catalog is VerifiedCatalogService ? _catalog.savedAt : null,
    );
  }

  static bool matchesCategory(String value, String filter) {
    final cat = filter.toLowerCase(), kind = value.toLowerCase();
    if (cat == 'all') return true;
    final terms = cat.contains('cafe')
        ? ['cafe', 'coffee']
        : cat.contains('food')
        ? ['food', 'cafe', 'restaurant', 'dining', 'bakery', 'hawker']
        : cat.contains('shop')
        ? ['shop', 'market', 'mall', 'store']
        : cat.contains('nature')
        ? ['nature', 'natural', 'park', 'garden', 'forest', 'beach', 'outdoor']
        : cat.contains('sight')
        ? [
            'sight',
            'attraction',
            'culture',
            'cultural',
            'historic',
            'architecture',
            'landmark',
            'monument',
            'temple',
            'museum',
            'religion',
          ]
        : [cat];
    return terms.any(kind.contains);
  }

  // Compatibility for existing callers. New UI uses the complete page result.
  Future<List<Attraction>> fetchPlacesNearLocation({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
    int limit = 20,
    int offset = 0,
    String? state,
    String query = '',
    String category = 'All',
    bool Function()? shouldContinue,
  }) async => (await fetchPage(
    latitude: latitude,
    longitude: longitude,
    radiusMeters: radiusMeters,
    limit: limit,
    offset: offset,
    state: state,
    query: query,
    category: category,
    shouldContinue: shouldContinue,
  )).items;

  Future<List<Attraction>> fetchPlacesByQuery({
    required String query,
    double? latitude,
    double? longitude,
    int limit = 20,
  }) async {
    return (await fetchPage(
      latitude: latitude ?? 3.139,
      longitude: longitude ?? 101.6869,
      query: query,
      limit: limit,
    )).items;
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
    this.savedAt,
  });
  final List<Attraction> items;
  final int nextOffset;
  final bool hasMore;
  final String source;
  final PlacesFailure failure;
  final String? message;
  final int failedCount;
  final List<Map<String, dynamic>> attributions;
  final DateTime? savedAt;
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
    PlacesFailure.none => 'Results from the attraction catalog.',
    PlacesFailure.emptyCatalog =>
      'No verified attraction catalog is published for this area yet. An administrator must import reviewed source data.',
    PlacesFailure.signIn =>
      'Sign in again with a registered account to load live Google places.',
    PlacesFailure.allowance =>
      'Google allowance or request limit reached. Try again later.',
    PlacesFailure.offline =>
      'Connection unavailable. Showing available local information.',
    PlacesFailure.service =>
      message ?? 'Some place details could not be loaded.',
  };
}
