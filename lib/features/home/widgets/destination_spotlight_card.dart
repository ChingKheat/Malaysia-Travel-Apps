import 'package:flutter/material.dart';
import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/features/home/models/spotlight_destination.dart';
import 'package:smart_travel_planner/l10n/localized_labels.dart';

/// Destination Spotlight prompt on Home.
///
/// Renders either as a floating promo card at the bottom of the screen
/// ([floating] = true), an inline card ([floating] = false), or a compact
/// reopen bar once dismissed.
class DestinationSpotlightCard extends StatelessWidget {
  const DestinationSpotlightCard({
    super.key,
    required this.dismissed,
    required this.onChooseDestinations,
    required this.onDismiss,
    this.floating = false,
    this.featured,
  });

  final bool dismissed;
  final VoidCallback onChooseDestinations;
  final VoidCallback onDismiss;
  final bool floating;
  final SpotlightDestination? featured;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (dismissed) {
      return Material(
        color: AppColors.nightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.nightLine),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('spotlight-compact-entry'),
          onTap: onChooseDestinations,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.explore_outlined,
                    size: 20,
                    color: AppColors.nightAccent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.spotlightChooseDestinations,
                      style: const TextStyle(
                        color: AppColors.nightBody,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: AppColors.nightMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (floating) {
      final activeFeatured = featured ?? spotlightDestinations.first;
      final featuredTitle = activeFeatured.localizedTitle(l10n);
      final featuredRegion = activeFeatured.localizedRegion(l10n);
      final featuredPhoto =
          activeFeatured.imageAsset ?? 'assets/recognition/petronas.jpg';

      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.94 + (0.06 * t), child: child),
        ),
        child: Material(
          key: const ValueKey('destination-spotlight-card'),
          color: AppColors.nightSurface,
          elevation: 16,
          shadowColor: Colors.black.withValues(alpha: 0.65),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: AppColors.nightAccent.withValues(alpha: 0.45),
              width: 1.2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    InkWell(
                      onTap: onChooseDestinations,
                      child: Image.asset(
                        featuredPhoto,
                        height: 148,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => const SizedBox(
                          height: 148,
                          child: ColoredBox(color: AppColors.nightRaised),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: const CircleBorder(),
                        child: IconButton(
                          key: const ValueKey('spotlight-dismiss-btn'),
                          tooltip: l10n.spotlightDismissLabel,
                          onPressed: onDismiss,
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.spotlightFeaturedSpot(
                          featuredTitle == featuredRegion
                              ? featuredTitle
                              : '$featuredTitle, $featuredRegion',
                        ),
                        style: const TextStyle(
                          color: AppColors.nightAccent,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.spotlightHeading,
                        style: const TextStyle(
                          color: AppColors.nightBody,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.spotlightSubtitle,
                        style: const TextStyle(
                          color: AppColors.nightMuted,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const ValueKey('spotlight-choose-btn'),
                        onPressed: onChooseDestinations,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.nightAccent,
                          foregroundColor: AppColors.onNightAccent,
                          minimumSize: const Size.fromHeight(48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          l10n.spotlightChooseDestinations,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
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

    return DecoratedBox(
      key: const ValueKey('destination-spotlight-card'),
      decoration: BoxDecoration(
        color: AppColors.nightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.nightLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/recognition/petronas.jpg',
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 84,
                      height: 84,
                      child: ColoredBox(color: AppColors.nightRaised),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.spotlightHeading,
                        style: const TextStyle(
                          color: AppColors.nightBody,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.spotlightSubtitle,
                        style: const TextStyle(
                          color: AppColors.nightMuted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('spotlight-dismiss-btn'),
                  tooltip: l10n.spotlightDismissLabel,
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.nightMuted,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('spotlight-choose-btn'),
              onPressed: onChooseDestinations,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.nightAccent,
                foregroundColor: AppColors.onNightAccent,
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                l10n.spotlightChooseDestinations,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
