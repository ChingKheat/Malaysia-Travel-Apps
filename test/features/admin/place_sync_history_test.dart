import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/admin/models/place_sync_record.dart';
import 'package:smart_travel_planner/features/admin/services/place_sync_history_service.dart';
import 'package:smart_travel_planner/features/admin/widgets/place_sync_notice.dart';

class MemoryHistoryCloud implements PlaceSyncHistoryCloud {
  final rows = <String, PlaceSyncRecord>{};
  bool offline = false;
  int recordCalls = 0;
  DateTime time = DateTime.utc(2026, 10, 16, 3);
  @override
  Future<PlaceSyncRecord?> load(String state) async {
    if (offline) throw StateError('offline');
    return rows[state];
  }

  @override
  Future<PlaceSyncRecord> record(String state, int count, int requests) async {
    recordCalls++;
    if (offline) throw StateError('offline');
    return rows[state] = PlaceSyncRecord(
      state: state,
      lastSyncedAt: time,
      placeCount: count,
      requestCount: requests,
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Relative ages and Malaysia dates handle day boundaries and future device clocks',
    () {
      final record = PlaceSyncRecord(
        state: 'Penang',
        lastSyncedAt: DateTime.utc(2026, 10, 16, 20, 5),
        placeCount: 120,
        requestCount: 8,
      );
      expect(record.ageLabel(DateTime.utc(2026, 10, 18, 20, 5)), '2 days ago');
      expect(record.ageLabel(DateTime.utc(2026, 10, 16, 22, 5)), '2 hours ago');
      expect(
        record.ageLabel(DateTime.utc(2026, 10, 16, 20, 6)),
        '1 minute ago',
      );
      expect(record.ageLabel(DateTime.utc(2026, 10, 16, 20)), 'just now');
      expect(record.malaysiaDateLabel, '17/10/2026 04:05 MYT');
    },
  );
  test(
    'Recording a successful import persists state-specific metadata across instances',
    () async {
      final cloud = MemoryHistoryCloud();
      final service = PlaceSyncHistoryService(cloud: cloud);
      final penang = await service.recordSuccess(
        state: 'Penang',
        placeCount: 120,
        requestCount: 8,
      );
      expect(penang.lastSyncedAt, cloud.time);
      expect(penang.localOnly, false);
      final restarted = PlaceSyncHistoryService(cloud: cloud);
      expect((await restarted.load('Penang'))!.placeCount, 120);
      expect(await restarted.load('Johor'), isNull);
      expect(
        cloud.recordCalls,
        1,
      ); // Loading a notice never starts another import.
      cloud.offline = true;
      final cached = await PlaceSyncHistoryService(cloud: cloud).load('Penang');
      expect(cached!.lastSyncedAt, cloud.time);
    },
  );
  test(
    'History reads do not change the timestamp or create a success for old data',
    () async {
      final cloud = MemoryHistoryCloud();
      final service = PlaceSyncHistoryService(cloud: cloud);
      expect(await service.load('Penang'), isNull);
      expect(await service.load('Penang'), isNull);
      expect(cloud.recordCalls, 0);
      cloud.offline = true;
      expect(await service.load('Penang'), isNull);
      expect(service.lastReadOffline, true);
    },
  );
  test(
    'Failed metadata uploads retain a clearly labelled local timestamp',
    () async {
      final cloud = MemoryHistoryCloud()..offline = true;
      final completion = DateTime.utc(2026, 10, 18, 6);
      final service = PlaceSyncHistoryService(
        cloud: cloud,
        now: () => completion,
      );
      final record = await service.recordSuccess(
        state: 'Penang',
        placeCount: 80,
        requestCount: 8,
      );
      expect(record.localOnly, true);
      cloud.offline = false;
      final restarted = PlaceSyncHistoryService(cloud: cloud);
      expect((await restarted.load('Penang'))!.lastSyncedAt, completion);
      expect((await restarted.load('Penang'))!.localOnly, true);
      cloud.time = completion.add(const Duration(hours: 1));
      await restarted.recordSuccess(
        state: 'Penang',
        placeCount: 90,
        requestCount: 9,
      );
      expect((await restarted.load('Penang'))!.localOnly, false);
    },
  );
  test('Corrupt local metadata does not crash the Admin Hub', () async {
    final cloud = MemoryHistoryCloud();
    final service = PlaceSyncHistoryService(cloud: cloud);
    await service.recordSuccess(
      state: 'Penang',
      placeCount: 80,
      requestCount: 8,
    );
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getKeys().singleWhere(
      (k) => k.startsWith('place_sync_v1:'),
    );
    await prefs.setString(key, 'invalid json');
    cloud.offline = true;
    expect(await service.load('Penang'), isNull);
  });
  testWidgets(
    'Notice shows age, exact date and counts without overflowing a phone',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaceSyncNotice(
              state: 'Penang',
              now: DateTime.utc(2026, 10, 18, 3),
              record: PlaceSyncRecord.fromJson(
                jsonDecode(
                  '{"state":"Penang","last_synced_at":"2026-10-16T03:00:00Z","place_count":120,"request_count":8}',
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Penang — last synced 2 days ago'), findsOneWidget);
      expect(find.textContaining('16/10/2026 11:00 MYT'), findsOneWidget);
      expect(
        find.textContaining('120 places found · 8 search requests'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Notice does not label imports with unknown dates as never synced',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PlaceSyncNotice(state: 'Johor', record: null)),
        ),
      );
      expect(find.text('Johor — sync time not recorded'), findsOneWidget);
      expect(
        find.textContaining('Older imports have no recorded date'),
        findsOneWidget,
      );
      expect(find.textContaining('never synced'), findsNothing);
    },
  );
}
