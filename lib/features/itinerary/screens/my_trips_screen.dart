import 'package:flutter/material.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'itinerary_page.dart';

class MyTripsScreen extends StatelessWidget {
  const MyTripsScreen({
    super.key,
    required this.onBackTap,
    required this.onPlanTap,
  });

  final VoidCallback onBackTap;
  final VoidCallback onPlanTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: onBackTap),
        title: const Text(
          'My Trips',
          style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(top: false, child: ItineraryPage(onPlanTap: onPlanTap)),
    );
  }
}
