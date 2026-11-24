import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/community/explore_page.dart';
import 'package:smart_travel_planner/features/community/widgets/citylore_post_card.dart';

void main() {
  test('Community location filter matches city and city-state labels', () {
    expect(communityPlaceMatches('Ayer Hitam, Johor', 'Ayer Hitam'), true);
    expect(communityPlaceMatches('Ayer Hitam', 'Ayer Hitam'), true);
    expect(communityPlaceMatches('Johor Bahru', 'Ayer Hitam'), false);
  });
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

      // The welcome image and posting action lead the feed.
      expect(find.text('Welcome to the community'), findsOneWidget);
      expect(
        find.text('Discover traveller stories and share your own.'),
        findsOneWidget,
      );
      expect(find.text('New post'), findsOneWidget);
      expect(find.text('All locations'), findsOneWidget);
      expect(find.text('Saved posts'), findsOneWidget);

      // 2. Verify Filter Chips are removed
      expect(find.text('Local Tips'), findsNothing);
      expect(find.text('Trip Logs'), findsNothing);
      expect(find.text('Photos'), findsNothing);
      expect(find.text('Questions'), findsNothing);

      expect(find.text('No posts yet.'), findsOneWidget);
      expect(find.byType(CitylorePostCard), findsNothing);
      expect(find.text('Amina Rahman'), findsNothing);
    },
  );
}
