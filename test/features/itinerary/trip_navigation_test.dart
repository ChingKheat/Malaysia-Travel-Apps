import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_navigation.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';

void main() {
  final hotel = TravelStop.fromJson({
    'title': 'Bukit Bintang',
    'latitude': 3.1468,
    'longitude': 101.7113,
  });
  final batuCaves = TravelStop.fromJson({
    'title': 'Batu Caves & temple',
    'latitude': 3.2379,
    'longitude': 101.684,
  });

  test(
    'Moovit carries both endpoints and falls back to Maps transit',
    () async {
      final links = TripNavigation.links(
        TripNavigationMode.moovit,
        hotel,
        batuCaves,
        'Public Transport',
      );
      expect(links.first.queryParameters['orig_lat'], '3.1468');
      expect(links.first.queryParameters['dest_lon'], '101.684');
      expect(links.first.queryParameters['dest_name'], 'Batu Caves & temple');
      final launched = <Uri>[];
      expect(
        await TripNavigation.open(
          links,
          launch: (uri) async {
            launched.add(uri);
            return uri.scheme == 'https';
          },
        ),
        isTrue,
      );
      expect(launched, links);
      expect(launched.last.queryParameters['travelmode'], 'transit');
    },
  );

  test('duration edits preserve coordinates and reject invalid values', () {
    final updated = batuCaves.withVisitMinutes(150);
    expect(updated.visitMinutes, 150);
    expect(updated.latitude, batuCaves.latitude);
    expect(() => batuCaves.withVisitMinutes(29), throwsRangeError);
  });
}
