import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_travel_planner/features/admin/screens/place_details_refresh_page.dart';
import 'package:smart_travel_planner/features/admin/services/admin_places_repository.dart';
import 'package:smart_travel_planner/features/admin/services/place_details_refresh_service.dart';
import 'package:smart_travel_planner/features/admin/services/place_refresh_task.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';
import 'package:smart_travel_planner/features/places/models/google_place_details.dart';

class RefreshRepository extends AdminPlacesRepository {
  RefreshRepository(this.total);
  final int total;
  final writes = <Map<String, dynamic>>[];
  final covers = <String, String>{};
  @override
  Future<String?> readCover(String state, String id) async => covers[id];
  @override
  Future<void> saveCover(
    String state,
    String id,
    String url,
    String? previous,
  ) async {
    covers[id] = url;
  }

  bool fail = false;
  @override
  Future<AdminPlacesPage> load(String state, {int offset = 0}) async =>
      AdminPlacesPage(
        totalCount: total,
        rows: List.generate(
          total,
          (i) => {
            'place_id': 'ChITest$i',
            'state': state,
            'data_source': 'google',
          },
        ).skip(offset).take(20).toList(),
      );
  @override
  Future<int> saveFetchedRows(
    String state,
    Iterable<Map<String, dynamic>> rows,
  ) async {
    if (fail) throw StateError('Database unavailable');
    writes.addAll(rows);
    return rows.length;
  }
}

class RefreshGoogle extends GooglePlacesService {
  final calls = <String>[];
  String? stopId;
  bool wrongState = false;
  int status = 429;
  @override
  Future<GooglePlaceDetails?> fetchDetails(
    String id, {
    bool basic = false,
  }) async {
    expect(basic, false);
    calls.add(id);
    if (id == stopId) {
      lastError = 'Allowance exhausted';
      lastStatusCode = status;
      return null;
    }
    lastStatusCode = 200;
    return GooglePlaceDetails(id, {
      'displayName': {'text': 'Museum'},
      'location': {'latitude': 5.4, 'longitude': 100.3},
      'regularOpeningHours': {
        'weekdayDescriptions': ['Monday: 9–11'],
      },
      'rating': 4.7,
      'userRatingCount': 123,
      'addressComponents': [
        {
          'types': ['country'],
          'shortText': 'MY',
        },
        {
          'types': ['administrative_area_level_1'],
          'longText': wrongState ? 'Melaka' : 'Penang',
        },
      ],
    });
  }
}

