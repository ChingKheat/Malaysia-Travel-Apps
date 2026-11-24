import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/itinerary/models/destination_leg.dart';
import 'package:smart_travel_planner/features/itinerary/models/transfer_event.dart';
import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/services/segmented_itinerary_scheduler.dart';
import 'package:smart_travel_planner/features/itinerary/services/transfer_manager.dart';
import 'package:smart_travel_planner/features/itinerary/services/travel_feasibility_calculator.dart';
import 'package:smart_travel_planner/features/itinerary/widgets/day_allocation_stepper.dart';
import 'package:smart_travel_planner/features/itinerary/widgets/multi_city_route_filter_bar.dart';
import 'package:smart_travel_planner/shared/data/malaysia_states.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';

TravelStop _mockStop(
  String id,
  String title,
  double lat,
  double lng, {
  String category = 'Attraction',
  String hours = '09:00 - 18:00',
}) => TravelStop(
  placeId: id,
  title: title,
  time: '',
  note: category,
  description: title,
  duration: '90 min',
  openingHours: hours,
  tips: const [],
  icon: Icons.place,
  color: Colors.amber,
  category: category,
  latitude: lat,
  longitude: lng,
);

void main() {
  group('Multi-Destination Data Models & Compatibility', () {
    test('Legacy single-destination JSON parses cleanly', () {
      final prefs = TripPreferences.fromJson({
        'destination': 'Johor',
        'number_of_days': 3,
      });

      expect(prefs.planningMode, PlanningMode.singleDestination);
      expect(prefs.isMultiDestination, isFalse);
      expect(prefs.effectiveLegs.length, 1);
      expect(prefs.effectiveLegs.first.stateName, 'Johor');
      expect(prefs.effectiveLegs.first.allocatedDays, 3);
    });

    test(
      'All-state multi-destination JSON round-trip and VARCHAR(100) label cap',
      () {
        final allLegs = [
          for (int i = 0; i < malaysiaStates.length; i++)
            DestinationLeg.fromStateName(
              malaysiaStates[i],
              allocatedDays: 1,
              sequence: i + 1,
            ),
        ];
        final prefs = TripPreferences(
          planningMode: PlanningMode.multiDestination,
          numberOfDays: allLegs.length,
          legs: allLegs,
        );

        expect(prefs.isMultiDestination, isTrue);
        expect(prefs.effectiveDestinationLabel!.length, lessThanOrEqualTo(100));

        final restored = TripPreferences.fromJson(prefs.toJson());
        expect(restored.planningMode, PlanningMode.multiDestination);
        expect(restored.legs.length, malaysiaStates.length);
        expect(restored.legs.first.stateName, malaysiaStates.first);
      },
    );
  });

  group('TransferManager Route Optimization & Sea-Crossing', () {
    test('Groups Peninsula hubs together before crossing to Borneo', () {
      final legs = [
        DestinationLeg.fromStateName('Penang', allocatedDays: 3, sequence: 1),
        DestinationLeg.fromStateName('Sabah', allocatedDays: 3, sequence: 2),
        DestinationLeg.fromStateName('Johor', allocatedDays: 2, sequence: 3),
        DestinationLeg.fromStateName(
          'Kuala Lumpur',
          allocatedDays: 2,
          sequence: 4,
        ),
      ];

      final optimized = TransferManager.optimizeLegOrder(legs);
      expect(optimized.last.region, MalaysianRegion.sabah);
      expect(optimized[0].stateName, 'Penang');
      expect(optimized[1].stateName, 'Kuala Lumpur');
      expect(optimized[2].stateName, 'Johor');
    });

    test('Forces Domestic Flight when crossing Peninsula to Sabah', () {
      final kl = DestinationLeg.fromStateName(
        'Kuala Lumpur',
        allocatedDays: 3,
        sequence: 1,
      );
      final sabah = DestinationLeg.fromStateName(
        'Sabah',
        allocatedDays: 4,
        sequence: 2,
      );
      final transfer = TransferManager.estimateTransfer(
        kl,
        sabah,
        DateTime(2026, 12, 4),
        preferredMode: InterCityTransportMode.privateCar,
      );

      expect(transfer.transportMode, InterCityTransportMode.domesticFlight);
      expect(transfer.isEstimated, isTrue);
      expect(transfer.totalTransferMinutes, greaterThan(180));
    });

    test('autoDistributeDays sums strictly to totalDays', () {
      final legs = [
        DestinationLeg.fromStateName('Johor'),
        DestinationLeg.fromStateName('Kuala Lumpur'),
        DestinationLeg.fromStateName('Penang'),
        DestinationLeg.fromStateName('Perak'),
      ];

      final distributed = TransferManager.autoDistributeDays(legs, 11);
      final total = distributed.fold<int>(0, (s, l) => s + l.allocatedDays);
      expect(total, 11);
      expect(distributed.every((l) => l.allocatedDays >= 1), isTrue);
    });
  });

  group('SegmentedItineraryScheduler & TravelFeasibilityCalculator', () {
    final kl = DestinationLeg.fromStateName('Kuala Lumpur');
    final penang = DestinationLeg.fromStateName('Penang', sequence: 2);

    test(
      'Schedules must-visits absent from the fetched city candidates',
      () async {
        final saved = _mockStop(
          'saved',
          'Saved museum',
          kl.latitude,
          kl.longitude,
        );
        final scan = _mockStop(
          'scan',
          'Scanned landmark',
          penang.latitude,
          penang.longitude,
          hours: 'Hours unverified',
        );
        final dining = _mockStop(
          'dining',
          'Dinner',
          penang.latitude,
          penang.longitude,
          category: 'Dining',
          hours: '24 hours',
        );
        final second = _mockStop(
          'second',
          'Second priority',
          penang.latitude,
          penang.longitude,
          hours: '24 hours',
        );
        final distant = _mockStop(
          'distant-priority',
          'Distant priority',
          5.98,
          116.07,
        );
        final priorities = [saved, scan, second, distant];
        final preferences = TripPreferences(
          planningMode: PlanningMode.multiDestination,
          startDate: DateTime(2026, 12, 7),
          legs: [kl, penang],
          mustVisitPlaces: priorities,
        );
        final result = await SegmentedItineraryScheduler.schedule(
          preferences: TripPreferences.fromJson(preferences.toJson()),
          fetchCandidates: (leg) async => leg == penang ? [dining] : [],
          resolvePriority: (stop, leg) async {
            expect(leg, penang);
            expect(stop.placeId, 'scan');
            return _mockStop(
              'resolved-scan',
              stop.title,
              stop.latitude,
              stop.longitude,
            );
          },
        );

        expect(result.days[0]!.map((stop) => stop.placeId), contains('saved'));
        expect(
          result.days[1]!
              .where((stop) => stop.category != 'Transit')
              .map((stop) => stop.placeId),
          ['resolved-scan', 'second'],
        );
        expect(
          result.warnings.values.join(' '),
          isNot(contains('Scanned landmark')),
        );
        expect(
          result.warnings.values.join(' '),
          contains('Distant priority (outside'),
        );
      },
    );

    Future<SegmentedScheduleResult> schedulePenang(
      List<TravelStop> candidates, {
      TimeOfDay start = const TimeOfDay(hour: 9, minute: 0),
      TimeOfDay end = const TimeOfDay(hour: 21, minute: 0),
    }) => SegmentedItineraryScheduler.schedule(
      preferences: TripPreferences(
        planningMode: PlanningMode.multiDestination,
        startDate: DateTime(2026, 12, 7),
        dailyStartTime: start,
        dailyEndTime: end,
        legs: [kl, penang],
      ),
      fetchCandidates: (leg) async => leg == penang ? candidates : [],
    );

    test(
      'Skips distant and unlocated places when the hub has no candidates',
      () async {
        final rejected = [
          _mockStop(
            'distant',
            'Distant park',
            penang.latitude + 1,
            penang.longitude,
          ),
          _mockStop('unlocated', 'Unlocated park', 0, 0),
        ];
        for (final candidate in rejected) {
          final result = await schedulePenang([candidate]);
          expect(result.days[1]!.map((stop) => stop.category), [
            'Transit',
            'Transit',
            'Transit',
          ], reason: candidate.title);
        }
      },
    );

    test(
      'Picks an open, reachable place over a closed or unreachable dining stop',
      () async {
        final result = await schedulePenang([
          _mockStop(
            'closed',
            'Closed cafe',
            penang.latitude,
            penang.longitude,
            category: 'Dining',
            hours: 'Wed - Sun, 09:00 - 21:00',
          ),
          _mockStop(
            'tight',
            'Closes early',
            penang.latitude + 0.18,
            penang.longitude,
            category: 'Dining',
            hours: '09:00 - 16:15',
          ),
          _mockStop(
            'open',
            'Open park',
            penang.latitude + 0.01,
            penang.longitude,
            hours: '09:00 - 21:00',
          ),
        ]);

        final visit = result.days[1]!.singleWhere(
          (stop) => stop.category != 'Transit',
        );
        expect(visit.placeId, 'open');
        expect(visit.travelMinutes, greaterThan(0));
        expect(visit.visitMinutes, 90);
      },
    );

    test(
      'Warns when a transfer exceeds the day and shows next-day arrival',
      () async {
        final result = await schedulePenang(
          [
            _mockStop(
              'open',
              'Open park',
              penang.latitude,
              penang.longitude,
              hours: '24 hours',
            ),
          ],
          start: const TimeOfDay(hour: 22, minute: 0),
          end: const TimeOfDay(hour: 23, minute: 0),
        );

        expect(result.days[1]!.map((stop) => stop.category), [
          'Transit',
          'Transit',
          'Transit',
        ]);
        expect(result.days[1]!.last.time, contains('(+1 day)'));
        expect(result.warnings[1], contains('after your planned end time'));
      },
    );

    test(
      'Schedules 10-day JB -> KL -> Penang trip with transition events',
      () async {
        final legs = [
          DestinationLeg.fromStateName('Johor', allocatedDays: 4, sequence: 1),
          DestinationLeg.fromStateName(
            'Kuala Lumpur',
            allocatedDays: 3,
            sequence: 2,
          ),
          DestinationLeg.fromStateName('Penang', allocatedDays: 3, sequence: 3),
        ];
        final prefs = TripPreferences(
          planningMode: PlanningMode.multiDestination,
          startDate: DateTime(2026, 12, 1),
          endDate: DateTime(2026, 12, 10),
          legs: legs,
          autoOptimizeRouteOrder: false,
        );

        final result = await SegmentedItineraryScheduler.schedule(
          preferences: prefs,
          fetchCandidates: (leg) async {
            return [
              _mockStop(
                '${leg.destinationId}_1',
                '${leg.hubName} Museum',
                leg.latitude + 0.01,
                leg.longitude + 0.01,
              ),
              _mockStop(
                '${leg.destinationId}_2',
                '${leg.hubName} Food Street',
                leg.latitude + 0.02,
                leg.longitude + 0.01,
                category: 'Dining',
              ),
              _mockStop(
                '${leg.destinationId}_3',
                '${leg.hubName} Heritage Park',
                leg.latitude + 0.01,
                leg.longitude + 0.02,
              ),
              _mockStop(
                '${leg.destinationId}_4',
                '${leg.hubName} Night Market',
                leg.latitude + 0.02,
                leg.longitude + 0.02,
                category: 'Dining',
              ),
            ];
          },
        );

        expect(result.days.length, 10);
        expect(result.resolvedTransfers.length, 2);
        // Day 4 (index 4) is transition to KL; Day 7 (index 7) is transition to Penang
        expect(result.days[4]!.any((s) => s.category == 'Transit'), isTrue);
        expect(result.days[7]!.any((s) => s.category == 'Transit'), isTrue);

        final report = TravelFeasibilityCalculator.evaluate(
          days: result.days,
          transfers: result.resolvedTransfers,
          preferences: prefs,
        );
        expect(report.score, inInclusiveRange(50, 100));
        expect(report.summary, isNotEmpty);
      },
    );
  });

  group('DayAllocationStepper Widget', () {
    testWidgets('Increments, decrements, and auto-splits days', (tester) async {
      var legs = [
        DestinationLeg.fromStateName('Johor', allocatedDays: 3, sequence: 1),
        DestinationLeg.fromStateName(
          'Kuala Lumpur',
          allocatedDays: 4,
          sequence: 2,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return DayAllocationStepper(
                  totalDays: 7,
                  legs: legs,
                  onChanged: (updated) => setState(() => legs = updated),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('All days allocated'), findsOneWidget);
      expect(find.text('3d'), findsOneWidget);
      expect(find.text('4d'), findsOneWidget);

      // Tap '+' on Johor (index 0) -> smart borrow from KL -> 4d and 3d
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pump();
      expect(legs[0].allocatedDays, 4);
      expect(legs[1].allocatedDays, 3);
    });
  });

  group('MultiCityRouteFilterBar Widget', () {
    testWidgets('Keeps the route visible while filtering states', (
      tester,
    ) async {
      int? selectedLeg;
      final legs = [
        DestinationLeg.fromStateName('Johor', allocatedDays: 4, sequence: 1),
        DestinationLeg.fromStateName(
          'Kuala Lumpur',
          allocatedDays: 3,
          sequence: 2,
        ),
        DestinationLeg.fromStateName('Penang', allocatedDays: 3, sequence: 3),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return MultiCityRouteFilterBar(
                  legs: legs,
                  startDate: DateTime(2026, 11, 24),
                  selectedLegIndex: selectedLeg,
                  onSelectLeg: (idx) => setState(() => selectedLeg = idx),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Johor → Kuala Lumpur → Penang'), findsOneWidget);
      expect(find.text('Johor (${legs[0].hubName})'), findsOneWidget);
      expect(find.text('Penang (${legs[2].hubName})'), findsOneWidget);
      expect(find.text('All (10d)'), findsOneWidget);
      expect(find.text('Johor (4d)'), findsOneWidget);
      expect(find.text('Kuala Lumpur (3d)'), findsOneWidget);

      // Tap Kuala Lumpur underline tab
      await tester.tap(find.text('Kuala Lumpur (3d)'));
      await tester.pump();
      expect(selectedLeg, 1);

      expect(find.text('Johor → Kuala Lumpur → Penang'), findsOneWidget);
      expect(find.text('Route'), findsNothing);
      expect(find.text('Johor (${legs[0].hubName})'), findsOneWidget);
      expect(find.text('Penang (${legs[2].hubName})'), findsOneWidget);
      final route = tester.widget<Text>(
        find.text('Johor → Kuala Lumpur → Penang'),
      );
      expect(route.maxLines, isNull);
      expect(route.overflow, isNot(TextOverflow.ellipsis));
    });
  });
}
