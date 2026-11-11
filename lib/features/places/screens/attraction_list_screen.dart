import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/features/places/utils/attraction_image_resolver.dart';
import 'package:smart_travel_planner/features/places/widgets/google_maps_attribution.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';
import 'package:smart_travel_planner/shared/utils/demo_feedback.dart';

/// Inspiring travel discovery screen displaying curated highlights and
/// rich editorial destination cards.
class AttractionListScreen extends StatelessWidget {
  const AttractionListScreen({
    super.key,
    required this.attractions,
    required this.selectedStops,
    required this.onAttractionTap,
    required this.onToggleStop,
    this.highlights,
    this.header,
    this.hasMore = false,
    this.loadingMore = false,
    this.onLoadMore,
    this.attributions,
    this.currentAreaName,
    this.selectedCategory = 'All',
    this.searchQuery = '',
    this.onClearFilters,
  });

  final Widget? header;
  final List<Attraction> attractions;
  final List<Attraction> selectedStops;
  final ValueChanged<Attraction> onAttractionTap;
  final ValueChanged<Attraction> onToggleStop;
  final List<Attraction>? highlights;
  final bool hasMore;
  final bool loadingMore;
  final VoidCallback? onLoadMore;
  final List<Map<String, dynamic>>? attributions;
  final String? currentAreaName;
  final String selectedCategory;
  final String searchQuery;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    final isSearching = searchQuery.trim().isNotEmpty;
    final isFiltering = selectedCategory != 'All';
    final showHighlights =
        !isSearching &&
        !isFiltering &&
        highlights != null &&
        highlights!.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        ?header,
        // 1. Featured Highlights Carousel (Only in default browse mode)
        if (showHighlights) ...[
          _buildHighlightsSection(context),
          const SizedBox(height: 22),
        ],

        // 2. Section Header: "Popular Spots Nearby" / "Results for ..."
        _buildSectionHeader(context),
        const SizedBox(height: 12),

        // 3. Attractions Feed or Empty State
        if (attractions.isEmpty)
          _buildEmptyState(context)
        else
          ...attractions.map((attraction) {
            final selected = selectedStops.any(
              (item) => item.xid == attraction.xid,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ModernAttractionCard(
                attraction: attraction,
                selected: selected,
                onTap: () => onAttractionTap(attraction),
                onToggle: () => onToggleStop(attraction),
              ),
            );
          }),

        // 4. "Discover More Places" Button (Footer)
        if (hasMore && onLoadMore != null) _buildLoadMoreButton(context),

