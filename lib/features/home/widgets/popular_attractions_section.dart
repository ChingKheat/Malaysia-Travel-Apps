import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/features/places/data/curated_attractions.dart';
import 'package:smart_travel_planner/features/places/screens/attraction_detail_page.dart';
import 'package:smart_travel_planner/features/places/screens/place_detail_page.dart';
import 'package:smart_travel_planner/features/places/utils/attraction_image_resolver.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';
import 'package:smart_travel_planner/shared/widgets/demo_tap.dart';

/// Curated selection of top iconic Malaysian attractions across various states.
final List<Attraction> defaultPopularAttractions = _buildDefaultPopularList();

List<Attraction> _buildDefaultPopularList() {
  const targetXids = [
    'curated_kl_01', // Petronas Twin Towers
    'curated_kl_02', // Batu Caves
    'curated_penang_01', // George Town Street Art
    'curated_melaka_02', // The Stadthuys & Dutch Square
    'curated_langkawi_01', // Langkawi Sky Bridge
    'curated_sabah_01', // Kinabalu National Park
    'curated_kl_04', // Jalan Alor Night Food Street
    'curated_kl_06', // KL Tower
    'curated_ipoh_01', // Concubine Lane
    'curated_johor_01', // Legoland Malaysia Resort
  ];

  final result = <Attraction>[];
  for (final xid in targetXids) {
    final match = curatedMalaysianAttractions
        .where((a) => a.xid == xid)
        .firstOrNull;
    if (match != null) {
      result.add(match);
    }
  }

  // Fallback to first 8 items if target list is incomplete
  if (result.isEmpty) {
    return curatedMalaysianAttractions.take(8).toList();
  }
  return result;
}

/// Popular Attractions discovery carousel for the Home Page with magazine-style cards.
class PopularAttractionsSection extends StatelessWidget {
  const PopularAttractionsSection({
    super.key,
    required this.onSeeAllTap,
    this.attractions,
  });

  final VoidCallback onSeeAllTap;
  final List<Attraction>? attractions;

  void _openAttraction(BuildContext context, Attraction attraction) {
    if (attraction.googlePlaceId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlaceDetailPage(
            stop: TravelStop(
              title: attraction.name,
              time: '',
              note: '',
              description: '',
              duration: '',
              openingHours: 'Hours unverified',
              tips: const [],
              icon: Icons.place,
              color: AppColors.primary,
              placeId: attraction.googlePlaceId,
              latitude: attraction.latitude,
              longitude: attraction.longitude,
              dataSource: 'google',
            ),
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AttractionDetailPage(attraction: attraction),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = attractions ?? defaultPopularAttractions;
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Elevated Header Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF6366F1,
                            ).withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.popularAttractions,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            context.l10n.topMustVisitDestinationsInMalaysia,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                key: const ValueKey('popular-attractions-see-all'),
                onTap: onSeeAllTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.seeAll,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Horizontal Carousel with Editorial Full-Bleed Cards
        SizedBox(
          height: 270,
          child: ListView.separated(
            key: const ValueKey('popular-attractions-list'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final attraction = items[index];
              return PopularAttractionCard(
                attraction: attraction,
                onTap: () => _openAttraction(context, attraction),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Creative full-bleed magazine-style attraction card with frosted glass badges.
class PopularAttractionCard extends StatelessWidget {
  const PopularAttractionCard({
    super.key,
    required this.attraction,
    required this.onTap,
  });

  final Attraction attraction;
  final VoidCallback onTap;

  String _resolveState(Attraction a) {
    final xid = a.xid.toLowerCase();
    if (xid.contains('_kl_')) return 'Kuala Lumpur';
    if (xid.contains('_penang_')) return 'Penang';
    if (xid.contains('_melaka_')) return 'Melaka';
    if (xid.contains('_langkawi_')) return 'Langkawi';
    if (xid.contains('_sabah_')) return 'Sabah';
    if (xid.contains('_sarawak_')) return 'Sarawak';
    if (xid.contains('_ipoh_')) return 'Perak';
    if (xid.contains('_johor_')) return 'Johor';
    return 'Malaysia';
  }

  String _cleanCategory(String raw) {
    final parts = raw.split(',');
    if (parts.isNotEmpty) {
      return parts.first.trim();
    }
    return 'Attraction';
  }

  IconData _categoryIcon(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('food') || c.contains('dining')) {
      return Icons.restaurant_rounded;
    }
    if (c.contains('park') || c.contains('nature')) {
      return Icons.park_rounded;
    }
    if (c.contains('religion') || c.contains('cultural')) {
      return Icons.temple_buddhist_rounded;
    }
    if (c.contains('shop') || c.contains('market')) {
      return Icons.shopping_bag_rounded;
    }
    return Icons.account_balance_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final direct = attraction.photoUrl?.split('|').firstOrNull?.trim();
    final photoUrl = (direct != null && direct.startsWith('http'))
        ? direct
        : AttractionImageResolver.resolvePhotoUrl(attraction);
    final stateName = _resolveState(attraction);
    final cleanCategory = _cleanCategory(attraction.category);
    final categoryIcon = _categoryIcon(attraction.category);
    final rating = (attraction.rating ?? 4.8).toStringAsFixed(1);

    return DemoTapCard(
      onTap: onTap,
      borderRadius: 22,
      child: Container(
        width: 206,
        height: 266,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E293B).withValues(alpha: 0.14),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.08),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Full-bleed Photo Background
            if (photoUrl != null)
              Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _FallbackGradient(icon: categoryIcon),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _FallbackGradient(icon: categoryIcon);
                },
              )
            else
              _FallbackGradient(icon: categoryIcon),

            // 2. Layered Scrim Gradients for Maximum Visual Depth
            // Top shadow for badge contrast
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 70,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Bottom deep cinematic shadow for typography contrast
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 160,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.45, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.92),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Top Floating Glassmorphism Badges
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // State Badge
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7.5,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 11,
                            color: Color(0xFF60A5FA),
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              stateName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Rating Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: Color(0xFFFFB800),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          rating,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 4. Bottom Floating Info & Action Dock
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Category Tag with Vibrant Gradient
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      ),
                      borderRadius: BorderRadius.circular(7),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF6366F1,
                          ).withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(categoryIcon, size: 10.5, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          context.tr(cleanCategory).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 7),

                  // Attraction Name
                  Text(
                    attraction.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.2,
                      letterSpacing: -0.2,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 6,
                          offset: Offset(0, 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Action Footer Row with Floating Action Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            context.l10n.exploreSpot,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 14,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                      // Floating Circular Action Button
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_outward_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackGradient extends StatelessWidget {
  const _FallbackGradient({this.icon = Icons.landscape_rounded});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF4338CA), Color(0xFF6D28D9)],
        ),
      ),
      child: Center(child: Icon(icon, color: Colors.white60, size: 40)),
    );
  }
}
