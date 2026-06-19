import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../data/sample_data.dart';
import '../widgets/action_cards.dart';
import '../widgets/app_header.dart';
import '../widgets/section_header.dart';
import '../widgets/trip_cards.dart';
import 'trip_detail_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onPlanTap,
    required this.onItineraryTap,
    required this.onRouteTap,
    required this.onAssistantTap,
  });

  final VoidCallback onPlanTap;
  final VoidCallback onItineraryTap;
  final VoidCallback onRouteTap;
  final VoidCallback onAssistantTap;

  @override
  Widget build(BuildContext context) {
    final upcomingTrip = savedTrips.first;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        const AppHeader(
          title: 'Hello, Traveler!',
          subtitle: 'Where would you like to explore today?',
        ),
        const SizedBox(height: 18),
        HeroPanel(onSearchTap: onPlanTap),
        const SizedBox(height: 18),
        SectionHeader(
          title: 'Auto Smart Scheduling',
          action: 'New plan',
          onTap: onPlanTap,
        ),
        const SizedBox(height: 10),
        const FeatureGrid(),
        const SizedBox(height: 18),
        TripCard(
          trip: upcomingTrip,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TripDetailPage(trip: upcomingTrip),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Quick Actions',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            QuickAction(
              icon: Icons.auto_awesome,
              label: 'Smart Plan',
              onTap: onPlanTap,
            ),
            QuickAction(
              icon: Icons.list_alt_outlined,
              label: 'Itinerary',
              onTap: onItineraryTap,
            ),
            QuickAction(
              icon: Icons.map_outlined,
              label: 'Explore',
              onTap: onRouteTap,
            ),
            QuickAction(
              icon: Icons.smart_toy_outlined,
              label: 'Assistant',
              onTap: onAssistantTap,
            ),
          ],
        ),
      ],
    );
  }
}

class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key, required this.onSearchTap});

  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF142850), Color(0xFF27496D), Color(0xFF6652E8)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x223A2CB1),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          const Icon(Icons.flight_takeoff, color: Colors.white, size: 34),
          const SizedBox(height: 10),
          const Text(
            'Smart Travel Planning',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              height: 1.05,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Auto smart scheduling for tourists in Malaysia',
            style: TextStyle(
              color: Color(0xFFE7EAFF),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onSearchTap,
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerLeft,
                child: const Row(
                  children: [
                    Icon(Icons.search, color: AppColors.muted),
                    SizedBox(width: 10),
                    Text(
                      'Where to next?',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
