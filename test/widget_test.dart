// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_travel_planner/app/smart_travel_app.dart';

void main() {
  testWidgets('Smart travel planner renders core prototype', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SmartTravelApp());

    expect(find.text('Hello, Traveler!'), findsOneWidget);
    expect(find.text('Smart Travel Planning'), findsOneWidget);

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();

    expect(find.text('Smart Travel Demo'), findsOneWidget);
    expect(find.text('List'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Batu Caves'), findsWidgets);

    await tester.tap(find.text('Itinerary').first);
    await tester.pumpAndSettle();

    expect(find.text('Rule-based Smart Itinerary'), findsOneWidget);
  });
}
