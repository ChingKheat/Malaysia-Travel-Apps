import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/community/community_page.dart';

void main() {
  testWidgets('post and comments show the owning account label', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final post = CommunityPost.fromFeed({
      'id': 'post',
      'author': 'Alex',
      'place': 'Ipoh',
      'topic': 'Local Tip',
      'body': 'Visit in the morning.',
      'created_at': '2026-11-16T01:00:00Z',
      'likes_count': 1,
      'liked': false,
      'saved': false,
      'is_mine': true,
      'comments': [
        {'body': 'My comment', 'author': 'Alex', 'is_mine': true},
        {
          'id': 'comment-1',
          'body': 'Another comment',
          'author': 'Alex',
          'is_mine': false,
        },
        'An older cached comment',
      ],
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: CommunityPostDetailPage(post: post),
      ),
    );
    expect(find.text('Alex (me)'), findsNWidgets(2));
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('An older cached comment'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Alex'));
    await tester.tap(find.text('Alex'));
    await tester.pumpAndSettle();
    expect(find.text('Community member'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(812, 375);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: CommunityPostDetailPage(post: post),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Add comment'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('text draft survives reopening composer', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: CommunityComposer()));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'A quiet morning in Ipoh',
    );
    await tester.tap(find.byKey(const ValueKey('community-place-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this place'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save & close'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const MaterialApp(home: CommunityComposer()));
    await tester.pumpAndSettle();
    expect(find.text('A quiet morning in Ipoh'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('community-place-picker')),
      findsOneWidget,
    );
    expect(find.textContaining('post and photos will appear'), findsOneWidget);
  });
}
