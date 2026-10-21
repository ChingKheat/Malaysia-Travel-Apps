import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';
import 'package:smart_travel_planner/features/itinerary/models/itinerary_models.dart';
import 'package:smart_travel_planner/features/places/models/google_place_details.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';
import 'package:smart_travel_planner/features/places/screens/place_detail_page.dart';
import 'package:smart_travel_planner/features/places/widgets/google_place_image.dart';

Map<String, dynamic> fixture() => {
  'id': 'ChIJ123',
  'displayName': {'text': 'Google museum'},
  'formattedAddress': 'Address from Google',
  'location': {'latitude': 3.15, 'longitude': 101.7},
  'rating': 4.2,
  'userRatingCount': 0,
  'editorialSummary': {'text': 'Summary from Google'},
  'primaryTypeDisplayName': {'text': 'Museum'},
  'regularOpeningHours': {
    'weekdayDescriptions': ['Monday: 10:00 AM – 6:00 PM'],
  },
  'nationalPhoneNumber': '03-1234 5678',
  'websiteUri': 'https://example.test',
  'googleMapsUri': 'https://maps.google.com/place',
  'photos': [
    {
      'name': 'places/ChIJ123/photos/old',
      'authorAttributions': [
        {
          'displayName': 'Original photographer',
          'uri': 'https://maps.google.com/author',
        },
      ],
    },
  ],
};
GooglePlacesService service(
  Future<http.Response> Function(http.Request) handler,
) => GooglePlacesService(
  client: MockClient(handler),
  accessToken: 'registered-user-token',
  endpoint: 'https://project.test/functions/v1/google-places',
);
TravelStop stop(Map<String, dynamic> data) =>
    GooglePlacesService.convertGooglePlaceToStop(
      place: data,
      timeRange: '09:00 AM - 10:30 AM',
      durationLabel: '90 min',
    );

