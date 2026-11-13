import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';

void main() {
  test('Retries transient errors with the same pagination token', () async {
    var calls = 0;
    final service = GooglePlacesService(
      accessToken: 'test',
      client: MockClient((r) async {
        expect(jsonDecode(r.body)['pageToken'], 'next');
        calls++;
        return calls < 3
            ? http.Response('{"error":"Failed","upstreamStatus":503}', 502)
            : http.Response('{"places":[]}', 200);
      }),
    );
    expect(
      await service.searchPageWithRetry(
        query: 'parks',
        state: 'Penang',
        pageToken: 'next',
        retryDelay: Duration.zero,
      ),
      isNotNull,
    );
    expect(calls, 3);
  });

  for (final status in [400, 401, 403, 429, 503]) {
    test('Status $status has bounded retry behavior', () async {
      var calls = 0;
      final service = GooglePlacesService(
        accessToken: 'test',
        client: MockClient((r) async {
          calls++;
          return http.Response('{"error":"Failed"}', status);
        }),
      );
      expect(
        await service.searchPageWithRetry(
          query: 'parks',
          state: 'Penang',
          retryDelay: Duration.zero,
        ),
        isNull,
      );
      expect(calls, status == 503 ? 3 : 1);
    });
  }

  test('Cancellation prevents the next attempt', () async {
    var calls = 0;
    final service = GooglePlacesService(
      accessToken: 'test',
      client: MockClient((r) async {
        calls++;
        throw http.ClientException('offline');
      }),
    );
    await service.searchPageWithRetry(
      query: 'parks',
      state: 'Penang',
      retryDelay: Duration.zero,
      shouldContinue: () => calls == 0,
    );
    expect(calls, 1);
  });
}
