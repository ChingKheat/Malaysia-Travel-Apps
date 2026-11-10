import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/home/widgets/popular_attractions_section.dart';
import 'package:smart_travel_planner/features/places/screens/attraction_detail_page.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';

void main() {
  const sampleAttractions = [
    Attraction(
      xid: 'curated_kl_01',
      name: 'Petronas Twin Towers (KLCC)',
      latitude: 3.1579,
      longitude: 101.7116,
      category: 'Sights, Landmark, Architecture',
      description: 'Iconic skyscrapers in Kuala Lumpur.',
    ),
    Attraction(
      xid: 'curated_penang_01',
      name: 'George Town Street Art',
      latitude: 5.4141,
      longitude: 100.3370,
      category: 'Culture, Art, Heritage',
      description: 'Heritage street art murals.',
    ),
  ];

  testWidgets('PopularAttractionsSection renders title and See All button',
      (tester) async {
    var seeAllTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PopularAttractionsSection(
              attractions: sampleAttractions,
              onSeeAllTap: () => seeAllTapped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Popular Attractions'), findsOneWidget);
    expect(find.text('See All'), findsOneWidget);
    expect(find.text('Petronas Twin Towers (KLCC)'), findsOneWidget);
    expect(find.text('George Town Street Art'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('popular-attractions-see-all')));
    await tester.pump();
    expect(seeAllTapped, isTrue);
  });

  testWidgets('Tapping an attraction card navigates to AttractionDetailPage',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PopularAttractionsSection(
              attractions: sampleAttractions,
              onSeeAllTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Petronas Twin Towers (KLCC)'), findsOneWidget);

    await tester.tap(find.text('Petronas Twin Towers (KLCC)'));
    await tester.pumpAndSettle();

    expect(find.byType(AttractionDetailPage), findsOneWidget);
    expect(find.text('Attraction Details'), findsOneWidget);
    expect(find.text('Iconic skyscrapers in Kuala Lumpur.'), findsOneWidget);
  });
}
