import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/community/explore_page.dart';
import 'package:smart_travel_planner/features/community/widgets/citylore_post_card.dart';

void main() {
  test('formatCommunityPlaceName capitalizes places and preserves commas', () {
    expect(formatCommunityPlaceName('putrajaya'), 'Putrajaya');
    expect(formatCommunityPlaceName('kuala lumpur'), 'Kuala Lumpur');
    expect(formatCommunityPlaceName('Ayer Hitam, Johor'), 'Ayer Hitam, Johor');
    expect(formatCommunityPlaceName('GEORGE TOWN'), 'George Town');
  });

  test('Community location filter matches city and city-state labels', () {
    expect(communityPlaceMatches('Ayer Hitam, Johor', 'Ayer Hitam'), true);
    expect(communityPlaceMatches('Ayer Hitam', 'Ayer Hitam'), true);
    expect(communityPlaceMatches('Ayer Hitam, Johor', 'Johor'), true);
    expect(communityPlaceMatches('George Town, Penang', 'Penang'), true);
    expect(communityPlaceMatches('Johor Bahru', 'Ayer Hitam'), false);
    expect(communityPlaceMatches('KL', 'Kuala Lumpur'), true);
    expect(communityPlaceMatches('Kuala Lumpur', 'KL'), true);
    expect(communityPlaceMatches('KLCC, Kuala Lumpur', 'Kuala Lumpur'), true);
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

      // Tapping "All locations" opens the polished filter sheet
      await tester.tap(find.text('All locations'));
      await tester.pumpAndSettle();
      expect(find.text('Filter posts by place'), findsOneWidget);
      expect(find.textContaining('Kuala Lumpur'), findsWidgets);
      expect(find.text('Penang'), findsOneWidget);
    },
  );
}
