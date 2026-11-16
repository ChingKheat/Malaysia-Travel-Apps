import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smart_travel_planner/features/itinerary/services/day_route_service.dart';
import 'package:smart_travel_planner/features/itinerary/widgets/day_route_map.dart';
import 'package:smart_travel_planner/shared/models/route_info.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';
import 'package:smart_travel_planner/shared/services/google_route_service.dart';

TravelStop stop(String name, String time, double latitude) =>
    TravelStop.fromJson({
      'title': name,
      'time': time,
      'latitude': latitude,
      'longitude': latitude == 0 ? 0.0 : 101.7,
    });

class TestRoutes extends GoogleRouteService {
  final calls = <(String, List<LatLng>)>[];
  bool fail = false;

  @override
  Future<RouteInfo?> fetchRoadRoute(
    List<LatLng> points, {
    required String mode,
  }) async {
    calls.add((mode, points));
    if (fail) return null;
    return RouteInfo(
      points: [points.first, const LatLng(3.25, 101.71), points.last],
      distanceKm: 4.5,
      durationMinutes: 20.5,
      isFallback: false,
    );
  }
}

void main() {
  final first = stop('First stop', '09:00 - 10:30', 3.2);
  final second = stop('Second stop', '10:45 - 12:00', 3.3);
  final third = stop('Third stop', '13:00 - 14:30', 3.4);

  test('loads adjacent stops in order and reuses only matching legs', () async {
    final routes = TestRoutes();
    final service = DayRouteService(routes: routes);
    final original = await service.load([first, second, third], 'Driving');
    expect(original.first!.points[1], const LatLng(3.25, 101.71));
    expect(routes.calls.map((call) => call.$2.map((point) => point.latitude)), [
      [3.2, 3.3],
      [3.3, 3.4],
    ]);
    await service.load([second, third, first], 'Driving');
    expect(routes.calls.last.$2.map((point) => point.latitude), [3.4, 3.2]);
    expect(routes.calls, hasLength(3));

    final missing = stop('Unknown', '12:00 - 13:00', 0);
    expect(await service.load([first, missing, third], 'Walking'), [
      null,
      null,
    ]);
    expect(await service.load([first, second], 'Public Transport'), [null]);
    expect(routes.calls, hasLength(3));
  });

  test(
    'failed legs can retry and timings report lateness and free time',
    () async {
      final routes = TestRoutes()..fail = true;
      final service = DayRouteService(routes: routes);
      expect(await service.load([first, second], 'Walking'), [null]);
      routes.fail = false;
      final route = (await service.load([first, second], 'Walking')).single!;
      final timing = DayRouteTiming.between(first, second, route)!;
      expect(timing.departure, 630);
      expect(timing.arrival, 651);
      expect(timing.late, 6);
      expect(DayRouteTiming.between(second, third, route)!.waiting, 39);
      expect(routes.calls, hasLength(2));
    },
  );

  testWidgets('shows journey details and opens the fullscreen itinerary', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DayRouteMap(
              stops: [first, second],
              mode: 'Driving',
              service: DayRouteService(routes: TestRoutes()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Day Route Map'), findsOneWidget);
    expect(find.text('1 schedule conflict'), findsOneWidget);
    await tester.tap(find.text('Journey segments'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1. First stop → 2. Second stop'));
    await tester.pumpAndSettle();
    expect(find.text('Open in Google Maps'), findsOneWidget);
    expect(find.text('Open in Waze'), findsOneWidget);
    await tester.tap(find.text('Full Route'));
    await tester.pumpAndSettle();
    expect(find.text('Open in Waze'), findsNothing);

    await tester.tap(find.byTooltip('Open fullscreen map'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Itinerary · 2 stops'));
    await tester.pumpAndSettle();
    expect(find.text('First stop'), findsOneWidget);
    expect(find.text('Travel to Second stop'), findsOneWidget);
  });
}