        // 5. Google Maps Attribution
        if (attributions != null && attributions!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: GoogleMapsAttribution(attributions: attributions!),
          ),
      ],
    );
  }

  Widget _buildHighlightsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEC4899).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.mustVisitHighlights,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          context.l10n.topIconicSpotsInValue(
                            (currentAreaName ?? 'Malaysia').toString(),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                context.l10n.valueTopPicks((highlights!.length).toString()),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 236,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: highlights!.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final attraction = highlights![index];
              final selected = selectedStops.any(
                (item) => item.xid == attraction.xid,
              );
              return HighlightAttractionCard(
                attraction: attraction,
                selected: selected,
                onTap: () => onAttractionTap(attraction),
                onToggle: () => onToggleStop(attraction),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context) {
    String title;
    String subtitle;

    if (searchQuery.trim().isNotEmpty) {
      title = context.l10n.searchResults;
      subtitle = context.l10n.matchingValue(searchQuery);
    } else if (selectedCategory != 'All') {
      title = selectedCategory;
      subtitle = context.l10n.placesInValue(
        currentAreaName ?? context.l10n.thisArea,
      );
    } else {
      title = 'Popular Attractions';
      subtitle = 'Curated spots within 5 km';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                context.tr(subtitle),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            context.l10n.valueSpots((attractions.length).toString()),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadMoreButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Center(
        child: FilledButton.tonalIcon(
          onPressed: loadingMore ? null : onLoadMore,
          icon: loadingMore
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.travel_explore_rounded, size: 20),
          label: Text(
            loadingMore
                ? context.l10n.discoveringMorePlaces
                : context.l10n.discoverMorePlacesInValue(
                    (currentAreaName ?? 'Malaysia').toString(),
                  ),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.sky,
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.travel_explore_rounded,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.noPlacesFound,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.isNotEmpty
                  ? context.l10n
                        .noAttractionsMatchValueTryCheckingForTyposOrSearchingABroaderTerm(
                          (searchQuery).toString(),
                        )
                  : context.l10n
                        .noSpotsFoundInThisCategoryNearValueTryChoosingAnotherCategoryOrSelectingANewLocation(
                          (currentAreaName ?? 'here').toString(),
                        ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.muted,
                height: 1.45,
              ),
            ),
            if (onClearFilters != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(context.l10n.resetSearchFilters),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Editorial horizontal card for curated must-visit highlights.
class HighlightAttractionCard extends StatelessWidget {
  const HighlightAttractionCard({
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
    final direct = attraction.photoUrl?.split('|').firstOrNull?.trim();
    final photoUrl = (direct != null && direct.startsWith('http'))
        ? direct
        : AttractionImageResolver.resolvePhotoUrl(attraction);
    final (catColor, catIcon, catLabel) = ModernAttractionCard.getCategoryMeta(
      attraction.category,
    );
    final rating = (attraction.rating ?? 4.8).toStringAsFixed(1);

    return Container(
      width: 205,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          if (selected)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo background
              if (photoUrl != null && photoUrl.startsWith('http'))
                Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) {
                    final fallback =
                        AttractionImageResolver.resolveFallbackPhotoUrl(
                          attraction,
                        );
                    if (fallback != null && fallback != photoUrl) {
                      return Image.network(
                        fallback,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            ModernAttractionCard.buildFallbackThumbnail(
                              catColor,
                              catIcon,
                            ),
                      );
                    }
                    return ModernAttractionCard.buildFallbackThumbnail(
                      catColor,
                      catIcon,
                    );
                  },
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return ModernAttractionCard.buildFallbackThumbnail(
                      catColor,
                      catIcon,
                    );
                  },
                )
              else
                ModernAttractionCard.buildFallbackThumbnail(catColor, catIcon),

              // Top dark scrim for badges
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 60,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom deep scrim for typography
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 140,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.88),
                        Colors.black.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Top-left category badge
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(catIcon, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        context.tr(catLabel),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Top-right frosted bookmark button
              Positioned(
                top: 10,
                right: 10,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      demoHaptic();
                      onToggle();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? AppColors.primary
                            : Colors.black.withValues(alpha: 0.45),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        selected
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom details
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Rating + Distance row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                rating,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            context.tr(
                              ModernAttractionCard.distanceLabel(
                                attraction.distanceMeters,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      attraction.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width modern editorial attraction card showcasing rich photography,
/// frosted badges, distance info, and one-tap bookmarking.
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
    final (catColor, catIcon, catLabel) = getCategoryMeta(attraction.category);
    final direct = attraction.photoUrl?.split('|').firstOrNull?.trim();
    final photoUrl = (direct != null && direct.startsWith('http'))
        ? direct
        : AttractionImageResolver.resolvePhotoUrl(attraction);
    final hasValidPhoto = photoUrl != null && photoUrl.startsWith('http');
    final ratingVal = attraction.rating ?? 4.7;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? AppColors.primary : const Color(0xFFE8ECF4),
          width: selected ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.16)
                : const Color(0xFF1E293B).withValues(alpha: 0.06),
            blurRadius: selected ? 16 : 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Photo Banner (165px)
              SizedBox(
                height: 165,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasValidPhoto)
                      Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          final fallback =
                              AttractionImageResolver.resolveFallbackPhotoUrl(
                                attraction,
                              );
                          if (fallback != null && fallback != photoUrl) {
                            return Image.network(
                              fallback,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  buildFallbackThumbnail(catColor, catIcon),
                            );
                          }
                          return buildFallbackThumbnail(catColor, catIcon);
                        },
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return buildFallbackThumbnail(catColor, catIcon);
                        },
                      )
                    else
                      buildFallbackThumbnail(catColor, catIcon),

                    // Top dark scrim for badges
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 55,
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

                    // Bottom dark scrim for distance & rating readability
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 60,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.65),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Top Left: Category Frosted Pill
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(catIcon, size: 13, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              context.tr(catLabel),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Top Right: Bookmark Button Pill
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            demoHaptic();
                            onToggle();
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected
                                  ? AppColors.primary
                                  : Colors.black.withValues(alpha: 0.45),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              selected
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Bottom Left: Distance with Walk Info
                    Positioned(
                      left: 12,
                      bottom: 10,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.near_me_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.tr(
                              distanceLabel(attraction.distanceMeters),
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom Right: Rating Star Pill
                    Positioned(
                      right: 12,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Color(0xFFFBBF24),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              ratingVal.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (attraction.userRatingsTotal != null &&
                                attraction.userRatingsTotal! > 0) ...[
                              const SizedBox(width: 2),
                              Text(
                                ' (${formatReviews(attraction.userRatingsTotal!)})',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Card Details Body
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name & Saved Indicator
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            attraction.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                              height: 1.25,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (selected) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 13,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  context.l10n.saved,
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Tags & Highlights row
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (attraction.isIndoor != null)
                          _buildPill(
                            context,
                            label: attraction.isIndoor!
                                ? context.l10n.indoor3
                                : context.l10n.outdoor2,
                            color: attraction.isIndoor!
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFFB45309),
                            backgroundColor: attraction.isIndoor!
                                ? const Color(0xFFEFF6FF)
                                : const Color(0xFFFEF3C7),
                          ),
                        if (ratingVal >= 4.5)
                          _buildPill(
                            context,
                            label: context.l10n.topRated,
                            color: const Color(0xFF7C3AED),
                            backgroundColor: const Color(0xFFF3E8FF),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Explore Action Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.tapToViewScheduleDetails,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.muted.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.l10n.explore,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(width: 3),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildPill(
    BuildContext context, {
    required String label,
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        context.tr(label),
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static Widget buildFallbackThumbnail(Color catColor, IconData catIcon) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [catColor.withValues(alpha: 0.85), catColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          catIcon,
          size: 40,
          color: Colors.white.withValues(alpha: 0.95),
        ),
      ),
    );
  }

  static (Color, IconData, String) getCategoryMeta(String category) {
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
    final raw = category.isEmpty
        ? 'Attraction'
        : category.split(',').first.trim();
    final cleanLabel = raw.toLowerCase() == 'tourist attraction'
        ? 'Attraction'
        : raw;
    return (AppColors.primary, Icons.place_rounded, cleanLabel);
  }

  static String formatReviews(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return '$count';
  }

  static String distanceLabel(double? meters) {
    if (meters == null) return 'Nearby';
    if (meters < 1000) return '${meters.round()} m away';
    final km = (meters / 1000).toStringAsFixed(1);
    if (meters <= 2000) {
      final walkMin = (meters / 80).round();
      return '$km km • ~$walkMin min walk';
    }
    return '$km km away';
  }
}
