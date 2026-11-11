import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';
import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/features/assistant/models/assistant_message.dart';
import 'package:smart_travel_planner/shared/utils/demo_feedback.dart';

class AssistantPlaceCard extends StatelessWidget {
  const AssistantPlaceCard({
    super.key,
    required this.place,
    this.onAddToItinerary,
  });

  final AssistantPlaceSuggestion place;
  final VoidCallback? onAddToItinerary;

  void _showPlaceDetails(BuildContext context) {
    demoHaptic();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              place.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                place.category,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      place.location,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                place.description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        showDemoSnackBar(
                          context,
                          context.l10n.valueAddedToYourDay2ScheduleDraft(
                            (place.name).toString(),
                          ),
                          icon: Icons.bookmark_added_rounded,
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(
                        context.l10n.addToMyItinerary,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06111827),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Place Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 68,
              height: 68,
              child: place.photoUrl != null
                  ? Image.network(
                      place.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _fallbackPhoto(),
                    )
                  : _fallbackPhoto(),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: Colors.amber,
                    ),
                    Text(
                      place.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  place.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        demoHaptic();
                        showDemoSnackBar(
                          context,
                          context.l10n.valueAddedToYourPlanDraft(
                            (place.name).toString(),
                          ),
                          icon: Icons.playlist_add_check_rounded,
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 13,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 3),
                            Text(
                              context.l10n.addToPlan,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _showPlaceDetails(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Text(
                          context.l10n.details,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackPhoto() {
    return Container(
      color: AppColors.sky,
      child: const Center(
        child: Icon(
          Icons.location_city_rounded,
          color: AppColors.primary,
          size: 28,
        ),
      ),
    );
  }
}
