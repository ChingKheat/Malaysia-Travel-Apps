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
        'curated_kl_04' ||
        'wikidata_Q19840251' => 'assets/recognition/jalan_alor.jpg',
        'curated_kl_05' ||
        'wikidata_Q7777247' => 'assets/recognition/thean_hou_temple.jpg',
        'curated_kl_06' ||
        'wikidata_Q744713' => 'assets/recognition/kl_tower.jpg',
        'curated_kl_07' ||
        'wikidata_Q1041178' => 'assets/recognition/petaling_street.jpg',
        'curated_kl_08' ||
        'wikidata_Q7155877' => 'assets/recognition/pavilion_kl.jpg',
        'curated_kl_09' || 'wikidata_Q12061078' =>
          'assets/recognition/perdana_botanical_gardens.jpg',
        'curated_kl_10' ||
        'wikidata_Q2660049' => 'assets/recognition/kl_bird_park.jpg',
        'curated_kl_11' ||
        'wikidata_Q4782782' => 'assets/recognition/aquaria_klcc.jpg',
        'curated_kl_12' ||
        'wikidata_Q1544487' ||
        'wikidata_Q6819001' => 'assets/recognition/merdeka_square.jpg',
        'curated_kl_13' ||
        'wikidata_Q3330187' => 'assets/recognition/islamic_arts_museum.jpg',
        'curated_kl_14' => 'assets/recognition/saloma_link_bridge.jpg',
        'curated_kl_15' => 'assets/recognition/kwai_chai_hong.jpg',
        'curated_johor_01' => 'assets/recognition/legoland_malaysia.jpg',
        'curated_johor_02' => 'assets/recognition/tan_hiok_nee.jpg',
        'curated_johor_03' ||
        'wikidata_Q2478866' => 'assets/recognition/sultan_abu_bakar_mosque.jpg',
        'curated_johor_04' || 'wikidata_Q4802043' =>
          'assets/recognition/rajakaliamman_glass_temple.jpg',
        'curated_johor_05' ||
        'wikidata_Q28219616' => 'assets/recognition/johor_zoo.jpg',
        'curated_johor_06' => 'assets/recognition/danga_bay_waterfront.jpg',
        'curated_johor_07' => 'assets/recognition/pasar_karat.jpg',
        'curated_johor_08' =>
          'assets/recognition/johor_heritage_food_trail.jpg',
        'curated_johor_09' => 'assets/recognition/puteri_harbour.jpg',
        'curated_johor_10' => 'assets/recognition/kota_tinggi_waterfalls.jpg',
        'curated_johor_11' => 'assets/recognition/desaru_beach.jpg',
        'curated_johor_12' => 'assets/recognition/johor_premium_outlets.jpg',
        'curated_johor_13' => 'assets/recognition/mid_valley_southkey.jpg',
        'curated_johor_14' =>
          'assets/recognition/johor_chinese_heritage_museum.jpg',
        'curated_johor_15' => 'assets/recognition/johor_bahru_city_square.jpg',
        _ => null,
      };

  static ({String author, String license, String source})? photoCredit(
    Attraction attraction,
  ) => switch (attraction.xid) {
    'curated_kl_04' || 'wikidata_Q19840251' => (
      author: 'Alexander Synaptic',
      license: 'CC BY-SA 4.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Jalan_Alor_Kuala_Lumpur.jpg',
    ),
    'curated_kl_05' || 'wikidata_Q7777247' => (
      author: 'Alexey Komarov',
      license: 'CC BY-SA 4.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Thean_Hou_Temple,_Kuala_Lumpur-3.jpg',
    ),
    'curated_kl_06' || 'wikidata_Q744713' => (
      author: 'Salmiah La Suma',
      license: 'CC BY-SA 4.0',
      source:
          'https://commons.wikimedia.org/wiki/File:KL_Tower,_Kuala_Lumpur,_Malaysia.jpg',
    ),
    'curated_kl_07' || 'wikidata_Q1041178' => (
      author: 'Shesmax',
      license: 'CC BY-SA 4.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Kuala_Lumpur._Jalan_Petaling._2019-12-07_16-40-19.jpg',
    ),
    'curated_kl_08' || 'wikidata_Q7155877' => (
      author: '*angys*',
      license: 'CC BY-SA 4.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Pavilion_KL_outview_2_(211030).jpg',
    ),
    'curated_kl_10' || 'wikidata_Q2660049' => (
      author: 'David Berkowitz',
      license: 'CC BY 2.0',
      source: 'https://www.flickr.com/photos/davidberkowitz/9051999114/',
    ),
    'curated_kl_11' || 'wikidata_Q4782782' => (
      author: 'Phalinn Ooi',
      license: 'CC BY 2.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Underwater_tunnel_in_Aquaria_KLCC.jpg',
    ),
    'curated_kl_12' || 'wikidata_Q1544487' || 'wikidata_Q6819001' => (
      author: 'Marcin Konsek',
      license: 'CC BY-SA 4.0',
      source:
          'https://commons.wikimedia.org/wiki/File:2016_Kuala_Lumpur,_Budynek_Su%C5%82tana_Abdula_Samada_(01).jpg',
    ),
    'curated_kl_13' || 'wikidata_Q3330187' => (
      author: 'travelourplanet.com',
      license: 'CC BY 2.0',
      source: 'https://www.flickr.com/photos/travelourplanet/14968692917/',
    ),
    'curated_kl_14' => (
      author: 'Renek78',
      license: 'CC BY-SA 4.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Saloma_Link_Bridge_04.jpg',
    ),
    'curated_kl_15' => (
      author: 'Slleong',
      license: 'CC0 1.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Kwai_Chai_Hong_3.jpg',
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
    'curated_johor_06' => (
      author: 'derek2688',
      license: 'CC BY 3.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Danga_bay_-_walkway_by_the_sea_-_panoramio.jpg',
    ),
    'curated_johor_07' => (
      author: 'poya',
      license: 'CC BY 3.0',
      source:
          'https://commons.wikimedia.org/wiki/File:JB_Bazar.JPG',
    ),
    'curated_johor_08' => (
      author: 'Paul Ng',
      license: 'CC BY-SA 2.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Breakfast_tour_of_JB_old_town_-_Flickr.jpg',
    ),
    'curated_johor_09' => (
      author: 'Mohd Fazlin Mohd Effendy Ooi',
      license: 'CC BY 2.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Puteri_Harbour_in_Johor%2C_Malaysia.jpg',
    ),
    'curated_johor_10' => (
      author: 'Nicolas Lannuzel',
      license: 'CC BY-SA 2.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Kota_Tinggi_waterfalls_-_Flickr.jpg',
    ),
    'curated_johor_11' => (
      author: 'Chongkian',
      license: 'CC BY-SA 4.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Desaru_Beach.jpg',
    ),
    'curated_johor_12' => (
      author: 'Chongkian',
      license: 'CC BY-SA 4.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Johor_Premium_Outlets.jpg',
    ),
    'curated_johor_13' => (
      author: 'Chongkian',
      license: 'CC BY-SA 4.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Mid_Valley_Southkey.jpg',
    ),
    'curated_johor_14' => (
      author: 'Ralff Nestor Nacor',
      license: 'CC BY-SA 4.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Johor_Bahru_Chinese_Heritage_Museum%2C_Malaysia.jpg',
    ),
    'curated_johor_15' => (
      author: 'Ralff Nestor Nacor',
      license: 'CC BY-SA 4.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Johor_Bahru_City_Square%2C_Malaysia.jpg',
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
