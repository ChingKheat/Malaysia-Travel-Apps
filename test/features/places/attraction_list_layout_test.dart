import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/places/data/curated_attractions.dart';
import 'package:smart_travel_planner/features/places/screens/attraction_list_screen.dart';

void main() {
  testWidgets('Explore highlights stay inside the screen width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttractionListScreen(
            attractions: const [],
            selectedStops: const [],
            highlights: curatedMalaysianAttractions.take(3).toList(),
            currentAreaName: 'Kuala Lumpur',
            onAttractionTap: (_) {},
            onToggleStop: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final cards = find.byType(HighlightAttractionCard);
    expect(cards, findsNWidgets(2));
    for (var index = 0; index < 2; index++) {
      expect(tester.getSize(cards.at(index)).width, closeTo(350, 1));
    }
    expect(find.byType(Scrollable), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
