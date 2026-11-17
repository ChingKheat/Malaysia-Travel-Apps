import 'package:smart_travel_planner/features/places/utils/attraction_image_resolver.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';

/// Provides rich offline metadata, addresses, tips, and gallery photos
/// for curated Malaysian attractions and smart fallbacks for dynamic places.
class AttractionMetadataResolver {
  const AttractionMetadataResolver._();

  /// Resolves the most accurate address available.
  /// Prioritizes live Google address, matches known Malaysian landmarks,
  /// or returns a graceful region/coordinate fallback.
  static String resolveAddress(Attraction a, [String? googleAddress]) {
    if (googleAddress != null && googleAddress.trim().isNotEmpty) {
      return googleAddress.trim();
    }
    return 'Address unavailable.';
  }

  static String resolveState(Attraction a) {
    final xid = a.xid.toLowerCase();
    if (xid.contains('_kl_')) return 'Kuala Lumpur';
    if (xid.contains('_penang_')) return 'Penang';
    if (xid.contains('_melaka_')) return 'Melaka';
    if (xid.contains('_langkawi_')) return 'Kedah (Langkawi)';
    if (xid.contains('_sabah_')) return 'Sabah';
    if (xid.contains('_sarawak_')) return 'Sarawak';
    if (xid.contains('_ipoh_')) return 'Perak';
    if (xid.contains('_johor_')) return 'Johor';

    final name = a.name.toLowerCase();
    if (name.contains('batu caves') ||
        name.contains('sunway') ||
        name.contains('shah alam')) {
      return 'Selangor';
    }
    if (name.contains('penang') || name.contains('george town')) {
      return 'Penang';
    }
    if (name.contains('melaka') || name.contains('malacca')) return 'Melaka';
    if (name.contains('langkawi')) return 'Kedah';
    if (name.contains('sabah') || name.contains('kinabalu')) return 'Sabah';
    if (name.contains('sarawak') || name.contains('kuching')) return 'Sarawak';
    if (name.contains('ipoh') || name.contains('perak')) return 'Perak';
    if (name.contains('johor') || name.contains('legoland')) return 'Johor';
    if (name.contains('putrajaya')) return 'Putrajaya';

    return 'Kuala Lumpur';
  }

  /// Uses only a photo explicitly attached to this attraction.
  static List<String> resolveGallery(Attraction a) {
    final photo = AttractionImageResolver.resolvePhotoUrl(a);
    return photo == null ? [] : [photo];
  }

  /// Estimated duration for visiting.
  static String resolveDuration(Attraction a) {
    final name = a.name.toLowerCase();
    final cat = a.category.toLowerCase();

    if (name.contains('batu caves')) return '2 – 3 hours';
    if (name.contains('twin towers')) return '1.5 – 2 hours';
    if (name.contains('legoland') || name.contains('sunway')) {
      return '4 – 6 hours';
    }
    if (name.contains('kinabalu')) return 'Half day (4+ hrs)';
    if (name.contains('bird park') || name.contains('aquaria')) {
      return '2 – 3 hours';
    }
    if (name.contains('central market') || name.contains('jalan alor')) {
      return '1.5 – 2 hours';
    }

    if (cat.contains('museum') || cat.contains('temple')) return '1 – 2 hours';
    if (cat.contains('food') || cat.contains('dining')) return '1 – 1.5 hours';
    if (cat.contains('park') || cat.contains('nature')) return '2 – 3 hours';
    return '1 – 2 hours';
  }

  /// Atmosphere / Setting badge.
  static String resolveAtmosphere(Attraction a) {
    if (a.isIndoor == true) return 'Indoor / AC';
    if (a.isIndoor == false) return 'Outdoor';

    final name = a.name.toLowerCase();
    final cat = a.category.toLowerCase();
    if (name.contains('cave')) return 'Outdoor & Cave';
    if (name.contains('mall') ||
        name.contains('pavilion') ||
        name.contains('museum') ||
        name.contains('aquaria')) {
      return 'Indoor (Air-con)';
    }
    if (cat.contains('park') ||
        cat.contains('nature') ||
        cat.contains('street') ||
        cat.contains('beach')) {
      return 'Outdoor';
    }
    return 'Covered & Open-air';
  }

