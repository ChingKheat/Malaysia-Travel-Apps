import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_travel_planner/core/config/supabase_config.dart';
import 'package:smart_travel_planner/features/admin/services/admin_places_repository.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';
import 'package:smart_travel_planner/features/places/services/place_catalog_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/local_itinerary_store.dart';
import 'package:smart_travel_planner/shared/data/malaysia_states.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';

Map<String, dynamic> reference(int i) => {
  'place_id': 'ChIJtest$i',
  'state': 'Penang',
  'data_source': 'google',
  'name': 'Saved Google place',
  'category': 'Attraction',
  'latitude': 0,
  'longitude': 0,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Leaving a page cancels additional detail batches', () async {
    var active = true;
    var requests = 0;
    final service = GooglePlacesService(
      accessToken: 'test',
      client: MockClient((request) async {
        requests++;
        active = false;
        final body = jsonDecode(request.body) as Map;
        return http.Response(jsonEncode({'id': body['placeId']}), 200);
      }),
    );
    await service.hydrateRows(
      List.generate(20, reference),
      shouldContinue: () => active,
    );
    expect(requests, 4);
  });

  test(
    'Legacy Google cache becomes references and remains readable offline',
    () async {
      final key = 'place_catalog_v1:${SupabaseConfig.supabaseUrl}:Penang';
      SharedPreferences.setMockInitialValues({
        key: jsonEncode([
          {
            ...reference(0),
            'name': 'Provider name',
            'rating': 4.9,
            'latitude': 5.4,
            'longitude': 100.3,
            'operating_hours': {
              'weekdayDescriptions': ['Provider hours'],
            },
            'photo_url': 'https://places.googleapis.com/private-reference',
          },
        ]),
      });
      final rows = await PlaceCatalogService().load(state: 'Penang');
      expect(rows.single['place_id'], 'ChIJtest0');
      expect(rows.single['latitude'], 0);
      expect(rows.single['name'], 'Saved Google place');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(key), false);
      final stored = prefs.getString(key.replaceFirst('v1:', 'v2:'))!;
      expect(stored, isNot(contains('Provider')));
      expect(stored, isNot(contains('places.googleapis.com')));
    },
  );

  test(
    'A displayed page hydrates at most 20 IDs with basic details and never searches',
    () async {
      final operations = <Map>[];
      final service = GooglePlacesService(
        accessToken: 'test',
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          operations.add(body);
          return http.Response(
            jsonEncode({
              'id': body['placeId'],
              'displayName': {'text': 'Live provider name'},
              'location': {'latitude': 5.4, 'longitude': 100.3},
            }),
            200,
          );
        }),
      );
      final rows = await service.hydrateRows(List.generate(70, reference));
      expect(rows.length, 20);
      expect(operations.length, 20);
      expect(
        operations.every(
          (o) => o['operation'] == 'details' && o['profile'] == 'basic',
        ),
        true,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    },
  );

  test(
    'Planning hydrates at most 32 with full details, never search',
    () async {
      var requests = 0;
      final service = GooglePlacesService(
        accessToken: 'test',
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          expect(body['operation'], 'details');
          expect(body['profile'], 'full');
          requests++;
          return http.Response(jsonEncode({'id': body['placeId']}), 200);
        }),
      );
      expect(
        (await service.hydrateRows(
          List.generate(90, reference),
          full: true,
          limit: 100,
        )).length,
        32,
      );
      expect(requests, 32);
    },
  );

  test(
    'Unverified allowance preserves reference placeholders and stops failed batches',
    () async {
      var requests = 0;
      final service = GooglePlacesService(
        accessToken: 'test',
        client: MockClient((request) async {
          requests++;
          return http.Response('{"error":"Allowance unverified"}', 429);
        }),
      );
      final rows = await service.hydrateRows(List.generate(20, reference));
      expect(rows.length, 20);
      expect(requests, 4);
      expect(
        rows.every(
          (r) => r['name'] == 'Saved Google place' && r['_live'] != true,
        ),
        true,
      );
    },
  );

  test('Admin pagination can reach saved records beyond 500', () async {
    final db = SupabaseClient(
      'https://db.test',
      'public',
      httpClient: MockClient((request) async {
        expect(request.url.queryParameters['offset'], '500');
        expect(request.url.queryParameters['limit'], '20');
        return http.Response(
          jsonEncode([reference(500)]),
          206,
          request: request,
          headers: {
            'content-type': 'application/json',
            'content-range': '500-500/540',
          },
        );
      }),
    );
    addTearDown(db.dispose);
    final page = await AdminPlacesRepository(
      client: db,
    ).load('Penang', offset: 500);
    expect(page.rows.single['place_id'], 'ChIJtest500');
    expect(page.totalCount, 540);
  });

  test(
    'Every supported area accepts a Malaysian address, including federal territories',
    () {
      expect(AdminPlacesRepository.supportedStates.length, 16);
      expect(
        malaysiaStates.toSet(),
        AdminPlacesRepository.supportedStates.toSet(),
      );
      for (final state in AdminPlacesRepository.supportedStates) {
        expect(
          AdminPlacesRepository.googleState({
            'addressComponents': [
              {
                'types': ['country'],
                'shortText': 'MY',
              },
              {
                'types': ['administrative_area_level_1'],
                'longText':
                    ['Labuan', 'Putrajaya', 'Kuala Lumpur'].contains(state)
                    ? 'Federal Territory of $state'
                    : state,
              },
            ],
          }),
          state,
        );
      }
    },
  );
  test(
    'Explore retains raw Google IDs and distinguishes app-owned records',
    () {
      final google = Attraction.fromGooglePlaceJson(
        {'id': 'opaque_google_id'},
        centerLat: 5.4,
        centerLon: 100.3,
      );
      expect(google.googlePlaceId, 'opaque_google_id');
      final own = Attraction.fromGooglePlaceJson(
        {'id': 'poi_local', '_data_source': 'local'},
        centerLat: 5.4,
        centerLon: 100.3,
      );
      expect(own.googlePlaceId, isNull);
    },
  );
  test(
    'Opaque Google IDs sanitize the outer journal record using its source marker',
    () async {
      final store = LocalItineraryStore();
      await store.write('opaque-user', {
        'stop': {
          'place_id': 'opaque_google_id',
          'place_name': 'Provider name',
          'arrival_time': '11:00',
          'snapshot': {
            'place_id': 'opaque_google_id',
            'data_source': 'google',
            'title': 'Provider name',
          },
        },
      });
      final result = await store.read('opaque-user');
      expect(result['stop']['place_name'], 'Saved Google place');
      expect(result['stop']['place_id'], 'opaque_google_id');
      expect(result['stop']['arrival_time'], '11:00');
    },
  );

  test(
    'Legacy itinerary journals discard provider data and preserve saved timing',
    () async {
      SharedPreferences.setMockInitialValues({
        'itinerary_journal_v1_user': jsonEncode({
          'trip': {
            'place_id': 'ChIJtest0',
            'place_name': 'Provider museum',
            'latitude': 5.4,
            'longitude': 100.3,
            'arrival_time': '09:00',
            'departure_time': '10:30',
            'is_visited': true,
            'snapshot': {
              'place_id': 'ChIJtest0',
              'title': 'Provider museum',
              'time': '09:00 - 10:30',
              'photo_urls': ['https://places.googleapis.com/photo'],
            },
          },
        }),
      });
      final result = await LocalItineraryStore().read('user');
      expect(result['trip']['arrival_time'], '09:00');
      expect(result['trip']['is_visited'], true);
      expect(result['trip']['snapshot']['time'], '09:00 - 10:30');
      final stored = (await SharedPreferences.getInstance()).getString(
        'itinerary_journal_v1_user',
      )!;
      expect(stored, isNot(contains('Provider museum')));
      expect(stored, isNot(contains('places.googleapis.com')));
    },
  );
}
