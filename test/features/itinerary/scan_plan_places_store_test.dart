import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/services/scan_plan_places_store.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';

void main() {
  test('Scan plan places are deduplicated and scoped to the user', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ScanPlanPlacesStore('scan-plan-first');
    final second = ScanPlanPlacesStore('scan-plan-second');
    const place = Attraction(
      xid: 'google_place123',
      name: 'KLCC Park',
      latitude: 3.15,
      longitude: 101.71,
      category: 'Park',
    );

    expect(await first.add(place), true);
    expect(await first.add(place), false);
    expect(
      await first.add(
        const Attraction(
          xid: 'scan_klcc_park',
          name: 'KLCC Park',
          latitude: 3.15,
          longitude: 101.71,
          category: 'Park',
        ),
      ),
      false,
    );
    expect(first.places.map((item) => item.name), ['KLCC Park']);
    await second.load();
    expect(second.places, isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('scan_plan_places:scan-plan-first'),
      contains('KLCC Park'),
    );
    await first.remove(place.xid);
    expect(first.places, isEmpty);
  });
}
