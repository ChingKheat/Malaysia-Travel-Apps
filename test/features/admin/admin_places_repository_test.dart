import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_travel_planner/features/admin/services/admin_places_repository.dart';

Map<String, dynamic> place(String id) => {
  'place_id': id,
  'name': 'Actual place $id',
  'latitude': 3.1,
  'longitude': 101.5,
  'category': 'Park',
  'rating': 4.2,
  'user_ratings_total': 17,
  'operating_hours': {
    'weekdayDescriptions': ['Monday: 9 am–5 pm'],
  },
};

void main() {
  test(
    'State comes from Google administrative address, not the search query',
    () {
      Map<String, dynamic> address(String state, {String country = 'MY'}) => {
        'addressComponents': [
          {
            'types': ['country'],
            'shortText': country,
          },
          {
            'types': ['administrative_area_level_1'],
            'longText': state,
          },
        ],
      };
      expect(
        AdminPlacesRepository.googleState(address('Selangor')),
        'Selangor',
      );
      expect(
        AdminPlacesRepository.googleState(
          address('Wilayah Persekutuan Kuala Lumpur'),
        ),
        'Kuala Lumpur',
      );
      expect(
        AdminPlacesRepository.googleState(address('Pulau Pinang')),
        'Penang',
      );
      expect(
        AdminPlacesRepository.googleState(address('Selangor', country: 'US')),
        isNull,
      );
      expect(AdminPlacesRepository.googleState({}), isNull);
      expect(
        AdminPlacesRepository.googleState(address("Johor Darul Ta'zim")),
        'Johor',
      );
      expect(
        AdminPlacesRepository.googleState(address('Wilayah Persekutuan')),
        isNull,
      );
    },
  );
  test('Incomplete data is rejected and absent ratings remain null', () {
    for (final invalid in [
      {...place('id'), 'name': 'Saved Google place'},
      {...place('id'), 'latitude': 0, 'longitude': 0},
      {...place('id'), 'latitude': double.nan},
    ]) {
      expect(
        () => AdminPlacesRepository.importRow('Selangor', invalid),
        throwsFormatException,
      );
    }
    final row = AdminPlacesRepository.importRow('Selangor', {
      ...place('id'),
      'rating': null,
      'user_ratings_total': null,
        'photo_url': 'https://places.googleapis.com/photo?key=never-store-this',
    });
    expect(row['rating'], isNull);
    expect(row['user_ratings_total'], isNull);
      expect(row['photo_url'], isNull);
  });
  test(
    'Database count uses the full server total rather than the displayed page size',
    () async {
      final client = SupabaseClient(
        'https://database.test',
        'public-test-key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/rest/v1/places');
          expect(request.url.queryParameters['state'], 'eq.Selangor');
          expect(request.url.queryParameters['limit'], '500');
          expect(request.headers['prefer'], contains('count=exact'));
          return http.Response(
            jsonEncode([
              {'place_id': 'first'},
              {'place_id': 'second'},
            ]),
            206,
            request: request,
            headers: {
              'content-type': 'application/json',
              'content-range': '0-1/509',
            },
          );
        }),
      );
      addTearDown(client.dispose);
      final page = await AdminPlacesRepository(client: client).load('Selangor');
      expect(page.rows.length, 2);
      expect(page.totalCount, 509);
    },
  );
  test(
    'Import counts only inserted rows and preserves existing IDs across states',
    () async {
      var requests = 0;
      final client = SupabaseClient(
        'https://database.test',
        'public-test-key',
        httpClient: MockClient((request) async {
          requests++;
          expect(request.method, 'POST');
          expect(
            request.headers['prefer'],
            contains('resolution=ignore-duplicates'),
          );
          expect(request.url.queryParameters['select'], 'place_id');
          final rows = jsonDecode(request.body) as List;
          expect(rows.length, requests == 1 ? 40 : 5);
          expect(rows.every((row) => row['state'] == 'Selangor'), true);
          expect(rows.first['name'], startsWith('Actual place'));
          expect(rows.first['latitude'], 3.1);
          expect(rows.first['longitude'], 101.5);
          expect(rows.first['rating'], 4.2);
          expect(rows.first['user_ratings_total'], 17);
          expect(
            rows.first['operating_hours']['weekdayDescriptions'],
            isNotEmpty,
          );
          // Existing IDs are ignored; API search results are not all new inserts.
          return http.Response(
            jsonEncode(
              rows
                  .take(requests == 1 ? 3 : 1)
                  .map((row) => {'place_id': row['place_id']})
                  .toList(),
            ),
            201,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final added = await AdminPlacesRepository(client: client).savePlaces(
        'Selangor',
        [...List.generate(45, (i) => place('place-$i')), place('place-0')],
      );
      expect(added, 4);
      expect(requests, 2);
    },
  );
  test(
    'Database failure is surfaced rather than returned as an empty state',
    () async {
      final client = SupabaseClient(
        'https://database.test',
        'public-test-key',
        httpClient: MockClient(
          (request) async => http.Response(
            '{"message":"database unavailable","code":"XX000"}',
            503,
            request: request,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(client.dispose);
      final repository = AdminPlacesRepository(client: client);
      await expectLater(
        repository.load('Johor'),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        repository.savePlaces('Johor', [place('new-place')]),
        throwsA(isA<PostgrestException>()),
      );
    },
  );
}
