import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/core/theme/app_decorations.dart';
import 'package:smart_travel_planner/features/itinerary/models/saved_trip.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/supabase_itinerary_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_preferences_service.dart';
import 'package:smart_travel_planner/features/home/widgets/trip_cards.dart';
import 'package:smart_travel_planner/features/places/screens/api_retrieval_screen.dart';
import 'package:smart_travel_planner/features/home/widgets/popular_attractions_section.dart';

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
        isGenerated: true,
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
        ListenableBuilder(
          listenable: AuthService(),
          builder: (context, _) {
            if (AuthService().currentUser?.isAdmin != true) {
              return const SizedBox.shrink();
            }
            return const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SavedPlacesInspectorBanner(),
                SizedBox(height: 18),
              ],
            );
          },
        ),
        HeroPanel(onSearchTap: widget.onPlanTap),
        const SizedBox(height: 18),

        PopularAttractionsSection(onSeeAllTap: widget.onRouteTap),
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

/// Admin-only banner on the home screen for inspecting synced place data.
class _SavedPlacesInspectorBanner extends StatelessWidget {
  const _SavedPlacesInspectorBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.savedPlacesInspector,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  context.l10n.viewAdminSyncedPlacesInspectSavedData,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
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
            child: Text(context.l10n.open),
          ),
        ],
      ),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.myTrips,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        context.l10n.viewSavedItinerariesAndYourCurrentPlan,
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        context.l10n.viewAll,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.noActiveTripPlanned,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    context.l10n.tapToPlanYourSmartSchedule,
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
      constraints: const BoxConstraints(minHeight: 250),
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.flight_takeoff, color: Colors.white, size: 34),
          const SizedBox(height: 10),
          Text(
            context.l10n.smartTravelPlanning2,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              height: 1.05,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.autoSmartSchedulingForTouristsInMalaysia,
            style: const TextStyle(
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
                constraints: const BoxConstraints(minHeight: 46),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Icon(Icons.search, color: AppColors.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.whereToNext,
                        style: TextStyle(color: AppColors.muted),
                      ),
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
