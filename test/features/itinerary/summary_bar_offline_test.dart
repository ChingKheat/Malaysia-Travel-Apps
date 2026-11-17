import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/itinerary/widgets/summary_bar.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';

void main() {
  testWidgets('Missing location does not show invented route metrics', (
    tester,
  ) async {
    const stop = TravelStop(
      title: 'Saved place',
      time: '09:00 AM - 10:00 AM',
      note: '',
      description: '',
      duration: '60 min',
      openingHours: 'Hours unverified',
      tips: [],
      icon: Icons.place,
      color: Colors.blue,
      placeId: 'ChIJtest',
      dataSource: 'google',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SummaryBar(stops: [stop])),
      ),
    );
    expect(find.text('Unavailable'), findsNWidgets(2));
    expect(find.text('~0.0 km'), findsNothing);
  });
}
