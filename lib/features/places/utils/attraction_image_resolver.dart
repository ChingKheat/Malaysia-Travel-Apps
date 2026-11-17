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
        'curated_kl_10' ||
        'wikidata_Q2660049' => 'assets/recognition/kl_bird_park.jpg',
        'curated_kl_13' ||
        'wikidata_Q3330187' => 'assets/recognition/islamic_arts_museum.jpg',
        _ => null,
      };

  static ({String author, String source})? photoCredit(Attraction attraction) =>
      switch (attraction.xid) {
        'curated_kl_10' || 'wikidata_Q2660049' => (
          author: 'David Berkowitz',
          source: 'https://www.flickr.com/photos/davidberkowitz/9051999114/',
        ),
        'curated_kl_13' || 'wikidata_Q3330187' => (
          author: 'travelourplanet.com',
          source: 'https://www.flickr.com/photos/travelourplanet/14968692917/',
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