void main() {
  test(
    'Preserves all supplied Google fields, including zero reviews',
    () async {
      final places = service((req) async {
        expect(req.url.host, 'project.test');
        expect(req.headers['authorization'], 'Bearer registered-user-token');
        expect(req.headers.containsKey('X-Goog-Api-Key'), false);
        expect(jsonDecode(req.body), {
          'operation': 'details',
          'placeId': 'ChIJ123',
        });
        return http.Response(
          jsonEncode(fixture()),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final details = (await places.fetchDetails('ChIJ123'))!;
      expect(details.name, 'Google museum');
      expect(details.address, 'Address from Google');
      expect(details.rating, 4.2);
      expect(details.reviewCount, 0);
      expect(details.phone, '03-1234 5678');
      expect(details.website, 'https://example.test');
      expect(details.description, 'Summary from Google');
      expect(details.hours, isNotEmpty);
      expect(
        details.photos.single.authors.single['displayName'],
        'Original photographer',
      );
    },
  );
  test('Missing fields stay unavailable rather than fabricated', () {
    final data = {'id': 'ChIJ123'};
    final result = stop(data);
    expect(result.tips, contains('Rating unavailable'));
    expect(result.tips, contains('Review count unavailable'));
    expect(result.tips, contains('Address unavailable'));
    expect(result.description, 'Description unavailable');
    expect(result.latitude, 0);
    expect(result.longitude, 0);
    expect(result.operatingHours, isEmpty);
    expect(result.googleDetails!.rating, isNull);
  });
  test(
    'Google persistence keeps the ID and own plan without Google content or photo references',
    () {
      final live = stop(
        fixture(),
      ).scheduled(600, 690, transit: 12, transportCost: 5);
      final snapshot = live.toJson();
      final text = jsonEncode(snapshot);
      for (final content in [
        'Google museum',
        'Address from Google',
        'Summary from Google',
        'places/ChIJ123/photos/old',
        'Original photographer',
        '101.7',
      ]) {
        expect(text, isNot(contains(content)));
      }
      expect(snapshot['place_id'], 'ChIJ123');
      final restored = TravelStop.fromJson(snapshot);
      expect(restored.isGooglePlace, true);
      expect(restored.googleDetails, isNull);
      expect(restored.time, live.time);
      expect(restored.travelMinutes, 12);
      expect(restored.travelCost, 5);
      expect(restored.estimatedCost, live.estimatedCost);
      final refreshed = restored.withGoogleDetails(
        GooglePlaceDetails.fromApi(fixture()),
      );
      expect(refreshed.title, 'Google museum');
      expect(refreshed.time, live.time);
      expect(refreshed.travelCost, 5);
      expect(refreshed.latitude, 3.15);
    },
  );
  test(
    'Legacy Google snapshots and joined database rows do not load expired key-bearing photos',
    () {
      final legacy = TravelStop.fromJson({
        'place_id': 'ChIJ123',
        'title': 'Old name',
        'photo_urls': [
          'https://places.googleapis.com/v1/photos/old/media?key=old-key',
        ],
        'time': '09:00 AM - 10:00 AM',
        'latitude': 3.1,
        'longitude': 101.7,
      });
      expect(legacy.title, 'Saved Google place');
      expect(legacy.primaryPhotoUrl, isNull);
      expect(legacy.latitude, 0);
      final row = ItineraryStop.fromSupabase({
        'place_id': 'ChIJ123',
        'places': {
          'name': 'Old name',
          'photo_url': 'https://places.googleapis.com/media?key=old-key',
        },
      }).toTravelStop();
      expect(row.isGooglePlace, true);
      expect(row.primaryPhotoUrl, isNull);
    },
  );
  test(
    'Offline, malformed and unauthorized responses have safe fallbacks',
    () async {
      for (final response in [
        http.Response('invalid', 200),
        http.Response('{"error":"Sign in again"}', 401),
        http.Response('{}', 503),
      ]) {
        final places = service((_) async => response);
        expect(await places.fetchDetails('ChIJ123'), isNull);
        expect(await places.fetchPlacesByText(query: 'KL'), isEmpty);
        expect(places.lastError, isNotNull);
      }
      final offline = service(
        (_) async => throw http.ClientException('offline'),
      );
      expect(await offline.refreshStop(stop(fixture())), isA<TravelStop>());
      expect(offline.lastError, contains('saved schedule'));
    },
  );
  test(
    'Text search rejects missing or unusable locations and never caches completed requests',
    () async {
      var count = 0;
      final places = service((_) async {
        count++;
        return http.Response(
          jsonEncode({
            'places': [
              fixture(),
              {'id': 'no-location'},
              {
                'id': 'invalid-location',
                'location': {'latitude': 0, 'longitude': 0},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final result = await places.fetchPlacesByText(
        query: 'Museums in Kuala Lumpur',
      );
      expect(result.single['id'], 'ChIJ123');
      await places.fetchPlacesByText(query: 'Museums in Kuala Lumpur');
      expect(count, 2);
    },
  );
  test('Wrong detail ID and invalid place ID are rejected', () async {
    var count = 0;
    final places = service((_) async {
      count++;
      return http.Response('{"id":"other"}', 200);
    });
    expect(await places.fetchDetails('../secret'), isNull);
    expect(count, 0);
    expect(await places.fetchDetails('ChIJ123'), isNull);
    expect(count, 1);
  });
  testWidgets(
    'Place details use API fields while preserving the user schedule',
    (tester) async {
      final places = service((_) async {
        final data = fixture()..remove('photos');
        return http.Response(
          jsonEncode(data),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: PlaceDetailPage(
            stop: TravelStop.fromJson({
              'place_id': 'ChIJ123',
              'time': '09:00 AM - 10:30 AM',
              'duration': '90 min',
            }),
            placesService: places,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Address from Google'), findsOneWidget);
      expect(find.text('Rating unavailable'), findsNothing);
      expect(find.text('09:00 AM - 10:30 AM'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('4.2'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    },
  );
  testWidgets(
    'Expired photo refreshes once and shows the new photograph attribution',
    (tester) async {
      final operations = <String>[];
      final places = service((request) async {
        final body = jsonDecode(request.body) as Map;
        operations.add(body['operation'] as String);
        if (body['operation'] == 'details') {
          final data = fixture();
          data['photos'] = [
            {
              'name': 'places/ChIJ123/photos/fresh',
              'authorAttributions': [
                {'displayName': 'New photographer'},
              ],
            },
          ];
          return http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (body['photoName'] == 'places/ChIJ123/photos/old') {
          return http.Response('{}', 410);
        }
        // A real 1x1 PNG; image bytes are never stored in the itinerary.
        return http.Response.bytes(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4AWP4DwQACfsD/fteaysAAAAASUVORK5CYII=',
          ),
          200,
          headers: {'content-type': 'image/png'},
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GooglePlaceImage(
              placeId: 'ChIJ123',
              photo: GooglePlaceDetails.fromApi(fixture()).photos.single,
              service: places,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(operations, ['photo', 'details', 'photo']);
      expect(find.text('Photo: New photographer'), findsOneWidget);
      expect(find.text('Photo: Original photographer'), findsNothing);
    },
  );
}
