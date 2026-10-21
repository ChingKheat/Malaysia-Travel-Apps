import 'package:flutter/material.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';

class AttractionListScreen extends StatelessWidget {
  const AttractionListScreen({
    super.key,
    required this.attractions,
    required this.selectedStops,
    required this.onAttractionTap,
    required this.onToggleStop,
  });

  final List<Attraction> attractions;
  final List<Attraction> selectedStops;
  final ValueChanged<Attraction> onAttractionTap;
  final ValueChanged<Attraction> onToggleStop;

  @override
  Widget build(BuildContext context) {
    if (attractions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 64,
                color: AppColors.primary.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 16),
              const Text(
                'No attractions found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'No attractions match your current search or category filter. Try clearing your search keyword, choosing another category, or selecting a different location area above.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
      itemCount: attractions.length,
      itemBuilder: (context, index) {
        final attraction = attractions[index];
        final selected = selectedStops.any(
          (item) => item.xid == attraction.xid,
        );

        return ModernAttractionCard(
          attraction: attraction,
          selected: selected,
          onTap: () => onAttractionTap(attraction),
          onToggle: () => onToggleStop(attraction),
        );
      },
    );
  }
}

class ModernAttractionCard extends StatelessWidget {
  const ModernAttractionCard({
    super.key,
    required this.attraction,
    required this.selected,
    required this.onTap,
    required this.onToggle,
  });