class WaitingGoogle extends RefreshGoogle {
  final gate = Completer<void>();
  @override
  Future<GooglePlaceDetails?> fetchDetails(
    String id, {
    bool basic = false,
  }) async {
    await gate.future;
    return super.fetchDetails(id, basic: basic);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('smart_travel/place_sync'),
          (_) async => null,
        );
  });
  Future<PlaceDetailsRefreshService> service(
    RefreshRepository repo,
    RefreshGoogle google,
  ) async => PlaceDetailsRefreshService(
    repository: repo,
    google: google,
    preferences: await SharedPreferences.getInstance(),
    scope: 'test-admin',
    interval: Duration.zero,
  );
  testWidgets(
    'Leaving the details page keeps work running and reattaches without duplicate requests',
    (tester) async {
      final repo = RefreshRepository(2);
      final google = WaitingGoogle();
      final sync = await service(repo, google);
      await tester.pumpWidget(
        MaterialApp(
          home: PlaceDetailsRefreshPage(
            state: 'Penang',
            service: sync,
            syncFlow: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final task = PlaceRefreshTask.attach(sync, 'Penang');
      expect(task.running, true);
      await tester.pumpWidget(const MaterialApp(home: Text('Another page')));
      expect(task.running, true);
      final completion = task.run();
      google.gate.complete();
      await tester.pumpAndSettle();
      expect((await completion).saved, 2);
      expect(google.calls, ['ChITest0', 'ChITest1']);
      expect(task.running, false);
      expect(tester.takeException(), null);
    },
  );

  testWidgets(
    'Unified sync starts details automatically and returns completion',
    (tester) async {
      final repo = RefreshRepository(2);
      final sync = await service(repo, RefreshGoogle());
      int? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.push<int>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlaceDetailsRefreshPage(
                        state: 'Penang',
                        service: sync,
                        syncFlow: true,
                        restartOnStart: true,
                      ),
                    ),
                  );
                },
                child: const Text('Sync places'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Sync places'));
      await tester.pumpAndSettle();
      expect(result, 2);
      expect(repo.writes, hasLength(2));
      expect(find.text('Sync places'), findsOneWidget);
    },
  );

  testWidgets('Unified sync keeps failed details open for resume', (
    tester,
  ) async {
    final google = RefreshGoogle()..stopId = 'ChITest0';
    final sync = await service(RefreshRepository(2), google);
    await tester.pumpWidget(
      MaterialApp(
        home: PlaceDetailsRefreshPage(
          state: 'Penang',
          service: sync,
          syncFlow: true,
          restartOnStart: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(sync.read('Penang')!.next, 0);
    expect(find.text('Resume update'), findsOneWidget);
    expect(find.textContaining('Allowance exhausted'), findsOneWidget);
  });

  test(
    'A failed place is automatically skipped and later places update',
    () async {
      final repo = RefreshRepository(3);
      final google = RefreshGoogle()
        ..stopId = 'ChITest1'
        ..status = 503;
      final sync = await service(repo, google);
      final result = await sync.run(
        'Penang',
        shouldContinue: () => true,
        onProgress: (_) {},
      );
      expect(result.finished, true);
      expect(result.saved, 2);
      expect(result.issues.keys, ['ChITest1']);
      expect(google.calls, ['ChITest0', 'ChITest1', 'ChITest2']);
      expect(repo.writes.map((r) => r['place_id']), ['ChITest0', 'ChITest2']);
    },
  );
  test(
    'Sync links approved photos, preserves existing ones and continues after failures',
    () async {
      final repo = RefreshRepository(4)
        ..covers['ChITest0'] = 'https://example.com/old.jpg';
      final requested = <String>[];
      final sync = PlaceDetailsRefreshService(
        repository: repo,
        google: RefreshGoogle(),
        preferences: await SharedPreferences.getInstance(),
        scope: 'cover-test',
        interval: Duration.zero,
        approvedCover: (id) async {
          requested.add(id);
          if (id == 'ChITest2') throw StateError('Storage unavailable');
          return id == 'ChITest1' ? 'https://example.com/new.jpg' : null;
        },
      );
      final result = await sync.run(
        'Penang',
        shouldContinue: () => true,
        onProgress: (_) {},
      );
      expect(result.saved, 4);
      expect(result.coversSaved, 1);
      expect(result.coversFailed, 1);
      expect(result.coversMissing, 1);
      expect(requested, ['ChITest1', 'ChITest2', 'ChITest3']);
      expect(repo.covers['ChITest0'], 'https://example.com/old.jpg');
      expect(repo.covers['ChITest1'], 'https://example.com/new.jpg');
      requested.clear();
      await sync.run('Penang', shouldContinue: () => true, onProgress: (_) {});
      expect(requested, ['ChITest2', 'ChITest3']);
    },
  );
  test('Refresh covers every page with full hours and ratings', () async {
    final repo = RefreshRepository(23), google = RefreshGoogle();
    final sync = await service(repo, google);
    final result = await sync.run(
      'Penang',
      shouldContinue: () => true,
      onProgress: (_) {},
    );
    expect(result.saved, 23);
    expect(result.finished, true);
    expect(repo.writes.last['operating_hours'], {
      'weekdayDescriptions': ['Monday: 9–11'],
    });
    expect(repo.writes.last['rating'], 4.7);
    expect(google.calls.length, 23);
  });
  test(
    'Quota failure resumes next ID across service restart; completed run can refresh again',
    () async {
      final repo = RefreshRepository(3),
          google = RefreshGoogle()..stopId = 'ChITest1';
      var sync = await service(repo, google);
      var result = await sync.run(
        'Penang',
        shouldContinue: () => true,
        onProgress: (_) {},
      );
      expect(result.saved, 1);
      expect(result.next, 1);
      expect(result.finished, false);
      google.stopId = null;
      sync = await service(repo, google);
      result = await sync.run(
        'Penang',
        shouldContinue: () => true,
        onProgress: (_) {},
      );
      expect(result.saved, 3);
      expect(repo.writes.map((r) => r['place_id']).toSet().length, 3);
      expect(google.calls.where((id) => id == 'ChITest0').length, 1);
      result = await sync.run(
        'Penang',
        shouldContinue: () => true,
        onProgress: (_) {},
      );
      expect(result.saved, 3);
      expect(repo.writes.length, 6);
    },
  );
  test(
    'Write failure and pause retain cursor; wrong state and invalid ID do not overwrite data',
    () async {
      final repo = RefreshRepository(2)..fail = true, google = RefreshGoogle();
      final sync = await service(repo, google);
      var result = await sync.run(
        'Penang',
        shouldContinue: () => true,
        onProgress: (_) {},
      );
      expect(result.next, 0);
      expect(result.saved, 0);
      repo.fail = false;
      google.wrongState = true;
      google.stopId = 'ChITest1';
      google.status = 404;
      result = await sync.run(
        'Penang',
        shouldContinue: () => true,
        onProgress: (_) {},
      );
      expect(result.issues.length, 2);
      expect(result.finished, true);
      expect(repo.writes, isEmpty);
      google.wrongState = false;
      google.stopId = null;
      var active = true;
      result = await sync.run(
        'Penang',
        shouldContinue: () => active,
        onProgress: (p) {
          if (p.saved == 1) active = false;
        },
      );
      expect(result.next, 1);
      expect(result.finished, false);
    },
  );
  test(
    'Full refresh overwrites 8–10 with 9–11 and clears absent fields without touching classification',
    () async {
      final updates = <Map>[];
      final client = SupabaseClient(
        'https://database.test',
        'public',
        httpClient: MockClient((request) async {
          final data = jsonDecode(request.body) as Map;
          updates.add(data);
          expect(data.containsKey('category'), false);
          expect(data.containsKey('is_indoor'), false);
          return http.Response(
            jsonEncode([
              {
                'place_id': 'ChITest',
                'name': 'Museum',
                'latitude': 5.4,
                'longitude': 100.3,
              },
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = AdminPlacesRepository(client: client);
      final google = RefreshGoogle();
      final details = (await google.fetchDetails('ChITest'))!;
      final row = <String, dynamic>{
        'place_id': 'ChITest',
        'name': 'Museum',
        'latitude': 5.4,
        'longitude': 100.3,
        '_live': true,
        '_fullDetails': true,
        '_addressComponents': details.data['addressComponents'],
        'operating_hours': {
          'weekdayDescriptions': ['Monday: 9–11'],
        },
        'rating': 4.7,
      };
      await repo.saveFetchedRows('Penang', [row]);
      expect(updates.last['operating_hours'], {
        'weekdayDescriptions': ['Monday: 9–11'],
      });
      await repo.saveFetchedRows('Penang', [
        {...row, 'operating_hours': null, 'rating': null},
      ]);
      expect(updates.last.containsKey('operating_hours'), true);
      expect(updates.last['operating_hours'], null);
      expect(updates.last['rating'], null);
    },
  );
  testWidgets('Refresh page works with large text and shows completed counts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sync = await service(RefreshRepository(1), RefreshGoogle());
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: PlaceDetailsRefreshPage(state: 'Penang', service: sync),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Update all saved places'), 200);
    await tester.ensureVisible(find.text('Update all saved places'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update all saved places'));
    await tester.pumpAndSettle();
    expect(sync.read('Penang')!.saved, 1);
    expect(tester.takeException(), null);
  });
  test(
    'skipCurrent moves cursor and records skipped place in issues',
    () async {
      final repo = RefreshRepository(2), google = RefreshGoogle();
      final sync = await service(repo, google);
      var first = true;
      final initial = await sync.run(
        'Penang',
        shouldContinue: () {
          if (first) {
            first = false;
            return true;
          }
          return false;
        },
        onProgress: (_) {},
      );
      expect(initial.next, 0);
      final skipped = await sync.skipCurrent('Penang');
      expect(skipped!.next, 1);
      expect(skipped.issues['ChITest0'], contains('Skipped by administrator'));
      final result = await sync.run(
        'Penang',
        shouldContinue: () => true,
        onProgress: (_) {},
      );
      expect(result.saved, 1);
      expect(result.finished, true);
      expect(result.issues.length, 1);
    },
  );
}
