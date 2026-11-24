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
    this.onTodayRouteTap,
    this.isDark = false,
  });

  final SavedTrip trip;
  final VoidCallback onTap;
  final VoidCallback? onTodayRouteTap;
  final bool isDark;

  static String coverAssetForDestination(String destination) {
    final normalized = destination.trim().toLowerCase();
    if (normalized.contains('johor')) {
      return 'assets/recognition/danga_bay_waterfront.jpg';
    }
    if (normalized.contains('kuala lumpur') || normalized == 'kl') {
      return 'assets/recognition/petronas.jpg';
    }
    if (normalized.contains('penang')) {
      return 'assets/recognition/community_hero_penang.png';
    }
    if (normalized.contains('langkawi') || normalized.contains('kedah')) {
      return 'assets/recognition/explore_hero_langkawi.png';
    }
    if (normalized.contains('cameron') || normalized.contains('pahang')) {
      return 'assets/recognition/my_trips_cameron_highlands.png';
    }
    return 'assets/recognition/trip_schedule_malaysia.png';
  }

  static DateTime? _parseTripStart(SavedTrip trip) {
    if (trip.startsOn != null) {
      return DateTime(
        trip.startsOn!.year,
        trip.startsOn!.month,
        trip.startsOn!.day,
      );
    }
    final match = RegExp(
      r'^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{1,2}),\s+(\d{4})',
    ).firstMatch(trip.date.trim());
    if (match == null) return null;
    const months = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };
    final month = months[match.group(1)!];
    final day = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (month == null || day == null || year == null) return null;
    return DateTime(year, month, day);
  }

  static String statusLabel(SavedTrip trip, {DateTime? now}) {
    final start = _parseTripStart(trip);
    final days = trip.totalDays < 1 ? 1 : trip.totalDays;
    if (start == null) {
      return 'Active plan • $days ${days == 1 ? 'day' : 'days'}';
    }
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);
    final end = start.add(Duration(days: days - 1));
    if (today.isBefore(start)) {
      final diff = start.difference(today).inDays;
      return diff == 1
          ? 'Upcoming • Starts tomorrow'
          : 'Upcoming • Starts in $diff days';
    }
    if (!today.isAfter(end)) {
      final dayNumber = today.difference(start).inDays + 1;
      return 'Ongoing • Day $dayNumber of $days';
    }
    return 'Completed • $days ${days == 1 ? 'day' : 'days'}';
  }

  @override
  Widget build(BuildContext context) {
    if (isDark) {
      final coverAsset = coverAssetForDestination(trip.destination);
      final status = statusLabel(trip);
      return Material(
        color: AppColors.nightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.nightLine, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              key: const ValueKey('home-upcoming-trip'),
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 164,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          coverAsset,
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                          errorBuilder: (_, _, _) => const SizedBox(
                            height: 164,
                            child: ColoredBox(color: AppColors.nightRaised),
                          ),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [0.45, 1.0],
                              colors: [
                                Colors.transparent,
                                AppColors.nightSurface,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                status,
                                style: const TextStyle(
                                  color: AppColors.nightAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.tripTitle(trip),
                                style: const TextStyle(
                                  color: AppColors.nightBody,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'serif',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.tripDate(trip),
                                style: const TextStyle(
                                  color: AppColors.nightMuted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.tr(trip.detail),
                                style: const TextStyle(
                                  color: AppColors.nightAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.nightRaised,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                            color: AppColors.nightAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (onTodayRouteTap != null) ...[
              const Divider(height: 1, thickness: 1, color: AppColors.nightLine),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: onTap,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Open Plan',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.nightBody,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 20,
                    color: AppColors.nightLine,
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: onTodayRouteTap,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.near_me_rounded,
                              size: 16,
                              color: AppColors.nightAccent,
                            ),
                            SizedBox(width: 6),
                            Text(
                              "Today's Route",
                              style: TextStyle(
                                color: AppColors.nightAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
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
