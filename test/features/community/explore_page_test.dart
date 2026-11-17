import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/community/explore_page.dart';
import 'package:smart_travel_planner/features/community/widgets/citylore_post_card.dart';

void main() {
  testWidgets(
    'Community shows an empty feed and posting controls without sample posts',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ExplorePage(isVisible: true))),
      );
      await tester.pumpAndSettle();

      // 1. Verify Share Prompt Card
      expect(find.text('Share a Tip or Ask a Question'), findsOneWidget);
      expect(
        find.text('Share a local tip, trip story, or question.'),
        findsOneWidget,
      );
      expect(find.text('New post'), findsOneWidget);

      // 2. Verify Filter Chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Local Tips'), findsOneWidget);
      expect(find.text('Trip Logs'), findsOneWidget);
      expect(find.text('Questions'), findsOneWidget);
      await tester.drag(find.text('Questions'), const Offset(-250, 0));
      await tester.pumpAndSettle();
      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('Places & Map'), findsNothing);

      expect(find.text('No posts yet.'), findsOneWidget);
      expect(find.byType(CitylorePostCard), findsNothing);
      expect(find.text('Amina Rahman'), findsNothing);
    },
  );
}
