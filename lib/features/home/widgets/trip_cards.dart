import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:smart_travel_planner/l10n/presentation_formatters.dart';
import 'package:flutter/material.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/core/theme/app_decorations.dart';
import 'package:smart_travel_planner/features/itinerary/models/saved_trip.dart';
import 'package:smart_travel_planner/shared/widgets/demo_tap.dart';

class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.onTap,
    this.isDark = false,
  });

  final SavedTrip trip;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (isDark) {
      return Material(
        color: AppColors.nightSurface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('home-upcoming-trip'),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/recognition/trip_schedule_malaysia.png',
                height: 164,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 164,
                  child: ColoredBox(color: AppColors.nightRaised),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tripTitle(trip),
                            style: const TextStyle(
                              color: AppColors.nightBody,
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'serif',
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tripDate(trip),
                            style: const TextStyle(color: AppColors.nightMuted),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tr(trip.detail),
                            style: const TextStyle(
                              color: AppColors.nightAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 24,
                      color: AppColors.nightAccent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return DemoTapCard(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: isDark
            ? BoxDecoration(
                color: AppColors.nightSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.nightLine, width: 1.2),
              )
            : cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: isDark
                    ? const LinearGradient(
                        colors: [
                          AppColors.nightHeroEnd,
                          AppColors.nightHeroStart,
                        ],
                      )
                    : const LinearGradient(
                        colors: [
                          AppColors.nightHeroStart,
                          AppColors.nightHeroEnd,
                        ],
                      ),
              ),
              child: const Icon(
                Icons.location_city,
                color: Colors.white,
                size: 34,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tripTitle(trip),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tripDate(trip),
                    style: TextStyle(
                      color: isDark ? AppColors.nightMuted : AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(trip.detail),
                    style: TextStyle(
                      color: isDark ? AppColors.nightAccent : AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? AppColors.nightAccent : AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class SavedTripCard extends StatelessWidget {
  const SavedTripCard({super.key, required this.trip, required this.onTap});

  final SavedTrip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DemoTapCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.sky,
              child: Icon(Icons.card_travel, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tripTitle(trip),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tripDate(trip),
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(trip.detail),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
