import 'package:smart_travel_planner/core/config/supabase_config.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';

/// Resolves high-resolution representative photo URLs for attractions.
/// Prioritizes real Supabase Storage photos, matches specific Malaysian landmarks,
/// and falls back gracefully to category-based photography.
class AttractionImageResolver {
  const AttractionImageResolver._();

  static String? resolvePhotoUrl(Attraction attraction) {
    final direct = attraction.photoUrl?.split('|').firstOrNull?.trim();
    if (direct != null && direct.startsWith('http')) return direct;

    final placeId = attraction.googlePlaceId;
    if (placeId != null && placeId.isNotEmpty && SupabaseConfig.isConfigured) {
      return '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/place-photos/$placeId.jpg';
    }

    return resolveFallbackPhotoUrl(attraction);
  }

  static String? resolveFallbackPhotoUrl(Attraction attraction) {
    final name = attraction.name.toLowerCase();
    final cat = attraction.category.toLowerCase();

    // Specific landmark matching across Malaysia
    if (name.contains('twin towers') ||
        name.contains('klcc') ||
        name.contains('petronas')) {
      return 'https://images.unsplash.com/photo-1596436889106-be35e843f974?w=500&auto=format&fit=crop&q=75';
    }
    if (name.contains('batu caves') || name.contains('murugan')) {
      return 'https://images.unsplash.com/photo-1544644181-1484b3fdfc62?w=500&auto=format&fit=crop&q=75';
    }
    if (name.contains('thean hou')) {
      return 'https://images.unsplash.com/photo-1548013146-72479768bada?w=500&auto=format&fit=crop&q=75';
    }
    if (name.contains('george town') ||
        name.contains('street art') ||
        name.contains('penang')) {
      return 'https://images.unsplash.com/photo-1599387737838-892410a5146c?w=500&auto=format&fit=crop&q=75';
    }
    if (name.contains('stadthuys') ||
        name.contains('dutch square') ||
        name.contains('famosa') ||
        name.contains('melaka')) {
      return 'https://images.unsplash.com/photo-1590487988256-9ed24133863e?w=500&auto=format&fit=crop&q=75';
    }
    if (name.contains('sky bridge') ||
        name.contains('skycab') ||
        name.contains('langkawi')) {
      return 'https://images.unsplash.com/photo-1518684079-3c830dcef090?w=500&auto=format&fit=crop&q=75';
    }
    if (name.contains('kinabalu') || name.contains('sabah')) {
      return 'https://images.unsplash.com/photo-1548013146-72479768bada?w=500&auto=format&fit=crop&q=75';
    }
    if (name.contains('tea') || name.contains('cameron')) {
      return 'https://images.unsplash.com/photo-1542273917363-3b1817f69a2d?w=500&auto=format&fit=crop&q=75';
    }
    if (name.contains('jalan alor') || name.contains('food street')) {
      return 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=500&auto=format&fit=crop&q=75';
    }
    if (name.contains('kl tower') || name.contains('menara kuala lumpur')) {
      return 'https://images.unsplash.com/photo-1518684079-3c830dcef090?w=500&auto=format&fit=crop&q=75';
    }
    if (name.contains('central market') ||
        name.contains('pasar seni') ||
        name.contains('petaling')) {
      return 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=500&auto=format&fit=crop&q=75';
    }
    if (name.contains('bird park') ||
        name.contains('aquaria') ||
        name.contains('zoo')) {
      return 'https://images.unsplash.com/photo-1552728089-57bdde30beb3?w=500&auto=format&fit=crop&q=75';
    }
    if (name.contains('national museum') || name.contains('muzium negara')) {
      return 'https://images.unsplash.com/photo-1596422846543-75c6fc197f07?w=500&auto=format&fit=crop&q=75';
    }

    // Category-based high-res photo fallbacks
    if (cat.contains('museum') ||
        cat.contains('gallery') ||
        cat.contains('art')) {
      return 'https://images.unsplash.com/photo-1565008447742-97f6f38c985c?w=500&auto=format&fit=crop&q=75';
    }
    if (cat.contains('food') ||
        cat.contains('restaurant') ||
        cat.contains('cafe') ||
        cat.contains('dining') ||
        cat.contains('hawker') ||
        cat.contains('bakery')) {
      return 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=500&auto=format&fit=crop&q=75';
    }
    if (cat.contains('shop') ||
        cat.contains('mall') ||
        cat.contains('market') ||
        cat.contains('store')) {
      return 'https://images.unsplash.com/photo-1567449303078-57ad995bd301?w=500&auto=format&fit=crop&q=75';
    }
    if (cat.contains('park') ||
        cat.contains('nature') ||
        cat.contains('natural') ||
        cat.contains('garden') ||
        cat.contains('forest') ||
        cat.contains('beach')) {
      return 'https://images.unsplash.com/photo-1448375240586-882707db888b?w=500&auto=format&fit=crop&q=75';
    }
    if (cat.contains('religion') ||
        cat.contains('temple') ||
        cat.contains('mosque') ||
        cat.contains('church') ||
        cat.contains('cultural')) {
      return 'https://images.unsplash.com/photo-1548013146-72479768bada?w=500&auto=format&fit=crop&q=75';
    }
    if (cat.contains('sight') ||
        cat.contains('landmark') ||
        cat.contains('monument') ||
        cat.contains('historic') ||
        cat.contains('tower') ||
        cat.contains('attraction') ||
        cat.contains('history')) {
      return 'https://images.unsplash.com/photo-1518684079-3c830dcef090?w=500&auto=format&fit=crop&q=75';
    }
    if (cat.contains('family') ||
        cat.contains('adventure') ||
        cat.contains('entertainment') ||
        cat.contains('theme park')) {
      return 'https://images.unsplash.com/photo-1513889961551-628c1e5e2ee9?w=500&auto=format&fit=crop&q=75';
    }
    if (cat.contains('night') || cat.contains('bar') || cat.contains('club')) {
      return 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=75';
    }

    return 'https://images.unsplash.com/photo-1596422846543-75c6fc197f07?w=500&auto=format&fit=crop&q=75';
  }
}
