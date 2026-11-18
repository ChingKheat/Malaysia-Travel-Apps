import '../../../core/config/supabase_config.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';

/// Photos explicitly associated with a place.
class AttractionImageResolver {
  const AttractionImageResolver._();
  static String? resolveAsset(Attraction attraction) =>
      switch (attraction.xid) {
        'curated_kl_01' ||
        'wikidata_Q83063' => 'assets/recognition/petronas.jpg',
        'curated_kl_02' => 'assets/recognition/batu_caves.jpg',
        'curated_kl_03' ||
        'wikidata_Q1041262' => 'assets/recognition/central_market.jpg',
        'curated_kl_09' || 'wikidata_Q12061078' =>
          'assets/recognition/perdana_botanical_gardens.jpg',
        'curated_kl_10' ||
        'wikidata_Q2660049' => 'assets/recognition/kl_bird_park.jpg',
        'curated_kl_13' ||
        'wikidata_Q3330187' => 'assets/recognition/islamic_arts_museum.jpg',
        'curated_johor_01' => 'assets/recognition/legoland_malaysia.jpg',
        'curated_johor_02' => 'assets/recognition/tan_hiok_nee.jpg',
        'curated_johor_03' ||
        'wikidata_Q2478866' => 'assets/recognition/sultan_abu_bakar_mosque.jpg',
        'curated_johor_04' || 'wikidata_Q4802043' =>
          'assets/recognition/rajakaliamman_glass_temple.jpg',
        'curated_johor_05' ||
        'wikidata_Q28219616' => 'assets/recognition/johor_zoo.jpg',
        _ => null,
      };

  static ({String author, String license, String source})? photoCredit(
    Attraction attraction,
  ) => switch (attraction.xid) {
    'curated_kl_10' || 'wikidata_Q2660049' => (
      author: 'David Berkowitz',
      license: 'CC BY 2.0',
      source: 'https://www.flickr.com/photos/davidberkowitz/9051999114/',
    ),
    'curated_kl_13' || 'wikidata_Q3330187' => (
      author: 'travelourplanet.com',
      license: 'CC BY 2.0',
      source: 'https://www.flickr.com/photos/travelourplanet/14968692917/',
    ),
    'curated_johor_01' => (
      author: 'milst1',
      license: 'CC BY-SA 2.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Entrance_Legoland_Malaysia.jpg',
    ),
    'curated_johor_02' => (
      author: 'Ralff Nestor Nacor',
      license: 'CC BY-SA 4.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Jalan_Tan_Hiok_Nee,_JB,_Malaysia.jpg',
    ),
    'curated_johor_03' || 'wikidata_Q2478866' => (
      author: 'Chainwit.',
      license: 'CC BY 4.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Masjid_Sultan_Abu_Bakar,_JB_(2025)_-_img_02.jpg',
    ),
    'curated_johor_04' || 'wikidata_Q4802043' => (
      author: 'Chainwit.',
      license: 'CC BY 4.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Arulmigu_Sri_Rajakaliamman_Glass_Temple,_JB_(2025)_-_img_82.jpg',
    ),
    'curated_johor_05' || 'wikidata_Q28219616' => (
      author: 'Stress 043',
      license: 'CC BY-SA 4.0',
      source: 'https://commons.wikimedia.org/wiki/File:Zoo_Johor_entrance.jpg',
    ),
    _ => null,
  };

  static String? googleProxyLink(String placeId) {
    final base = Uri.tryParse(SupabaseConfig.supabaseUrl);
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        !RegExp(r'^[A-Za-z0-9_-]{5,255}$').hasMatch(placeId)) {
      return null;
    }
    return base
        .resolve('/functions/v1/google-places')
        .replace(queryParameters: {'operation': 'photo', 'placeId': placeId})
        .toString();
  }

  static bool isGoogleProxyLink(String? url, String? placeId) =>
      url != null && placeId != null && url == googleProxyLink(placeId);

  static String? resolvePhotoUrl(Attraction attraction) {
    final direct = attraction.photoUrl?.split('|').firstOrNull?.trim();
    if (isGoogleProxyLink(direct, attraction.googlePlaceId)) return null;
    final uri = Uri.tryParse(direct ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.host.contains('unsplash.com') ||
        uri.host.contains('pexels.com') ||
        uri.host.contains('places.googleapis.com') ||
        uri.queryParameters.containsKey('key')) {
      return null;
    }
    return direct;
  }

  static String? resolveFallbackPhotoUrl(Attraction attraction) => null;
}
