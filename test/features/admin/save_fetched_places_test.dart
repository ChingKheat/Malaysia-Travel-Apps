import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_travel_planner/features/admin/services/admin_places_repository.dart';

void main() {
  test(
    'Refresh saves real fields, tolerates float serialization and preserves reviewed fields',
    () async {
      var writes = 0;
      final client = SupabaseClient(
        'https://database.test',
        'public-key',
        httpClient: MockClient((request) async {
          writes++;
          expect(request.method, 'PATCH');
          final body = jsonDecode(request.body) as Map;
          expect(body['name'], 'Forest');
          expect(body.containsKey('category'), false);
          expect(body.containsKey('is_indoor'), false);
          expect(body.containsKey('rating'), false);
          expect(body.containsKey('operating_hours'), false);
          return http.Response(
            jsonEncode([
              {
                'place_id': 'ChITest',
                'name': 'Forest',
                'latitude': 2.3,
                'longitude': 102.44379,
              },
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final row = <String, dynamic>{
        'place_id': 'ChITest',
        '_live': true,
      '_fullDetails': false,
      'operating_hours': <String, dynamic>{},
        'name': 'Forest',
        'latitude': 2.3,
        'longitude': 102.44379000000001,
        '_addressComponents': [
          {
            'types': ['country'],
            'shortText': 'MY',
          },
          {
            'types': ['administrative_area_level_1'],
            'longText': 'Melaka',
          },
        ],
      };
      final repo = AdminPlacesRepository(client: client);
      expect(await repo.saveFetchedRows('Melaka', [row]), 1);
      expect(await repo.saveFetchedRows('Penang', [row]), 0);
      expect(writes, 1);
    },
  );
}
