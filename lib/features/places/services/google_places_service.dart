import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'place_catalog_service.dart';
import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/core/config/supabase_config.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';
import 'package:smart_travel_planner/features/places/models/google_place_details.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'place_classifier.dart';
import 'package:smart_travel_planner/features/itinerary/services/smart_itinerary_service.dart';

class GooglePlacesService {
  GooglePlacesService({
    http.Client? client,
    this.accessToken,
    String? endpoint,
    PlaceCatalogService? catalog,
  }) : _catalog = catalog ?? PlaceCatalogService(),
       _client = client ?? http.Client(),
       _endpoint =
           endpoint ??
           '${SupabaseConfig.supabaseUrl}/functions/v1/google-places';
  final PlaceCatalogService _catalog;
  final http.Client _client;
  final String? accessToken;
  final String _endpoint;
  String? lastError;
  int? lastStatusCode;
  static bool get isAvailable =>
      (!AuthService().isGuest &&
      SupabaseConfig.client?.auth.currentSession?.user.id ==
          AuthService().currentUser?.uid &&
      SupabaseConfig.client?.auth.currentSession != null);
  // Only coalesce concurrent requests. Completed Google responses are not a database cache.
  static final Map<String, Future<List<Map<String, dynamic>>>> _inFlight = {};
  static void clearMemoryCache() => _inFlight.clear();
  String? get _token =>
      accessToken ??
      (!AuthService().isGuest &&
              SupabaseConfig.client?.auth.currentSession?.user.id ==
                  AuthService().currentUser?.uid &&
              SupabaseConfig.client?.auth.currentSession != null
          ? SupabaseConfig.client?.auth.currentSession?.accessToken
          : null);
  Future<http.Response?> _request(Map<String, dynamic> body) async {
    lastStatusCode = null;
    final token = _token;
    if (token == null) {
      lastStatusCode = 401;
      lastError =
          'Sign in with a registered account to load Google place data.';
      return null;
    }
    try {
      final response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'apikey': SupabaseConfig.supabaseAnonKey,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      lastStatusCode = response.statusCode;
      if (response.statusCode != 200) {
        lastError = 'Place service unavailable (${response.statusCode}).';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map) {
            lastError = decoded['error']?.toString() ?? lastError;
            final upstream = decoded['upstreamStatus'];
            if (upstream is int) {
              lastStatusCode = upstream;
              lastError = '$lastError (Google HTTP $upstream)';
            }
          }
        } catch (_) {}
        return response;
      }
      lastError = null;
      return response;
    } catch (_) {
      lastError =
          'Unable to reach the place service. Your saved schedule is still available.';
      return null;
    }
  }

  Future<http.Response?> requestOperation(Map<String, dynamic> body) =>
      _request(body);

  /// Reuse admin-synced data even when Google or Auth is unavailable.
  Future<List<Map<String, dynamic>>> fetchPlacesWithDatabaseCache({
    required String destinationState,
    required String query,
    bool isMeal = false,
    int maxResults = 8,
    bool Function()? shouldContinue,
  }) async {
    final rows = await _catalog.load(state: destinationState);
    final matches = rows
        .where((row) => PlaceCatalogService.isMeal(row) == isMeal)
        .toList();
    matches.sort(
      (a, b) =>
          ((b['rating'] as num?) ?? 0).compareTo((a['rating'] as num?) ?? 0),
    );
    final hydrated = await hydrateRows(
      matches.take(maxResults.clamp(0, 32)),
      full: true,
      limit: 32,
      shouldContinue: shouldContinue,
    );
    return hydrated
        .where(
          (r) =>
              !PlaceCatalogService.isGoogleReference(r) || r['_live'] == true,
        )
        .map(PlaceCatalogService.asGoogleShape)
        .toList();
  }

  /// Hydrate only a bounded displayed page/candidate pool. Never save responses.
  Future<List<Map<String, dynamic>>> hydrateRows(
    Iterable<Map<String, dynamic>> rows, {
    bool full = false,
    int limit = 20,
    bool Function()? shouldContinue,
  }) async {
    final selected = rows.take(limit.clamp(0, 32)).toList();
    final result = <Map<String, dynamic>>[];
    // Small batches avoid exceeding the per-user burst limit during planning.
    for (var start = 0; start < selected.length; start += 4) {
      if (shouldContinue != null && !shouldContinue()) break;
      final batch = selected.skip(start).take(4);
      final hydrated = await Future.wait(
        batch.map((row) async {
          if (!PlaceCatalogService.isGoogleReference(row)) return row;
          final details = await fetchDetails(
            row['place_id'].toString(),
            basic: !full,
          );
          final lat = details?.latitude;
          final lng = details?.longitude;
          final validLocation =
              lat != null &&
              lng != null &&
              lat.isFinite &&
              lng.isFinite &&
              lat.abs() <= 90 &&
              lng.abs() <= 180 &&
              (lat != 0 || lng != 0);
          if (details == null ||
              details.name?.trim().isNotEmpty != true ||
              !validLocation) {
            return {
              ...PlaceCatalogService.persistentRow(row),
              '_loadError': details == null
                  ? lastError ?? 'Place details unavailable'
                  : 'Google did not return a usable name and location. Retry later.',
            };
          }
          return <String, dynamic>{
            ...row,
            '_live': true,
            '_fullDetails': full,
            'google_photos': details.photos
                .map((p) => {'name': p.name, 'authorAttributions': p.authors})
                .toList(),
            '_addressComponents': details.data['addressComponents'],
            'name': details.name ?? 'Name unavailable',
            'category': details.category ?? row['category'],
            'latitude': details.latitude ?? 0.0,
            'longitude': details.longitude ?? 0.0,
            'rating': details.rating,
            'user_ratings_total': details.reviewCount,
            'operating_hours': details.hours,
            'attributions': details.attributions,
          };
        }),
      );
      result.addAll(hydrated);
      if (hydrated.every(
        (r) => PlaceCatalogService.isGoogleReference(r) && r['_live'] != true,
      )) {
        result.addAll(
          selected.skip(start + 4).map(PlaceCatalogService.persistentRow),
        );
        break;
      }
    }
    return result;
  }

  Future<Map<String, dynamic>?> budgetStatus() async {
    final response = await _request({'operation': 'budget_status'});
    if (response?.statusCode != 200) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(response!.body) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchPlacesByText({
    required String query,
    required String state,
    int maxResults = 10,
  }) => _fetchPlacesByText(query: query, state: state, maxResults: maxResults);

  Future<List<Map<String, dynamic>>> searchPlannerPlaces({
    required String query,
    required String state,
  }) => _fetchPlacesByText(
    query: query,
    state: state,
    maxResults: 8,
    planner: true,
  );

  Future<List<Map<String, dynamic>>> _fetchPlacesByText({
    required String query,
    required String state,
    int maxResults = 10,
    bool planner = false,
  }) async {
    final key = '$_endpoint|${_token ?? ''}|$state|$query|$maxResults|$planner';
    final existing = _inFlight[key];
    if (existing != null) return existing;
    final pending = _search(query, state, maxResults, planner: planner);
    _inFlight[key] = pending;
    try {
      return await pending;
    } finally {
      if (identical(_inFlight[key], pending)) _inFlight.remove(key);
    }
  }

  Future<List<Map<String, dynamic>>> _search(
    String query,
    String state,
    int maxResults, {
    required bool planner,
  }) async {
    final data = await searchPage(
      query: query,
      state: state,
      pageSize: maxResults,
      planner: planner,
    );
    if (data == null) return [];
    try {
      return (data['places'] as List? ?? [])
          .whereType<Map>()
          .map((p) => Map<String, dynamic>.from(p))
          .where((p) {
            final location = p['location'] as Map?;
            final lat = location?['latitude'];
            final lng = location?['longitude'];
            return p['id'] is String &&
                lat is num &&
                lng is num &&
                lat.isFinite &&
                lng.isFinite &&
                lat >= 1 &&
                lat <= 7.5 &&
                lng >= 99 &&
                lng <= 120;
          })
          .toList();
    } catch (_) {
      lastError = 'The place service returned invalid data.';
      return [];
    }
  }

  Future<Map<String, dynamic>?> searchPageWithRetry({
    required String query,
    required String state,
    String? pageToken,
    void Function(int attempt)? onAttempt,
    bool Function()? shouldContinue,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    for (var attempt = 1; attempt <= 3; attempt++) {
      if (shouldContinue != null && !shouldContinue()) return null;
      onAttempt?.call(attempt);
      final result = await searchPage(
        query: query,
        state: state,
        pageToken: pageToken,
      );
      if (result != null) return result;
      if (shouldContinue != null && !shouldContinue()) return null;
      // Never retry authentication, invalid parameters or the app allowance gate.
      final transient =
          lastStatusCode == null ||
          (lastStatusCode ?? 0) >= 500 ||
          (lastStatusCode == 429 &&
              (lastError?.contains('Google HTTP 429') ?? false));
      if (!transient || attempt == 3) return null;
      await Future<void>.delayed(retryDelay * attempt);
    }
    return null;
  }

  Future<Map<String, dynamic>?> searchPage({
    required String query,
    String? state,
    int pageSize = 20,
    String? pageToken,
    bool planner = false,
  }) async {
    final response = await _request({
      'operation': planner ? 'planner_search' : 'search',
      'query': query,
      'state': ?state,
      'pageSize': pageSize.clamp(1, 20),
      'pageToken': ?pageToken,
    });
    if (response?.statusCode != 200) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(response!.body) as Map);
    } catch (_) {
      lastError = 'The place service returned invalid data.';
      return null;
    }
  }

  Future<GooglePlaceDetails?> fetchDetails(
    String placeId, {
    bool basic = false,
  }) async {
    final key = jsonEncode([_endpoint, _token, placeId, basic]);
    final existing = _detailsInFlight[key];
    if (existing != null) {
      final result = await existing;
      lastError = result == null ? 'Place details unavailable.' : null;
      return result;
    }
    final pending = _fetchDetails(placeId, basic: basic);
    _detailsInFlight[key] = pending;
    try {
      return await pending;
    } finally {
      if (identical(_detailsInFlight[key], pending)) {
        _detailsInFlight.remove(key);
      }
    }
  }

  static final Map<String, Future<GooglePlaceDetails?>> _detailsInFlight = {};

  Future<GooglePlaceDetails?> _fetchDetails(
    String placeId, {
    required bool basic,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{5,255}$').hasMatch(placeId)) return null;
    final response = await _request({
      'operation': 'details',
      'placeId': placeId,
      'profile': basic ? 'basic' : 'full',
    });
    if (response?.statusCode != 200) return null;
    try {
      final details = GooglePlaceDetails.fromApi(
        Map<String, dynamic>.from(jsonDecode(response!.body) as Map),
      );
      if (details.id != placeId) {
        lastError = 'Unexpected place details.';
        return null;
      }
      return details;
    } catch (_) {
      lastError = 'Place details unavailable.';
      return null;
    }
  }

  Future<Uint8List?> fetchPhoto(
    GooglePlacePhoto photo, {
    int width = 800,
  }) async => (await fetchPhotoResult(photo, width: width)).bytes;

  Future<({Uint8List? bytes, bool expired})> fetchPhotoResult(
    GooglePlacePhoto photo, {
    int width = 800,
  }) async {
    final response = await _request({
      'operation': 'photo',
      'photoName': photo.name,
      'width': width.clamp(100, 1600),
    });
    if (response?.statusCode != 200 ||
        !(response!.headers['content-type'] ?? '').startsWith('image/')) {
      return (bytes: null, expired: response?.statusCode == 410);
    }
    return (bytes: response.bodyBytes, expired: false);
  }

  Future<TravelStop> refreshStop(TravelStop stop) async {
    if (!stop.isGooglePlace || stop.placeId == null) return stop;
    final details = await fetchDetails(stop.placeId!);
    return details == null ? stop : stop.withGoogleDetails(details);
  }

  /// Resolve a local place only when both the name and location agree.
  /// Google data remains transient and is never written to the local catalog.
  Future<GooglePlaceDetails?> findDetailsForLocalStop(
    TravelStop stop, {
    required String state,
  }) async {
    if (stop.isGooglePlace ||
        stop.title.trim().isEmpty ||
        !stop.latitude.isFinite ||
        !stop.longitude.isFinite ||
        stop.latitude.abs() > 90 ||
        stop.longitude.abs() > 180 ||
        stop.latitude == 0 ||
        stop.longitude == 0) {
      return null;
    }
    final results = await searchPlannerPlaces(query: stop.title, state: state);
    final matches = <({String id, double distance})>[];
    for (final result in results) {
      final id = result['id'];
      final name = (result['displayName'] as Map?)?['text'];
      final location = result['location'] as Map?;
      final lat = location?['latitude'];
      final lng = location?['longitude'];
      if (id is! String ||
          name is! String ||
          lat is! num ||
          lng is! num ||
          !lat.isFinite ||
          !lng.isFinite ||
          !_samePlaceName(stop.title, name)) {
        continue;
      }
      final distance = const Distance().as(
        LengthUnit.Meter,
        LatLng(stop.latitude, stop.longitude),
        LatLng(lat.toDouble(), lng.toDouble()),
      );
      if (distance <= 2000) matches.add((id: id, distance: distance));
    }
    matches.sort((a, b) => a.distance.compareTo(b.distance));
    if (matches.isEmpty ||
        (matches.length > 1 &&
            matches[1].distance - matches[0].distance < 100)) {
      return null;
    }
    final details = await fetchDetails(matches.first.id);
    if (details == null ||
        details.name == null ||
        !_samePlaceName(stop.title, details.name!) ||
        details.latitude == null ||
        details.longitude == null ||
        !details.latitude!.isFinite ||
        !details.longitude!.isFinite ||
        details.latitude!.abs() > 90 ||
        details.longitude!.abs() > 180 ||
        const Distance().as(
              LengthUnit.Meter,
              LatLng(stop.latitude, stop.longitude),
              LatLng(details.latitude!, details.longitude!),
            ) >
            2000) {
      return null;
    }
    return details;
  }

  static bool _samePlaceName(String first, String second) {
    Set<String> words(String value) => value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .split(' ')
        .where((word) => word.isNotEmpty && word != 'state')
        .map((word) => word == 'masjid' ? 'mosque' : word)
        .toSet();
    final a = words(first), b = words(second);
    if (a.isEmpty || b.isEmpty) return false;
    return 2 * a.intersection(b).length / (a.length + b.length) >= 0.8;
  }

  // Kept for older callers: expiring Google photo URLs must never be persisted.
  @Deprecated('Use fetchDetails and fetchPhoto; do not store Google photo URLs')
  static String buildPhotoUrl(
    String photoName, {
    int maxWidthPx = 800,
    int maxHeightPx = 600,
  }) => '';

  /// Converts a Google Places API result item into a TravelStop
  static TravelStop convertGooglePlaceToStop({
    required Map<String, dynamic> place,
    required String timeRange,
    required String durationLabel,
    bool isMeal = false,
  }) {
    final displayName =
        (place['displayName'] as Map<String, dynamic>?)?['text'] as String? ??
        'Point of Interest';
    final address =
        place['formattedAddress'] as String? ?? 'Address unavailable';
    final primaryType =
        (place['primaryTypeDisplayName'] as Map<String, dynamic>?)?['text']
            as String? ??
        (isMeal ? 'Restaurant' : 'Attraction');
    final summary =
        (place['editorialSummary'] as Map<String, dynamic>?)?['text']
            as String? ??
        'Description unavailable';
    final rating = place['rating']?.toString();
    final reviewCount = place['userRatingCount']?.toString();

    final types = (place['types'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    IconData icon = Icons.place;
    Color color = AppColors.primary;

    if (isMeal ||
        types.any(
          (t) =>
              t.contains('restaurant') ||
              t.contains('food') ||
              t.contains('cafe'),
        )) {
      icon = Icons.restaurant;
      color = const Color(0xFFFF8A3D);
    } else if (types.any((t) => t.contains('museum') || t.contains('art'))) {
      icon = Icons.museum;
      color = const Color(0xFF0D9488);
    } else if (types.any(
      (t) =>
          t.contains('place_of_worship') ||
          t.contains('hindu') ||
          t.contains('mosque') ||
          t.contains('church'),
    )) {
      icon = Icons.temple_buddhist;
      color = const Color(0xFFDC2626);
    } else if (types.any(
      (t) => t.contains('park') || t.contains('nature') || t.contains('garden'),
    )) {
      icon = Icons.park;
      color = const Color(0xFF16A34A);
    } else if (types.any(
      (t) =>
          t.contains('shopping') || t.contains('store') || t.contains('market'),
    )) {
      icon = Icons.shopping_bag;
      color = const Color(0xFFD97706);
    } else if (types.any(
      (t) =>
          t.contains('tourist_attraction') || t.contains('historical_landmark'),
    )) {
      icon = Icons.location_city;
      color = const Color(0xFF2563EB);
    }

    final openingHours = place['regularOpeningHours'] as Map<String, dynamic>?;

    final hoursString =
        (openingHours?['weekdayDescriptions'] as List?)?.join('; ') ??
        'Hours unverified';

    final pId = place['id']?.toString() ?? place['place_id']?.toString();
    double lat = 0.0;
    double lng = 0.0;
    if (place['location'] is Map) {
      lat = (place['location']['latitude'] as num?)?.toDouble() ?? 0.0;
      lng = (place['location']['longitude'] as num?)?.toDouble() ?? 0.0;
    } else {
      lat = (place['latitude'] as num?)?.toDouble() ?? 0.0;
      lng = (place['longitude'] as num?)?.toDouble() ?? 0.0;
    }

    return TravelStop(
      operatingHours: openingHours ?? {},
      visitMinutes: isMeal ? 75 : 90,
      estimatedCost: SmartItineraryService.estimateVisitCost(
        isMeal ? 'Food' : primaryType,
      ),
      isIndoor:
          place['is_indoor'] as bool? ??
          PlaceClassifier.classify(category: primaryType, name: displayName),
      title: displayName,
      time: timeRange,
      note: '$primaryType • Google Maps',
      description: summary,
      duration: durationLabel,
      openingHours: hoursString,
      category: primaryType,
      dataSource: place['_data_source'] == 'local' ? 'local' : 'google',
      googleDetails: place['_data_source'] == 'local'
          ? null
          : GooglePlaceDetails.fromApi(place),
      tips: [
        rating == null ? 'Rating unavailable' : 'Rating: $rating',
        reviewCount == null
            ? 'Review count unavailable'
            : '$reviewCount reviews',
        address,
        'Powered by Google Maps Platform',
      ],
      icon: icon,
      color: color,
      placeId: pId,
      latitude: lat,
      longitude: lng,
    );
  }
}
