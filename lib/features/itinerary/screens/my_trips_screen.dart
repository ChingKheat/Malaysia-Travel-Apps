import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'itinerary_page.dart';

class MyTripsScreen extends StatelessWidget {
  const MyTripsScreen({
    super.key,
    required this.onBackTap,
    required this.onPlanTap,
    this.initialItineraryId,
    this.initialDayIndex = 0,
  });

  final VoidCallback onBackTap;
  final VoidCallback onPlanTap;
  final String? initialItineraryId;
  final int initialDayIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: onBackTap),
        title: Text(
          context.l10n.myTrips,
          style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink),
        ),
        backgroundColor: AppColors.nightSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ItineraryPage(
          onPlanTap: onPlanTap,
          initialItineraryId: initialItineraryId,
          initialDayIndex: initialDayIndex,
        ),
      ),
    );
  }
}
