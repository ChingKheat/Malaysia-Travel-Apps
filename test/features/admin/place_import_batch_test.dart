import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_travel_planner/features/admin/models/place_import_batch.dart';
import 'package:smart_travel_planner/features/admin/services/admin_places_repository.dart';

Map<String, dynamic> discovery(String id, {String state = 'Penang'}) => {
  'id': id,
  'displayName': {'text': 'Real place'},
  'location': {'latitude': 5.4, 'longitude': 100.3},
  'addressComponents': [
    {
      'types': ['country'],
      'shortText': 'MY',
    },
    {
      'types': ['administrative_area_level_1'],
      'longText': state,
    },
  ],
};
void main() {
  test(
    'duplicates conflict deterministically and cross-state results are rejected',
    () {
      final batch = PlaceImportBatch('Penang');
      batch.add(discovery('same'), 'Culture');
      batch.add(discovery('same'), 'Food');
      batch.add(discovery('same'), 'Culture');
      batch.add(discovery('other', state: 'Johor'), 'Nature');
      batch.add({
        ...discovery('bad'),
        'location': {'latitude': 0, 'longitude': 0},
      }, 'Nature');
      expect(batch.returned, 5);
      expect(batch.stateAccepted, 4);
      expect(batch.wrongState, 1);
      expect(batch.invalid, 1);
      expect(batch.rows.length, 1);
      expect(batch.rows['same']!['app_category'], 'Attraction');
      expect(batch.conflicts, 1);
    },
  );
  test('partial write failure reports committed progress and stops', () async {
    int calls = 0;
    final client = SupabaseClient(
      'https://test.example',
      'test-key',
      httpClient: MockClient((req) async {
        calls++;
        if (calls == 2) {
          return http.Response(
            '{"message":"unavailable","code":"503"}',
            503,
            request: req,
          );
        }
        return http.Response(
          jsonEncode(
            (jsonDecode(req.body) as List)
                .map((r) => {'place_id': r['place_id']})
                .toList(),
          ),
          201,
          request: req,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final rows = List.generate(
      45,
      (i) => <String, dynamic>{
        'place_id': 'id-$i',
        'name': 'Name',
        'latitude': 5.4,
        'longitude': 100.3,
      },
    );
    await expectLater(
      AdminPlacesRepository(client: client).savePlaces('Penang', rows),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'progress',
          contains('40 inserts confirmed; 5 records unconfirmed'),
        ),
      ),
    );
    expect(calls, 2);
  });
  test(
    'review writes only application fields and reports a concurrent edit',
    () async {
      final client = SupabaseClient(
        'https://test.example',
        'test-key',
        httpClient: MockClient((req) async {
          expect(req.method, 'PATCH');
          expect(req.url.path, '/rest/v1/places');
          expect(jsonDecode(req.body), {
            'category': 'Nature',
            'is_indoor': false,
          });
          expect(req.url.queryParameters['category'], 'eq.Attraction');
          expect(req.url.queryParameters['is_indoor'], 'is.null');
          return http.Response(
            '[]',
            200,
            request: req,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await expectLater(
        AdminPlacesRepository(client: client).saveReview(
          {
            'place_id': 'ChITest123',
            'state': 'Penang',
            'category': 'Attraction',
            'is_indoor': null,
          },
          'Nature',
          false,
        ),
        throwsStateError,
      );
    },
  );
}
