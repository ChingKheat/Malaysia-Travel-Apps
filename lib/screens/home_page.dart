import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../data/sample_data.dart';
import '../services/auth_service.dart';
import '../widgets/app_header.dart';
import '../widgets/trip_cards.dart';
import 'api_retrieval_screen.dart';
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
    final user = AuthService().currentUser;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        AppHeader(
          title: 'Hello, ${user != null ? user.name.split(' ').first : "Traveler"}!',
          subtitle: 'Where would you like to explore today?',
        ),

        const SizedBox(height: 18),
        
        // Live API Test Inspector Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.api, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live API Retrieval Inspector',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      'Test real-time place retrieval & inspect JSON output',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ApiRetrievalScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Open'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),
        HeroPanel(onSearchTap: onPlanTap),
        const SizedBox(height: 18),

        TripCard(
          trip: upcomingTrip,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TripDetailPage(trip: upcomingTrip),
            ),
          ),
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
