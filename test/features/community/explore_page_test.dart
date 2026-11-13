import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/community/explore_page.dart';
import 'package:smart_travel_planner/features/community/widgets/citylore_post_card.dart';

void main() {
  testWidgets('Citylore ExplorePage renders editorial dark card feed and controls', (
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
      find.text('Post a photo, local tip, or itinerary...'),
      findsOneWidget,
    );
    expect(find.text('New post'), findsOneWidget);

    // 2. Verify Filter Chips
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Local Tip'), findsAtLeastNWidgets(1));
    expect(find.text('Trip Log'), findsAtLeastNWidgets(1));
    expect(find.text('Question'), findsAtLeastNWidgets(1));
    expect(find.text('Photo'), findsAtLeastNWidgets(1));

    // 3. Verify Citylore Post Card (The Design Box)
    expect(find.byType(CitylorePostCard), findsWidgets);
    expect(find.text('Amina Rahman'), findsOneWidget);
    expect(find.text('AR'), findsOneWidget);
    expect(find.text('Penang · Architect · 2h ago'), findsOneWidget);
    expect(find.text('Chinatown Edge'), findsOneWidget);
    expect(
      find.text('Early kopi tarik & kaya toast before Central Market opens'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Skip the midday rush by arriving along Jalan Tun H.S. Lee'),
      findsOneWidget,
    );
    expect(find.text('View related landmark →'), findsWidgets);
    expect(find.text('38'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Message'), findsWidgets);
    expect(find.text('Saved'), findsWidgets);

    // 4. Test like button increments like count
    final likeButton = find.byTooltip('Like').first;
    await tester.ensureVisible(likeButton);
    await tester.tap(likeButton);
    await tester.pumpAndSettle();
    expect(find.text('39'), findsOneWidget);

    // 5. Test Message opens composer/dialog
    final messageButton = find.widgetWithText(InkWell, 'Message').first;
    await tester.ensureVisible(messageButton);
    await tester.tap(messageButton);
    await tester.pumpAndSettle();
    expect(find.text('Message Amina Rahman'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
  });
}
