import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_travel_planner/features/places/services/places_service.dart';
import 'package:smart_travel_planner/features/places/services/place_catalog_service.dart';
import 'package:smart_travel_planner/features/places/services/verified_catalog_service.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';

Map<String, dynamic> record(String id, {double latitude = 3.14}) => {
  'place_id': id,
  'name': 'Test $id',
  'state': 'Kuala Lumpur',
  'category': 'Museum',
  'latitude': latitude,
  'longitude': 101.69,
  'data_source': 'independent',
  'catalog_status': 'published',
  'catalog_source_url': 'https://example.test/source',
  'catalog_license': 'Test fixture license',
  'catalog_verified_at': '2026-11-18T00:00:00Z',
};

class Catalog extends PlaceCatalogService {
  Catalog(this.rows);
  final List<Map<String, dynamic>> rows;
  @override
  Future<List<Map<String, dynamic>>> load({String? state}) async => rows;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'missing cloud migration is a setup error, not an offline error',
    () async {
      final db = SupabaseClient(
        'https://db.test',
        'public',
        httpClient: MockClient(
          (req) async => http.Response(
            jsonEncode({
              'code': '42703',
              'message': 'column places.catalog_status does not exist',
            }),
            400,
            request: req,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(db.dispose);
      final page = await PlacesService(
        catalog: VerifiedCatalogService(client: db),
      ).fetchPage(latitude: 3.14, longitude: 101.69);
      expect(page.failure, PlacesFailure.service);
      expect(page.notice, contains('setup is incomplete'));
      expect(page.items, isEmpty);
    },
  );
  test(
    'browse, revisit, search and pagination make zero Google requests',
    () async {
      var requests = 0;
      final google = GooglePlacesService(
        accessToken: 'test',
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 429);
        }),
      );
      final rows = [
        record('a'),
        record('b'),
        record('far', latitude: 5),
        {...record('reference'), 'data_source': 'google'},
        {...record('unverified'), 'catalog_verified_at': null},
        record('a'),
      ];
      final service = PlacesService(catalog: Catalog(rows), google: google);
      for (var i = 0; i < 2; i++) {
        final first = await service.fetchPage(
          latitude: 3.14,
          longitude: 101.69,
          limit: 1,
        );
        expect(first.items.single.xid, 'a');
        expect(first.hasMore, true);
        final second = await service.fetchPage(
          latitude: 3.14,
          longitude: 101.69,
          offset: first.nextOffset,
          limit: 1,
        );
        expect(second.items.single.xid, 'b');
        expect(second.hasMore, false);
        expect(first.items.single.rating, isNull);
      }
      expect(
        (await service.fetchPage(
          latitude: 3.14,
          longitude: 101.69,
          query: 'b',
          category: 'Sights',
        )).items.single.xid,
        'b',
      );
      expect(
        (await service.fetchPage(
          latitude: 3.14,
          longitude: 101.69,
          category: 'Food',
        )).items,
        isEmpty,
      );
      expect(requests, 0);
    },
  );

  test(
    'published catalog is server-filtered and survives service recreation offline',
    () async {
      var offline = false;
      final db = SupabaseClient(
        'https://db.test',
        'public',
        httpClient: MockClient((req) async {
          if (offline) throw Exception('network unavailable');
          expect(req.url.queryParameters['catalog_status'], 'eq.published');
          expect(req.url.queryParameters['state'], 'eq.Kuala Lumpur');
          return http.Response(
            jsonEncode([record('a')]),
            200,
            request: req,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(db.dispose);
      final initial = VerifiedCatalogService(client: db);
      expect(
        await initial.load(state: 'Kuala Lumpur'),
        hasLength(1),
        reason: initial.loadError,
      );
      offline = true;
      final recreated = VerifiedCatalogService(client: db);
      expect(await recreated.load(state: 'Kuala Lumpur'), hasLength(1));
      expect(recreated.lastLoadOffline, true);
      expect(recreated.savedAt, isNotNull);
      expect(await recreated.load(state: 'Penang'), isEmpty);
    },
  );

  test(
    'only concurrent identical details are coalesced; profiles stay separate',
    () async {
      var calls = 0;
      final profiles = <String>[];
      final google = GooglePlacesService(
        accessToken: 'test',
        endpoint: 'https://test/details',
        client: MockClient((req) async {
          calls++;
          profiles.add(jsonDecode(req.body)['profile'] as String);
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return http.Response(jsonEncode({'id': 'ChITest123'}), 200);
        }),
      );
      await Future.wait([
        google.fetchDetails('ChITest123'),
        google.fetchDetails('ChITest123'),
        google.fetchDetails('ChITest123', basic: true),
      ]);
      expect(calls, 2);
      expect(profiles.toSet(), {'basic', 'full'});
      await google.fetchDetails('ChITest123');
      expect(calls, 3); // No permanent Google response cache.
    },
  );
}
