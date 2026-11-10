import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/places/models/google_place_details.dart';
import 'package:smart_travel_planner/features/places/screens/attraction_detail_page.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';
import 'package:smart_travel_planner/features/places/services/place_catalog_service.dart';
import 'package:smart_travel_planner/features/places/services/places_service.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';

class EmptyCatalog extends PlaceCatalogService {
  @override
  Future<List<Map<String, dynamic>>> load({String? state}) async => [];
}

class FakeGoogle extends GooglePlacesService {
  bool searched = false;
  bool failDetails = false;
  @override
  Future<List<Map<String, dynamic>>> fetchPlacesByText({
    required String query,
    required String state,
    int maxResults = 10,
  }) async {
    searched = true;
    return [
      {
        'id': 'ChITest123',
        'displayName': {'text': 'Test place'},
        'location': {'latitude': 3.14, 'longitude': 101.69},
      },
    ];
  }

  @override
  Future<GooglePlaceDetails?> fetchDetails(
    String placeId, {
    bool basic = false,
  }) async => failDetails
      ? null
      : GooglePlaceDetails(placeId, {
          'formattedAddress': 'Test address',
          'editorialSummary': {'text': 'Test description'},
          'regularOpeningHours': {
            'weekdayDescriptions': ['Monday: 9 AM – 5 PM'],
          },
        });
}

void main() {
  test(
    'an empty catalog never calls admin search and labels local fallback',
    () async {
      final google = FakeGoogle();
      final service = PlacesService(catalog: EmptyCatalog(), google: google);
      final page = await service.fetchPage(
        latitude: 3.139,
        longitude: 101.6869,
      );
      expect(google.searched, isFalse);
      expect(page.failure, PlacesFailure.emptyCatalog);
      expect(page.source, 'Local offline guide');
      expect(page.hasMore, isFalse);
    },
  );

  testWidgets('details show real hours and address and return to list', (
    tester,
  ) async {
    final google = FakeGoogle();
    const attraction = Attraction(
      xid: 'google_ChITest123',
      name: 'Test place',
      latitude: 3.14,
      longitude: 101.69,
      category: 'Museum',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => AttractionDetailPage(
                    attraction: attraction,
                    placesService: google,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Test description'), findsOneWidget);
    expect(find.text('Monday: 9 AM – 5 PM'), findsOneWidget);
    expect(find.text('Test address'), findsOneWidget);
    expect(find.text('Open Daily'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('unavailable live details keep the place and offer retry', (
    tester,
  ) async {
    final google = FakeGoogle()..failDetails = true;
    const attraction = Attraction(
      xid: 'google_ChITest123',
      name: 'Test place',
      latitude: 3.14,
      longitude: 101.69,
      category: 'Museum',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AttractionDetailPage(
          attraction: attraction,
          placesService: google,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Test place'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(
      find.text('Opening hours unavailable. Check before visiting.'),
      findsOneWidget,
    );
    google.failDetails = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Test description'), findsOneWidget);
  });
}
