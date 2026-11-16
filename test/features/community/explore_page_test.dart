import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/community/explore_page.dart';
import 'package:smart_travel_planner/features/community/widgets/citylore_post_card.dart';

void main() {
  testWidgets('Community shows an empty feed and posting controls without sample posts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ExplorePage(isVisible: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Share Prompt Card
    expect(find.text('Share from Kuala Lumpur'), findsOneWidget);
    expect(
      find.text('Share a local tip, trip story, or question.'),
      findsOneWidget,
    );
    expect(find.text('New post'), findsOneWidget);

    // 2. Verify Filter Chips
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Local Tip'), findsAtLeastNWidgets(1));
    expect(find.text('Trip Log'), findsAtLeastNWidgets(1));
    expect(find.text('Question'), findsAtLeastNWidgets(1));
    expect(find.text('Photo'), findsAtLeastNWidgets(1));

    expect(find.text('No posts yet.'), findsOneWidget);
    expect(find.byType(CitylorePostCard), findsNothing);
    expect(find.text('Amina Rahman'), findsNothing);
  });
}
