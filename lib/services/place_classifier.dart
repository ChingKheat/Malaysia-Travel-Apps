/// Utility for automatic classification of places into Indoor or Outdoor,
/// or leaving ambiguous places as null for manual review.
class PlaceClassifier {
  /// Returns `true` for indoor, `false` for outdoor, or `null` for ambiguous/needs review.
  static bool? classify({required String category, required String name}) {
    final cat = category.toLowerCase().trim();
    final nm = name.toLowerCase().trim();

    // 1. PRIMARY CHECK: Indoor categories (Food, Dining, Museums, Shopping, Hospitality)
    const indoorCats = [
      'restaurant',
      'cafe',
      'coffee',
      'bakery',
      'food court',
      'hawker',
      'diner',
      'bar',
      'bistro',
      'buffet',
      'eatery',
      'museum',
      'art gallery',
      'gallery',
      'aquarium',
      'shopping mall',
      'mall',
      'supermarket',
      'department store',
      'store',
      'shop',
      'hotel',
      'resort',
      'cinema',
      'theater',
      'library',
      'indoor',
      'bowling',
      'gym',
      'spa',
    ];
    for (final kw in indoorCats) {
      if (cat.contains(kw)) return true;
    }

    // 2. PRIMARY CHECK: Outdoor categories (Nature, Beaches, Parks, Hiking)
    const outdoorCats = [
      'beach',
      'botanical garden',
      'garden',
      'hiking',
      'nature',
      'scenic',
      'waterfall',
      'mountain',
      'hill',
      'peak',
      'forest',
      'woods',
      'jungle',
      'camp',
      'zoo',
      'safari',
      'wildlife',
      'farm',
      'plantation',
      'lookout',
      'lake',
      'river',
      'island',
      'pier',
      'jetty',
      'bridge',
    ];
    for (final kw in outdoorCats) {
      if (cat.contains(kw)) return false;
    }

    if (cat == 'park' || cat.contains('park')) {
      return false;
    }

    // 3. SECONDARY CHECK for Ambiguous categories (Tourist attraction, Historical landmark, etc.)
    // Check indoor name keywords first
    const indoorNames = [
      'museum',
      'muzium',
      'art gallery',
      'gallery',
      'aquarium',
      'shopping mall',
      'mall',
      'plaza',
      'komtar',
      'complex',
      'indoor',
      'cinema',
      'tower',
      'menara',
    ];
    for (final kw in indoorNames) {
      if (nm.contains(kw)) return true;
    }

    // Check outdoor name keywords
    const outdoorNames = [
      'beach',
      'pantai',
      'bay',
      'teluk',
      'waterfall',
      'air terjun',
      'cascade',
      'jeram',
      'hill',
      'bukit',
      'peak',
      'gunung',
      'mountain',
      'botanical garden',
      'forest',
      'hutan',
      'jungle',
      'trail',
      'hiking',
      'walkway',
      'treetop',
      'viewpoint',
      'view point',
      'lookout',
      'viewing deck',
      'viewing area',
      'wave breaker',
      'street art',
      'mural',
      'jetties',
      'jetty',
      'pier',
      'promenade',
      'fort',
      'nature',
    ];
    for (final kw in outdoorNames) {
      if (nm.contains(kw)) return false;
    }

    // 4. Ambiguous / Neutral / Mixed Categories -> Return NULL (Needs manual review)
    // Examples: "Tourist attraction", "Historical landmark", "Place of worship",
    // "Buddhist temple", "Hindu temple", "Church", "Mosque", "Market"
    return null;
  }
}
