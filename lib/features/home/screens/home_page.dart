import 'package:flutter/material.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/core/theme/app_decorations.dart';
import 'package:smart_travel_planner/features/itinerary/models/saved_trip.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/supabase_itinerary_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_preferences_service.dart';
import 'package:smart_travel_planner/features/home/widgets/trip_cards.dart';
import 'package:smart_travel_planner/features/places/screens/api_retrieval_screen.dart';

class HomePage extends StatefulWidget {
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
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<SavedTrip> _dbSavedTrips = [];

  @override
  void initState() {
    super.initState();
    SupabaseItineraryService().addListener(_onRepoChanged);
    _loadTrips();
  }

  @override
  void dispose() {
    SupabaseItineraryService().removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    if (mounted) {
      _loadTrips(refresh: false);
    }
  }

  Future<void> _loadTrips({bool refresh = true}) async {
    try {
      final uid = AuthService().currentUser?.uid;
      final itineraries = await SupabaseItineraryService().getSavedItineraries(
        refresh: refresh,
      );
      if (mounted && uid == AuthService().currentUser?.uid) {
        setState(() {
          _dbSavedTrips = itineraries.map((e) => e.toSavedTrip()).toList();
        });
      }
    } catch (_) {}
  }

  SavedTrip? get _upcomingTrip {
    final userPrefs = TripPreferencesService.storedPreferences;
    if (userPrefs != null &&
        userPrefs.destination != null &&
        userPrefs.destination!.trim().isNotEmpty) {
      return SavedTrip(
        title: '${userPrefs.destination} Smart Schedule',
        date: 'Active Planned Trip',
        detail: '${userPrefs.numberOfDays ?? 3} days itinerary',
        destination: '${userPrefs.destination}, Malaysia',
        budget: userPrefs.budgetCategory ?? 'Medium',
        interests: userPrefs.interests,
        totalDays: userPrefs.numberOfDays ?? 3,
      );
    }
    if (_dbSavedTrips.isNotEmpty) {
      return _dbSavedTrips.first;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final upcomingTrip = _upcomingTrip;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
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
                      'Saved Places Inspector',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'View admin-synced places & inspect saved data',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ApiRetrievalScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Open'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),
        HeroPanel(onSearchTap: widget.onPlanTap),
        const SizedBox(height: 18),

        _MyTripsCard(onTap: widget.onItineraryTap),
        const SizedBox(height: 18),

        if (upcomingTrip != null)
          TripCard(trip: upcomingTrip, onTap: widget.onItineraryTap)
        else
          _EmptyTripCard(onPlanTap: widget.onPlanTap),
      ],
    );
  }
}

class _MyTripsCard extends StatelessWidget {
  const _MyTripsCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDecoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: const ValueKey('home-my-trips'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.folder_open_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Trips',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'View saved itineraries and your current plan',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'View All',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyTripCard extends StatelessWidget {
  const _EmptyTripCard({required this.onPlanTap});

  final VoidCallback onPlanTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPlanTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6E9F4), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.add_location_alt_outlined,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Active Trip Planned',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tap to plan your smart schedule',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
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
