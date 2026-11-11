import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/community/community_page.dart';

void main() {
  testWidgets(
    'saved filter includes a bookmarked post and detail shares state',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: CommunityPage()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Save post').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Save post').first);
      await tester.scrollUntilVisible(find.text('Saved'), -400);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saved'));
      await tester.pumpAndSettle();
      expect(find.text('Kuala Lumpur'), findsOneWidget);
      await tester.ensureVisible(find.text('Read story').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read story').first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Save post'))
            .selected,
        isTrue,
      );
      await tester.ensureVisible(find.text('Save post'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save post'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.text('No posts here yet. Try another filter or bookmark a post.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('text draft survives reopening composer', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: CommunityComposer()));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'A quiet morning in Ipoh',
    );
    await tester.enterText(find.byType(TextField).last, 'Ipoh');
    await tester.ensureVisible(find.text('Save text draft'));
    await tester.tap(find.text('Save text draft'));
    await tester.pumpAndSettle();
    expect(find.text('Text draft saved on this device.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const MaterialApp(home: CommunityComposer()));
    await tester.pumpAndSettle();
    expect(find.text('A quiet morning in Ipoh'), findsOneWidget);
    expect(find.text('Ipoh'), findsOneWidget);
    expect(find.textContaining('No public uploads'), findsOneWidget);
  });
}
