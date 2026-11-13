import '../utils/attraction_image_resolver.dart';
import '../widgets/google_place_image.dart';
import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/features/places/data/attraction_metadata_resolver.dart';
import 'package:smart_travel_planner/features/places/models/google_place_details.dart';
import 'package:smart_travel_planner/features/places/services/google_places_service.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';

/// Full-featured attraction details screen with offline resilience,
/// rich photography, visitor highlights, and Google Maps integration (UC401).
class AttractionDetailPage extends StatefulWidget {
  const AttractionDetailPage({
    super.key,
    required this.attraction,
    this.placesService,
    this.onToggleSaved,
    this.isSaved = false,
  });

  final Attraction attraction;
  final GooglePlacesService? placesService;
  final bool Function(Attraction)? onToggleSaved;
  final bool isSaved;

  @override
  State<AttractionDetailPage> createState() => _AttractionDetailPageState();
}

class _AttractionDetailPageState extends State<AttractionDetailPage> {
  late final GooglePlacesService _service;
  late bool _saved;
  GooglePlaceDetails? _details;
  bool _loading = false;
  String? _error;

  final PageController _pageController = PageController();
  int _activePhotoIndex = 0;
  bool _isDescriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _service = widget.placesService ?? GooglePlacesService();
    _saved = widget.isSaved;
    if (widget.attraction.googlePlaceId != null) {
      _refresh();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    GooglePlaceDetails? details;
    try {
      details = await _service.fetchDetails(widget.attraction.googlePlaceId!);
    } catch (_) {
      details = null;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _details = details;
      if (details == null) {
        _error = _service.lastError ?? 'Place details are unavailable.';
      }
    });
  }

  Future<void> _openMap() async {
    final a = widget.attraction;
    final details = _details;

    if (details?.mapsUri != null) {
      final uri = Uri.tryParse(details!.mapsUri!);
      if (uri != null) {
        try {
          if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
            return;
          }
        } catch (_) {}
      }
    }

    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${a.latitude},${a.longitude}',
      if (a.googlePlaceId != null) 'query_place_id': a.googlePlaceId!,
    });
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.unableToOpenGoogleMaps)),
      );
    }
  }

  void _toggleSave() {
    final a = widget.attraction;
    if (widget.onToggleSaved != null) {
      if (widget.onToggleSaved!(a)) {
        setState(() => _saved = !_saved);
      }
    } else {
      setState(() => _saved = !_saved);
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _saved
              ? context.l10n.savedToFavoritePlaces
              : context.l10n.removedFromSavedPlaces,
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sharePlace() async {
    final a = widget.attraction;
    final address = AttractionMetadataResolver.resolveAddress(
      a,
      _details?.address,
    );
    final mapLink =
        'https://www.google.com/maps/search/?api=1&query=${a.latitude},${a.longitude}';
    final shareText = '${a.name}\n$address\n$mapLink';

    await Clipboard.setData(ClipboardData(text: shareText));
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.attractionDetailsMapLinkCopiedToClipboard),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _copyToClipboard(String text, String confirmationMessage) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr(confirmationMessage)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatReviews(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return '$count';
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.attraction;
    final details = _details;

    final hours =
        (details?.hours['weekdayDescriptions'] as List?)
            ?.whereType<String>()
            .toList() ??
        [];

    final rating = details?.rating ?? a.rating;
    final reviewCount = details?.reviewCount ?? a.userRatingsTotal;

    final description = AttractionMetadataResolver.resolveDescription(
      a,
      details?.description,
      rating,
      reviewCount,
    );

    final resolvedAddress = AttractionMetadataResolver.resolveAddress(
      a,
      details?.address,
    );
    final duration = AttractionMetadataResolver.resolveDuration(a);
    final atmosphere = AttractionMetadataResolver.resolveAtmosphere(a);
    final admission = AttractionMetadataResolver.resolveAdmission(a);
    final tips = AttractionMetadataResolver.resolveTips(a);

    final localPhoto = AttractionImageResolver.resolveAsset(a);
    final galleryPhotos = AttractionMetadataResolver.resolveGallery(a);
    final totalPhotos = galleryPhotos.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: CustomScrollView(
        slivers: [
          // ==================== HERO SLIVER APP BAR ====================
          SliverAppBar(
            expandedHeight: 330,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const BackButton(color: AppColors.ink),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      _saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: _saved ? AppColors.primary : AppColors.ink,
                      size: 20,
                    ),
                    tooltip: _saved
                        ? context.l10n.removeFromSaved
                        : context.l10n.saveAttraction,
                    onPressed: _toggleSave,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8, right: 14),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.share_rounded,
                      color: AppColors.ink,
                      size: 20,
                    ),
                    tooltip: context.l10n.sharePlace,
                    onPressed: _sharePlace,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Photo Pager
                  if (galleryPhotos.isEmpty &&
                      details != null &&
                      details.photos.isNotEmpty)
                    GooglePlaceImage(
                      placeId: details.id,
                      photo: details.photos.first,
                      service: _service,
                      autoLoad: true,
                      fill: true,
                    )
                  else if (galleryPhotos.isNotEmpty)
                    PageView.builder(
                      controller: _pageController,
                      itemCount: galleryPhotos.length,
                      onPageChanged: (idx) =>
                          setState(() => _activePhotoIndex = idx),
                      itemBuilder: (context, index) {
                        return Image.network(
                          galleryPhotos[index],
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              details != null && details.photos.isNotEmpty
                              ? GooglePlaceImage(
                                  placeId: details.id,
                                  photo: details.photos.first,
                                  service: _service,
                                  autoLoad: true,
                                  fill: true,
                                )
                              : _buildFallbackHero(a.category),
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: const Color(0xFFE2E8F0),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    )
                  else if (localPhoto != null)
                    Image.asset(
                      localPhoto,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _buildFallbackHero(a.category),
                    )
                  else
                    _buildFallbackHero(a.category),

                  // Top gradient shadow for app bar legibility
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 100,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.45),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom subtle gradient transition
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Photo counter pill (bottom right)
                  if (totalPhotos > 1)
                    Positioned(
                      bottom: 26,
                      right: 18,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.photo_library_outlined,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${_activePhotoIndex + 1} / $totalPhotos',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Carousel dot indicators (bottom center)
                  if (totalPhotos > 1 && totalPhotos <= 6)
                    Positioned(
                      bottom: 28,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(totalPhotos, (index) {
                          final isActive = index == _activePhotoIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: isActive ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ==================== MAIN CONTENT BODY ====================
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_loading) const LinearProgressIndicator(),

                // Error Retry Banner (Keeps test assertions intact)
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFFD199)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFFD97706),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr(_error!),
                                  style: const TextStyle(
                                    color: Color(0xFF92400E),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  context.l10n.showingAvailablePlaceInformation,
                                  style: TextStyle(
                                    color: Color(0xFFB45309),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _refresh,
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFB45309),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: Text(context.l10n.retry),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Elevated Content Container with curved overlap
                Container(
                  margin: const EdgeInsets.only(top: 0),
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x0A111827),
                        blurRadius: 18,
                        offset: Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Attraction Title
                      Text(
                        a.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                              letterSpacing: -0.4,
                              height: 1.25,
                            ),
                      ),
                      const SizedBox(height: 10),

                      // Rating & Verification Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: Color(0xFFD97706),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  (rating ?? 4.8).toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (reviewCount != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              context.l10n.valueReviews(
                                (_formatReviews(reviewCount)).toString(),
                              ),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(width: 10),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Color(0xFFCBD5E1),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Retains the exact string for tests & clarity
                          Text(
                            rating != null
                                ? context.l10n.ratingValue5(
                                    (rating.toStringAsFixed(1)).toString(),
                                  )
                                : context.l10n.topMalaysianAttraction,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ==================== HIGHLIGHT TILES ====================
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.schedule_rounded,
                              label: context.l10n.estVisit,
                              value: duration,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.wb_sunny_outlined,
                              label: context.l10n.setting,
                              value: atmosphere,
                              color: AppColors.teal,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.confirmation_number_outlined,
                              label: context.l10n.entry,
                              value: admission,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ==================== ABOUT SECTION ====================
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.article_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            context.l10n.about,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.ink,
                                  fontSize: 17,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        description.trim().isEmpty
                            ? context.l10n.descriptionUnavailable
                            : description,
                        maxLines: _isDescriptionExpanded ? null : 3,
                        overflow: _isDescriptionExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.6,
                          color: Color(0xFF334155),
                        ),
                      ),
                      if (description.length > 140)
                        InkWell(
                          onTap: () => setState(
                            () => _isDescriptionExpanded =
                                !_isDescriptionExpanded,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6, bottom: 4),
                            child: Text(
                              _isDescriptionExpanded
                                  ? context.l10n.readLess
                                  : context.l10n.readMore,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),

                      // ==================== ADDRESS CARD ====================
                      _buildInfoCard(
                        icon: Icons.location_on_rounded,
                        iconColor: AppColors.primary,
                        title: context.l10n.address,
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              resolvedAddress,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                color: Color(0xFF1E293B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (a.latitude != 0 && a.longitude != 0) ...[
                              const SizedBox(height: 6),
                              Text(
                                'GPS: ${a.latitude.toStringAsFixed(4)}° N, ${a.longitude.toStringAsFixed(4)}° E',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.copy_rounded,
                            size: 19,
                            color: AppColors.primary,
                          ),
                          tooltip: context.l10n.copyAddress,
                          onPressed: () => _copyToClipboard(
                            resolvedAddress,
                            'Address copied to clipboard!',
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ==================== OPENING HOURS CARD ====================
                      _buildInfoCard(
                        icon: Icons.schedule_rounded,
                        iconColor: AppColors.teal,
                        title: context.l10n.openingHours,
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hours.isEmpty
                                  ? context
                                        .l10n
                                        .openingHoursUnavailableCheckBeforeVisiting
                                  : hours.join('\n'),
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                color: hours.isEmpty
                                    ? AppColors.muted
                                    : const Color(0xFF1E293B),
                                fontWeight: hours.isEmpty
                                    ? FontWeight.normal
                                    : FontWeight.w500,
                              ),
                            ),
                            if (hours.isEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                context
                                    .l10n
                                    .operatingHoursMayVaryDuringPublicHolidaysOrSpecialEvents,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ==================== TRAVELER TIPS ====================
                      if (tips.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFFDE68A),
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.lightbulb_rounded,
                                      size: 18,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    context.l10n.travelerTipsGoodToKnow,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...tips.map(
                                (tip) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 5),
                                        child: Icon(
                                          Icons.check_circle_rounded,
                                          size: 14,
                                          color: Color(0xFFD97706),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          tip,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            height: 1.45,
                                            color: Color(0xFF78350F),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // ==================== GOOGLE MAPS ATTRIBUTION ====================
                      if (details != null &&
                          details.attributions.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'Google Maps',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...details.attributions.map(
                          (a) => Text(
                            a['provider']?.toString() ?? 'Google Maps',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],

                      // Extra spacing for sticky bottom bar
                      const SizedBox(height: 90),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // ==================== STICKY BOTTOM ACTION BAR ====================
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              // Secondary: Bookmark/Save Button
              Material(
                color: _saved
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: _toggleSave,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 52,
                    width: 52,
                    alignment: Alignment.center,
                    child: Icon(
                      _saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: _saved ? AppColors.primary : AppColors.ink,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Primary Action: Open in Google Maps
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _openMap,
                    icon: const Icon(Icons.directions_rounded, size: 21),
                    label: Text(
                      context.l10n.openInGoogleMaps,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== UI HELPER WIDGETS ====================

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            context.tr(label),
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget content,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                content,
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _buildFallbackHero(String category) {
    final kind = category.toLowerCase();
    final icon =
        kind.contains('food') ||
            kind.contains('restaurant') ||
            kind.contains('cafe')
        ? Icons.restaurant_rounded
        : kind.contains('nature') || kind.contains('park')
        ? Icons.park_rounded
        : kind.contains('religion') || kind.contains('cultural')
        ? Icons.temple_buddhist_rounded
        : Icons.place_rounded;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B28B8), Color(0xFF6652E8)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.photoUnavailable,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
