import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';
import '../data/curated_attractions.dart';
import 'place_catalog_service.dart';
import 'google_places_service.dart';
import 'verified_catalog_service.dart';
import 'package:smart_travel_planner/shared/data/malaysia_states.dart';

class PlacesService {
  PlacesService({
    http.Client? client,
    PlaceCatalogService? catalog,
    GooglePlacesService? google,
    this.includeCuratedFallback = false,
  }) : _catalog = catalog ?? VerifiedCatalogService();
  final PlaceCatalogService _catalog;
  final bool includeCuratedFallback;

  bool hasMore = false;
  List<Map<String, dynamic>> attributions = [];
  String? get lastError =>
      _catalog is VerifiedCatalogService ? _catalog.loadError : null;

  static String nearestState(double latitude, double longitude) =>
      nearestMalaysiaState(LatLng(latitude, longitude));

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
    final catalogRows = rows
        .where(VerifiedCatalogService.usable)
        .where((row) => radiusMeters != null || row['state'] == selectedState)
        .toList();
    final curated = includeCuratedFallback && catalogRows.isEmpty
        ? curatedAttractionsForState(selectedState).toList()
        : const <Attraction>[];
    final center = LatLng(latitude, longitude);
    final candidates = curated.isNotEmpty
        ? curated.map(
            (place) => place.copyWith(
              distanceMeters: const Distance().as(
                LengthUnit.Meter,
                center,
                place.point,
              ),
            ),
          )
        : catalogRows.map(
            (row) => Attraction.fromGooglePlaceJson(
              PlaceCatalogService.asGoogleShape(row),
              centerLat: latitude,
              centerLon: longitude,
            ),
          );
    final search = query.trim().toLowerCase();
    final byId = <String, Attraction>{
      for (final place in candidates)
        if (matchesCategory(place.category, category) &&
            place.name.toLowerCase().contains(search) &&
            (radiusMeters == null ||
                (place.distanceMeters ?? double.infinity) <= radiusMeters))
          place.xid: place,
    };
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
      source: curated.isNotEmpty
          ? 'Curated app catalog'
          : _catalog.lastLoadOffline
          ? 'Saved verified catalog'
          : 'Verified database catalog',
      failure: catalogRows.isEmpty && curated.isEmpty
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
    if (kind.contains('theme park') || kind.contains('amusement park')) {
      if (cat.contains('nature')) return false;
      if (cat.contains('sight')) return true;
    }
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
