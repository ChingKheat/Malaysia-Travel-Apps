import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_travel_planner/features/places/services/place_catalog_service.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';
import 'package:smart_travel_planner/shared/services/google_route_service.dart';
import 'package:smart_travel_planner/core/config/api_keys.dart';

Map<String, dynamic> row(String id, String category) => {
  'place_id': id,
  'name': 'Real $id',
  'state': 'Selangor',
  'category': category,
  'latitude': 3.1,
  'longitude': 101.5,
  'rating': null,
  'user_ratings_total': 0,
  'operating_hours': {'periods': []},
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Catalog pagination keeps places beyond the first thousand rows',
    () async {
      var calls = 0;
      final db = SupabaseClient(
        'https://db.test',
        'public',
        httpClient: MockClient((request) async {
          calls++;
          final offset = int.parse(
            request.url.queryParameters['offset'] ?? '0',
          );
          final rows = offset == 0
              ? List.generate(1000, (i) => row('place-$i', 'Museum'))
              : [row('last-place', 'Museum')];
          return http.Response(
            jsonEncode(rows),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(db.dispose);
      expect((await PlaceCatalogService(client: db).load()).length, 1001);
      expect(calls, 2);
    },
  );
  test(
    'Catalog supports offline reopen, filters states, and excludes photo URLs',
    () async {
      final db = SupabaseClient(
        'https://db.test',
        'public',
        httpClient: MockClient((request) async {
          expect(request.url.host, 'db.test');
          expect(
            request.url.queryParameters['select'],
            isNot(contains('photo_url')),
          );
          return http.Response(
            jsonEncode([row('museum', 'Museum'), row('food', 'Restaurant')]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(db.dispose);
      expect((await PlaceCatalogService(client: db).load()).length, 2);
      final offline = SupabaseClient(
        'https://db.test',
        'public',
        httpClient: MockClient(
          (request) async => http.Response(
            '{"message":"expired"}',
            401,
            request: request,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(offline.dispose);
      expect(
        (await PlaceCatalogService(
          client: offline,
        ).load(state: 'Selangor')).length,
        2,
      );
      expect(
        await PlaceCatalogService(client: offline).load(state: 'Johor'),
        isEmpty,
      );
    },
  );
  test(
    'Planning uses stored data, preserves missing ratings, and makes no Google request',
    () async {
      final catalog = _Catalog([
        row('museum', 'Museum'),
        row('food', 'Restaurant'),
      ]);
      final service = GooglePlacesService(
        catalog: catalog,
        client: MockClient(
          (_) async => throw StateError('Google must not be called'),
        ),
      );
      final attractions = await service.fetchPlacesWithDatabaseCache(
        destinationState: 'Selangor',
        query: 'any',
      );
      final meals = await service.fetchPlacesWithDatabaseCache(
        destinationState: 'Selangor',
        query: 'any',
        isMeal: true,
      );
      expect(attractions.single['id'], 'museum');
      expect(meals.single['id'], 'food');
      expect(attractions.single['rating'], isNull);
      expect(attractions.single['userRatingCount'], 0);
    },
  );
  test(
    'Unauthorized server response never triggers a direct Google fallback',
    () async {
      ApiKeys.googleMaps = 'client-key-must-not-be-used';
      addTearDown(() => ApiKeys.googleMaps = '');
      var requests = 0;
      final service = GooglePlacesService(
        accessToken: 'test',
        client: MockClient((request) async {
          requests++;
          expect(request.url.host, 'yavslytukzgphvaqspcq.supabase.co');
          return http.Response('{"error":"Sign in again"}', 401);
        }),
      );
      expect(await service.fetchDetails('ChIJ123'), isNull);
      expect(requests, 1);
    },
  );
  test('Google route polyline decoding is validated', () {
    final points = GoogleRouteService.decodePolyline(
      '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
    );
    expect(points.length, 3);
    expect(points.first.latitude, closeTo(38.5, 0.00001));
    expect(points.last.longitude, closeTo(-126.453, 0.00001));
    expect(() => GoogleRouteService.decodePolyline('_'), throwsFormatException);
  });
}

class _Catalog extends PlaceCatalogService {
  _Catalog(this.rows);
  final List<Map<String, dynamic>> rows;
  @override
  Future<List<Map<String, dynamic>>> load({String? state}) async => rows;
}
