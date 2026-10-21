import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
    final token = _token;
    if (token == null) {
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
      if (response.statusCode != 200) {
        lastError = 'Place service unavailable (${response.statusCode}).';
        try {
          lastError =
              (jsonDecode(response.body) as Map)['error']?.toString() ??
              lastError;
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
  }) async {
    final rows = await _catalog.load(state: destinationState);
    final matches = rows
        .where((row) => PlaceCatalogService.isMeal(row) == isMeal)
        .toList();
    matches.sort(
      (a, b) =>
          ((b['rating'] as num?) ?? 0).compareTo((a['rating'] as num?) ?? 0),
    );
    return matches
        .take(maxResults)
        .map(PlaceCatalogService.asGoogleShape)
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchPlacesByText({
    required String query,
    int maxResults = 10,
  }) async {
    final key = '$_endpoint|${_token ?? ''}|$query|$maxResults';
    final existing = _inFlight[key];
    if (existing != null) return existing;
    final pending = _search(query, maxResults);
    _inFlight[key] = pending;
    try {
      return await pending;
    } finally {
      if (identical(_inFlight[key], pending)) _inFlight.remove(key);
    }
  }

  Future<List<Map<String, dynamic>>> _search(
    String query,
    int maxResults,
  ) async {
    final data = await searchPage(query: query, pageSize: maxResults);
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

  Future<Map<String, dynamic>?> searchPage({
    required String query,
    int pageSize = 20,
    String? pageToken,
  }) async {
    final response = await _request({
      'operation': 'search',
      'query': query,
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

  Future<GooglePlaceDetails?> fetchDetails(String placeId) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{5,255}$').hasMatch(placeId)) return null;
    final response = await _request({
      'operation': 'details',
      'placeId': placeId,
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
      dataSource: 'google',
      googleDetails: GooglePlaceDetails.fromApi(place),
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
