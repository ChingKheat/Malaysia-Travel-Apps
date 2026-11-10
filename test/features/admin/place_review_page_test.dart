import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/admin/screens/place_review_page.dart';
import 'package:smart_travel_planner/features/admin/services/admin_places_repository.dart';
import 'package:smart_travel_planner/features/places/models/google_place_details.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';

class ReviewRepository extends AdminPlacesRepository {
  int saves = 0;
  @override
  Future<void> saveReview(
    Map<String, dynamic> original,
    String category,
    bool? indoor,
  ) async {
    saves++;
  }
}

class ReviewGoogle extends GooglePlacesService {
  int loads = 0;
  @override
  Future<GooglePlaceDetails?> fetchDetails(
    String id, {
    bool basic = false,
  }) async {
    loads++;
    return GooglePlaceDetails(id, {
      'displayName': {'text': 'Live museum'},
      'primaryTypeDisplayName': {'text': 'Museum'},
      'formattedAddress': 'Penang address',
    });
  }
}

void main() {
  testWidgets(
    'review is explicit, loads on demand and fits large text on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = ReviewRepository();
      final google = ReviewGoogle();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: PlaceReviewPage(
            row: {
              'place_id': 'ChITest123',
              'state': 'Penang',
              'category': 'Culture',
              'is_indoor': null,
            },
            repository: repo,
            google: google,
          ),
        ),
      );
      expect(google.loads, 0);
      expect(repo.saves, 0);
      expect(tester.takeException(), isNull);
      final scrollable = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Load / retry live details'),
        250,
        scrollable: scrollable,
      );
      await tester.tap(find.text('Load / retry live details'));
      await tester.pumpAndSettle();
      expect(google.loads, 1);
      expect(repo.saves, 0);
      await tester.scrollUntilVisible(
        find.text('Live museum'),
        150,
        scrollable: scrollable,
      );
      expect(find.text('Live museum'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Confirm and save review'),
        250,
        scrollable: scrollable,
      );
      await tester.tap(find.text('Confirm and save review'));
      await tester.pumpAndSettle();
      expect(repo.saves, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