  /// Admission / Entry requirement hint.
  static String resolveAdmission(Attraction a) {
    final name = a.name.toLowerCase();
    if (name.contains('batu caves')) return 'Free Admission (Main Cave)';
    if (name.contains('merdeka square') ||
        name.contains('jalan alor') ||
        name.contains('saloma') ||
        name.contains('thean hou')) {
      return 'Free Entry';
    }
    if (name.contains('twin towers') ||
        name.contains('kl tower') ||
        name.contains('aquaria') ||
        name.contains('legoland') ||
        name.contains('bird park')) {
      return 'Ticketed';
    }
    return 'General Access';
  }

  static String resolveDescription(
    Attraction a, [
    String? googleDescription,
    double? rating,
    int? reviewCount,
  ]) {
    if (googleDescription != null &&
        googleDescription.trim().isNotEmpty &&
        !googleDescription.toLowerCase().contains('unavailable')) {
      return googleDescription.trim();
    }

    if (a.description != null &&
        a.description!.trim().isNotEmpty &&
        !a.description!.toLowerCase().contains('unavailable')) {
      return a.description!.trim();
    }

    return 'Description unavailable.';
  }

  static List<String> resolveTips(Attraction a) {
    final name = a.name.toLowerCase();
    final cat = a.category.toLowerCase();

    if (name.contains('batu caves') || name.contains('murugan')) {
      return const [
        'Modest attire required: shoulders and knees must be covered to enter the sacred Cathedral Cave.',
        'Be prepared for a workout: climb 272 vibrant rainbow steps guarded by the 42.7m golden Murugan statue.',
        'Watch out for wild macaques: keep food, water bottles, and sunglasses secured in your bag.',
        'Best time to visit is early morning (around 8:00 AM) to beat the tropical midday heat and tour bus crowds.',
      ];
    }
    if (name.contains('twin towers') ||
        name.contains('klcc') ||
        name.contains('petronas')) {
      return const [
        'Pre-booking tickets online is strongly advised as daily observation deck time slots sell out.',
        'Catch the free Lake Symphony light & water fountain show at KLCC Park every evening (8:00 PM & 9:00 PM).',
        'Best exterior photo spot is from across the road near the fountain edge with ultra-wide angle.',
      ];
    }
    if (name.contains('thean hou')) {
      return const [
        'Spectacular panoramic views of the Kuala Lumpur skyline from the upper levels.',
        'Thousands of traditional red hanging lanterns make it a magical spot for sunset and night photos.',
        'Please remove shoes when entering inner prayer halls.',
      ];
    }
    if (name.contains('central market') || name.contains('pasar seni')) {
      return const [
        'A great air-conditioned heritage hub for Malaysian batik, pewter souvenirs, and local woodcarvings.',
        'Conveniently connected right opposite the Pasar Seni LRT and MRT interchange station.',
        'Check out the food court upstairs for traditional curry laksa, cendol, and local delicacies.',
      ];
    }
    if (name.contains('jalan alor')) {
      return const [
        'The street comes alive after 6:30 PM with bustling open-air dining stalls.',
        'Famous must-tries: grilled chicken wings at Wong Ah Wah, satay skewers, and crispy salted egg seafood.',
        'Cash and local DuitNow QR payments are widely accepted.',
      ];
    }
    if (cat.contains('religion') ||
        cat.contains('temple') ||
        cat.contains('mosque') ||
        cat.contains('church')) {
      return const [
        'Respectful attire is requested: cover shoulders and knees, and remove footwear where indicated.',
        'Quiet observation is appreciated during active prayer or worship hours.',
      ];
    }
    if (cat.contains('park') ||
        cat.contains('nature') ||
        cat.contains('garden')) {
      return const [
        'Wear comfortable walking shoes, stay hydrated, and bring mosquito repellent.',
        'Tropical showers often occur in late afternoon; consider carrying a compact umbrella.',
      ];
    }
    if (cat.contains('food') ||
        cat.contains('dining') ||
        cat.contains('market')) {
      return const [
        'Peak dining hours are between 7:00 PM and 9:00 PM.',
        'Local e-wallets (Touch \'n Go / DuitNow) and cash are the most convenient payment methods.',
      ];
    }

    return const [
      'Check local operating hours before planning your journey, especially during public holidays.',
      'Comfortable walking footwear and hydration are recommended when exploring.',
    ];
  }
}
