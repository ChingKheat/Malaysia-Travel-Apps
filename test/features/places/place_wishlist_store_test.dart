import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/places/services/place_wishlist_store.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('wishlist persists places and separates users', () async {
    SharedPreferences.setMockInitialValues({});
    final place = Attraction(
      xid: 'google_test_place',
      name: 'Test Garden',
      latitude: 2.91,
      longitude: 101.68,
      category: 'Park',
      description: 'A garden',
    );
    final first = PlaceWishlistStore('first');
    await first.toggle(place);
    final saved = await PlaceWishlistStore('first').load();
    expect(saved.single.name, 'Test Garden');
    expect(saved.single.latitude, 2.91);
    expect(await PlaceWishlistStore('second').load(), isEmpty);
    await first.toggle(place);
    expect(await first.load(), isEmpty);
  });

  test('old Scan bookmarks appear in the wishlist once', () async {
    SharedPreferences.setMockInitialValues({
      'visual_scan_saved_spots:traveler': ['curated_kl_01'],
      'place_wishlist:traveler': '[]',
    });
    final store = PlaceWishlistStore('traveler');
    final first = await store.load();
    expect(first.single.name, contains('Petronas Twin Towers'));
    expect(await store.load(), hasLength(1));
    await store.toggle(first.single);
    expect(await store.load(), isEmpty);
  });
}
