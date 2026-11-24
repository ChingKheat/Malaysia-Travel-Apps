import 'package:flutter/material.dart';
import 'package:smart_travel_planner/features/assistant/widgets/assistant_stop_preview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/assistant/services/assistant_tool_handler.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/itinerary/models/itinerary_models.dart';
import 'package:smart_travel_planner/features/itinerary/services/local_itinerary_store.dart';
import 'package:smart_travel_planner/features/itinerary/services/supabase_itinerary_service.dart';
import 'package:smart_travel_planner/features/places/services/place_catalog_service.dart';

class _Catalog extends PlaceCatalogService {
  @override
  Future<List<Map<String, dynamic>>> load({String? state}) async => [
    {'place_id': 'park', 'name': 'Park'},
    {'place_id': 'empty', 'name': ' ', 'category': 'Food'},
    {'place_id': 'reference', 'name': 'Saved Google place', 'category': 'Food'},
    {'place_id': 'cafe', 'name': 'Market Cafe', 'category': 'Food'},
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = LocalItineraryStore();
  late SupabaseItineraryService service;
  late String uid;
  late String tripId;
  late String dayId;
  ItineraryStop stop(String id, String arrival, String departure) =>
      ItineraryStop(
        id: id,
        scheduleId: dayId,
        placeId: id,
        placeName: id,
        stopOrder: 1,
        arrivalTime: arrival,
        departureTime: departure,
      );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService().loginAsGuest();
    uid = AuthService().currentUser!.uid;
    service = SupabaseItineraryService.withStore(store);
    tripId = (await service.saveItinerary(
      title: 'Weekend',
      destinationState: 'Kuala Lumpur',
      totalCost: 0,
      dailySchedules: [
        DailySchedule(
          scheduleId: '',
          itineraryId: '',
          dayNumber: 1,
          scheduleDate: DateTime(2026, 12, 1),
        ),
      ],
    )).itineraryId!;
    dayId = (await service.getSavedItineraries(
      refresh: false,
    )).single.dailySchedules.single.scheduleId;
  });

  test('Food cards only include identifiable venues', () async {
    final handler = AssistantToolHandler(places: _Catalog());
    final result = await handler.execute('search_malaysia_places', {
      'category': 'food',
      'keyword': '',
    });
    final names = (result['places'] as List).map((row) => row['name']);
    expect(names, contains('Market Cafe'));
    expect(names, isNot(contains('Saved Google place')));
    expect(names, isNot(contains(' ')));
  });

  test('Preview and cancellation leave the journal unchanged', () async {
    final before = await store.read(uid);
    final result = await AssistantToolHandler(
      places: _Catalog(),
    ).execute('add_to_itinerary', {'place_id': 'park'});
    expect(result['confirmation_required'], isTrue);
    expect(await store.read(uid), before);
  });

  test(
    'Bundled attractions can be previewed without a server catalog row',
    () async {
      final handler = AssistantToolHandler(places: _Catalog());
      final catalog = await handler.catalog();
      final place = catalog.singleWhere(
        (row) => row['name'] == 'Melaka River Cruise',
      );
      final result = await handler.execute('add_to_itinerary', {
        'place_id': place['place_id'],
      });
      expect(result['confirmation_required'], isTrue);
      expect((result['proposal'] as Map)['place_name'], 'Melaka River Cruise');
    },
  );

  Future<void> openPreview(
    WidgetTester tester,
    Map<String, dynamic> details,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => showAssistantStopPreview(context, {
                  'place_id': 'park',
                  'place_name': 'Park',
                  ...details,
                }, repository: service),
                child: const Text('Open preview'),
              );
            },
          ),
        ),
      ),
    );
    final open = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Open preview'))
        .onPressed!;
    await tester.runAsync(() async {
      open();
      await service.getSavedItineraries(refresh: false);
    });
    await tester.pumpAndSettle();
  }

  testWidgets('Cancel an incomplete preview and leave storage unchanged', (
    tester,
  ) async {
    final before = await store.read(uid);
    await openPreview(tester, {});
    expect(find.text('Preview stop'), findsOneWidget);
    expect(find.text('Choose'), findsNWidgets(4));
    final confirm = find.widgetWithText(FilledButton, 'Confirm and save');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Preview stop'), findsNothing);
    expect(await store.read(uid), before);
  });

  testWidgets('Offline preview saves locally and displays pending sync', (
    tester,
  ) async {
    await openPreview(tester, {
      'trip_title': 'Weekend',
      'day_number': 1,
      'arrival_time': '10:00',
      'departure_time': '11:00',
    });
    final confirm = find.widgetWithText(FilledButton, 'Confirm and save');
    final save = tester.widget<FilledButton>(confirm).onPressed!;
    final trips = await tester.runAsync(() async {
      save();
      save();
      return service.getSavedItineraries(refresh: false);
    });
    await tester.pumpAndSettle();
    expect(find.text('Saved on this device · Pending sync'), findsOneWidget);
    expect(trips!.single.dailySchedules.single.stops.single.placeId, 'park');
  });

  test('A conflict introduced after preview prevents saving', () async {
    final proposal = stop('park', '10:00', '11:00');
    await service.updateDailyScheduleStops(
      scheduleId: dayId,
      totalDistanceKm: 0,
      stops: [stop('museum', '9:30 AM', '10:30 AM')],
    );
    expect(
      await service.confirmStop(uid, tripId, proposal),
      StopConfirmation.conflict,
    );
    expect(
      (await service.getSavedItineraries(
        refresh: false,
      )).single.dailySchedules.single.stops.single.placeId,
      'museum',
    );
  });

  test(
    'Double confirmation and retry persist one stop with pending sync',
    () async {
      final proposal = stop('park', '10:00', '11:00');
      final results = await Future.wait(
        List.generate(2, (_) => service.confirmStop(uid, tripId, proposal)),
      );
      expect(results, [StopConfirmation.pending, StopConfirmation.pending]);
      final restarted = SupabaseItineraryService.withStore(store);
      expect(
        await restarted.confirmStop(uid, tripId, proposal),
        StopConfirmation.pending,
      );
      expect(
        (await restarted.getSavedItineraries(
          refresh: false,
        )).single.dailySchedules.single.stops.single.id,
        'park',
      );
      expect((await store.read(uid))[tripId]['pending'], isTrue);
    },
  );
}
