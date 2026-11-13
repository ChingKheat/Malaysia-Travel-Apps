import 'package:smart_travel_planner/features/places/services/google_places_service.dart';
import 'package:smart_travel_planner/features/places/widgets/google_place_image.dart';
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

/// Horizontally scrollable popular attractions on the home page.
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

    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final cardHeight =
        250 + (textScaler.scale(15) - 15).clamp(0.0, double.infinity) * 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.popularAttractions,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              key: const ValueKey('popular-attractions-see-all'),
              onPressed: onSeeAllTap,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.seeAll),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth * 0.72).clamp(0.0, 248.0);
            return SizedBox(
              height: cardHeight,
              child: ListView.separated(
                key: const ValueKey('popular-attractions-list'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 2),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final attraction = items[index];
                  return SizedBox(
                    width: cardWidth,
                    child: PopularAttractionCard(
                      attraction: attraction,
                      onTap: () => _openAttraction(context, attraction),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

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
    final category = raw.split(',').first.trim();
    return category.isEmpty ? 'Attraction' : category;
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
    final photoUrl = AttractionImageResolver.resolvePhotoUrl(attraction);
    final localPhoto = AttractionImageResolver.resolveAsset(attraction);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final rating = attraction.rating;
    final category = context.tr(_cleanCategory(attraction.category));
    final fallback = ColoredBox(
      color: colors.primaryContainer,
      child: Center(
        child: Icon(
          _categoryIcon(attraction.category),
          color: colors.onPrimaryContainer,
          size: 38,
        ),
      ),
    );

    return DemoTapCard(
      onTap: onTap,
      borderRadius: 16,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: photoUrl != null
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      frameBuilder: (_, child, frame, wasSynchronouslyLoaded) =>
                          wasSynchronouslyLoaded || frame != null
                          ? child
                          : fallback,
                      errorBuilder: (_, _, _) => fallback,
                    )
                  : localPhoto != null
                  ? Image.asset(
                      localPhoto,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) => fallback,
                    )
                  : _LiveAttractionPhoto(
                      key: ValueKey(attraction.xid),
                      attraction: attraction,
                      fallback: fallback,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    attraction.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _resolveState(attraction),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      if (rating != null) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.star_rounded,
                          size: 15,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          rating.toStringAsFixed(1),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_outward_rounded,
                        size: 16,
                        color: colors.primary,
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

class _LiveAttractionPhoto extends StatefulWidget {
  const _LiveAttractionPhoto({
    super.key,
    required this.attraction,
    required this.fallback,
  });

  final Attraction attraction;
  final Widget fallback;

  @override
  State<_LiveAttractionPhoto> createState() => _LiveAttractionPhotoState();
}

class _LiveAttractionPhotoState extends State<_LiveAttractionPhoto> {
  static final _service = GooglePlacesService();
  late final Future<Attraction?> _match = _findPhoto();

  Future<Attraction?> _findPhoto() async {
    final place = widget.attraction;
    if (place.googlePlaceId != null && place.googlePhotos.isNotEmpty) {
      return place;
    }
    if (place.googlePlaceId case final id?) {
      final details = await _service.fetchDetails(id);
      if (details == null || details.photos.isEmpty) return null;
      return Attraction(
        xid: place.xid,
        name: place.name,
        latitude: place.latitude,
        longitude: place.longitude,
        category: place.category,
        googlePhotos: details.photos,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Attraction?>(
      future: _match,
      builder: (context, snapshot) {
        final place = snapshot.data;
        if (place == null) return widget.fallback;
        return GooglePlaceImage(
          placeId: place.googlePlaceId!,
          photo: place.googlePhotos.first,
          service: _service,
          autoLoad: true,
          fill: true,
          fallback: widget.fallback,
          showGoogleMapsAttribution: true,
        );
      },
    );
  }
}