  final Attraction attraction;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final (catColor, catIcon, catLabel) = _getCategoryMeta(attraction.category);
    final resolvedPhoto = _resolvePhotoUrl(attraction);
    final hasValidPhoto = resolvedPhoto != null && resolvedPhoto.startsWith('http');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? AppColors.primary : const Color(0xFFE8ECF4),
          width: selected ? 1.6 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: selected ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left Visual Thumbnail (80 x 80)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: hasValidPhoto
                        ? Image.network(
                            resolvedPhoto,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildFallbackThumbnail(catColor, catIcon),
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return _buildFallbackThumbnail(catColor, catIcon);
                            },
                          )
                        : _buildFallbackThumbnail(catColor, catIcon),
                  ),
                ),
                const SizedBox(width: 12),

                // Center Content Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Row: Category Chip & Indoor/Outdoor tag
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(catIcon, size: 11, color: catColor),
                                  const SizedBox(width: 3.5),
                                  Flexible(
                                    child: Text(
                                      catLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: catColor,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (attraction.isIndoor != null) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: attraction.isIndoor!
                                    ? const Color(0xFFEFF6FF)
                                    : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                attraction.isIndoor! ? '🏢 Indoor' : '🌤️ Outdoor',
                                style: TextStyle(
                                  color: attraction.isIndoor!
                                      ? const Color(0xFF1D4ED8)
                                      : const Color(0xFFB45309),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Title
                      Text(
                        attraction.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          height: 1.22,
                        ),
                      ),
                      const SizedBox(height: 5),

                      // Rating & Distance Row
                      Row(
                        children: [
                          if (attraction.rating != null) ...[
                            const Icon(
                              Icons.star_rounded,
                              size: 15,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              attraction.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            if (attraction.userRatingsTotal != null &&
                                attraction.userRatingsTotal! > 0)
                              Text(
                                ' (${_formatReviews(attraction.userRatingsTotal!)})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            const Text(
                              ' • ',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          const Icon(
                            Icons.near_me_outlined,
                            size: 12,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 2.5),
                          Expanded(
                            child: Text(
                              _distanceLabel(attraction.distanceMeters),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Right Action Pill Button (+ Add / ✓ Added)
                GestureDetector(
                  onTap: onToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6.5,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selected
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_add_outlined,
                          size: 14,
                          color: selected ? Colors.white : AppColors.primary,
                        ),
                        const SizedBox(width: 3.5),
                        Text(
                          selected ? 'Saved' : 'Save',
                          style: TextStyle(
                            color: selected ? Colors.white : AppColors.primary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackThumbnail(Color catColor, IconData catIcon) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            catColor.withValues(alpha: 0.85),
            catColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          catIcon,
          size: 34,
          color: Colors.white.withValues(alpha: 0.95),
        ),
      ),
    );
  }

  static (Color, IconData, String) _getCategoryMeta(String category) {
    final kind = category.toLowerCase();
    if (kind.contains('food') ||
        kind.contains('cafe') ||
        kind.contains('restaurant') ||
        kind.contains('bakery') ||
        kind.contains('hawker')) {
      return (const Color(0xFFEA580C), Icons.restaurant_rounded, 'Food');
    }
    if (kind.contains('shop') ||
        kind.contains('mall') ||
        kind.contains('market') ||
        kind.contains('store')) {
      return (const Color(0xFFDB2777), Icons.shopping_bag_rounded, 'Shopping');
    }
    if (kind.contains('natural') ||
        kind.contains('park') ||
        kind.contains('nature') ||
        kind.contains('garden') ||
        kind.contains('forest') ||
        kind.contains('beach')) {
      return (const Color(0xFF059669), Icons.park_rounded, 'Nature');
    }
    if (kind.contains('museum') || kind.contains('gallery')) {
      return (const Color(0xFF4F46E5), Icons.museum_rounded, 'Museum');
    }
    if (kind.contains('planetarium')) {
      return (const Color(0xFF2563EB), Icons.public_rounded, 'Science');
    }
    if (kind.contains('religion') ||
        kind.contains('temple') ||
        kind.contains('mosque') ||
        kind.contains('church')) {
      return (
        const Color(0xFF0D9488),
        Icons.account_balance_rounded,
        'Culture',
      );
    }
    if (kind.contains('historic') ||
        kind.contains('architecture') ||
        kind.contains('landmark') ||
        kind.contains('monument') ||
        kind.contains('sights')) {
      return (const Color(0xFF7C3AED), Icons.castle_rounded, 'Sight');
    }
    final raw =
        category.isEmpty ? 'Attraction' : category.split(',').first.trim();
    final cleanLabel =
        raw.toLowerCase() == 'tourist attraction' ? 'Attraction' : raw;
    return (
      AppColors.primary,
      Icons.place_rounded,
      cleanLabel,
    );
  }

  static String _formatReviews(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return '$count';
  }

  static String _distanceLabel(double? meters) {
    if (meters == null) return 'Nearby';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  static String? _resolvePhotoUrl(Attraction attraction) {
    final direct = attraction.photoUrl?.split('|').firstOrNull?.trim();
    if (direct != null && direct.startsWith('http')) return direct;

    final name = attraction.name.toLowerCase();
    final cat = attraction.category.toLowerCase();

    // Specific landmark matching
    if (name.contains('national museum') || name.contains('muzium negara')) {
      return 'https://images.unsplash.com/photo-1596422846543-75c6fc197f07?w=400&auto=format&fit=crop&q=75';
    }
    if (name.contains('bamboo') || name.contains('playhouse')) {
      return 'https://images.unsplash.com/photo-1542273917363-3b1817f69a2d?w=400&auto=format&fit=crop&q=75';
    }
    if (name.contains('water jet') ||
        name.contains('fountain') ||
        name.contains('lake')) {
      return 'https://images.unsplash.com/photo-1513836279014-a89f7a76ae86?w=400&auto=format&fit=crop&q=75';
    }
    if (name.contains('orchid') ||
        name.contains('flower') ||
        name.contains('garden')) {
      return 'https://images.unsplash.com/photo-1585320806297-9794b3e4eeae?w=400&auto=format&fit=crop&q=75';
    }
    if (name.contains('gallery') || name.contains('wei-ling')) {
      return 'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?w=400&auto=format&fit=crop&q=75';
    }
    if (name.contains('orang asli') || name.contains('craft')) {
      return 'https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=400&auto=format&fit=crop&q=75';
    }
    if (name.contains('etnologi') || name.contains('ethnology')) {
      return 'https://images.unsplash.com/photo-1582555172866-f73bb12a2ab3?w=400&auto=format&fit=crop&q=75';
    }
    if (name.contains('planetarium') || name.contains('astronomy')) {
      return 'https://images.unsplash.com/photo-1506703719100-a0f3a48c0f86?w=400&auto=format&fit=crop&q=75';
    }
    if (name.contains('twin towers') ||
        name.contains('klcc') ||
        name.contains('petronas')) {
      return 'https://images.unsplash.com/photo-1596436889106-be35e843f974?w=400&auto=format&fit=crop&q=75';
    }
    if (name.contains('batu caves') || name.contains('murugan')) {
      return 'https://images.unsplash.com/photo-1544644181-1484b3fdfc62?w=400&auto=format&fit=crop&q=75';
    }
    if (name.contains('thean hou')) {
      return 'https://images.unsplash.com/photo-1548013146-72479768bada?w=400&auto=format&fit=crop&q=75';
    }
    if (name.contains('bird park') ||
        name.contains('aquaria') ||
        name.contains('zoo')) {
      return 'https://images.unsplash.com/photo-1552728089-57bdde30beb3?w=400&auto=format&fit=crop&q=75';
    }
    if (name.contains('central market') ||
        name.contains('pasar seni') ||
        name.contains('petaling')) {
      return 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=400&auto=format&fit=crop&q=75';
    }

    // Category-based high-res photo fallbacks
    if (cat.contains('museum') ||
        cat.contains('gallery') ||
        cat.contains('art')) {
      return 'https://images.unsplash.com/photo-1565008447742-97f6f38c985c?w=400&auto=format&fit=crop&q=75';
    }
    if (cat.contains('food') ||
        cat.contains('restaurant') ||
        cat.contains('cafe') ||
        cat.contains('dining') ||
        cat.contains('hawker') ||
        cat.contains('bakery')) {
      return 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400&auto=format&fit=crop&q=75';
    }
    if (cat.contains('shop') ||
        cat.contains('mall') ||
        cat.contains('market') ||
        cat.contains('store')) {
      return 'https://images.unsplash.com/photo-1567449303078-57ad995bd301?w=400&auto=format&fit=crop&q=75';
    }
    if (cat.contains('park') ||
        cat.contains('nature') ||
        cat.contains('natural') ||
        cat.contains('garden') ||
        cat.contains('forest') ||
        cat.contains('beach')) {
      return 'https://images.unsplash.com/photo-1448375240586-882707db888b?w=400&auto=format&fit=crop&q=75';
    }
    if (cat.contains('religion') ||
        cat.contains('temple') ||
        cat.contains('mosque') ||
        cat.contains('church') ||
        cat.contains('cultural')) {
      return 'https://images.unsplash.com/photo-1548013146-72479768bada?w=400&auto=format&fit=crop&q=75';
    }
    if (cat.contains('sight') ||
        cat.contains('landmark') ||
        cat.contains('monument') ||
        cat.contains('historic') ||
        cat.contains('tower')) {
      return 'https://images.unsplash.com/photo-1518684079-3c830dcef090?w=400&auto=format&fit=crop&q=75';
    }
    return null;
  }
}
