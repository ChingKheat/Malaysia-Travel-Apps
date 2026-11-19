import 'package:flutter/material.dart';
import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/features/itinerary/models/itinerary_models.dart';
import 'package:smart_travel_planner/features/itinerary/models/saved_trip.dart';
import 'package:smart_travel_planner/features/itinerary/services/supabase_itinerary_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/trip_preferences_service.dart';
import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:smart_travel_planner/l10n/presentation_formatters.dart';

import 'my_trips_screen.dart';

class TripSelectionScreen extends StatefulWidget {
  const TripSelectionScreen({super.key});

  @override
  State<TripSelectionScreen> createState() => _TripSelectionScreenState();
}

class _TripSelectionScreenState extends State<TripSelectionScreen> {
  late Future<List<Itinerary>> _trips;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  void _loadTrips() {
    _trips = SupabaseItineraryService().getSavedItineraries(
      includeDrafts: true,
    );
  }

  Future<void> _openTrip(String? id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => MyTripsScreen(
          initialItineraryId: id,
          onBackTap: () => Navigator.of(routeContext).pop(),
          onPlanTap: () {
            final navigator = Navigator.of(routeContext);
            navigator.pop();
            navigator.pop();
          },
        ),
      ),
    );
    if (mounted) setState(_loadTrips);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = TripPreferencesService.storedPreferences;
    final active = prefs?.destination == null
        ? null
        : SavedTrip(
            title: '${prefs!.destination} Custom Schedule',
            date: 'Active Generated Plan',
            detail: '',
            destination: '${prefs.destination}, Malaysia',
            budget: prefs.budgetCategory ?? 'Medium',
            interests: prefs.interests,
            totalDays: prefs.numberOfDays ?? 3,
            startsOn: prefs.startDate,
            isGenerated: true,
          );
    return Scaffold(
      backgroundColor: AppColors.nightCanvas,
      appBar: AppBar(
        title: Text(context.l10n.myTrips),
        backgroundColor: AppColors.nightCanvas,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: FutureBuilder<List<Itinerary>>(
          future: _trips,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done && active == null) {
              return const SizedBox.shrink();
            }
            if (snapshot.hasError) {
              return Center(
                child: TextButton(
                  onPressed: () => setState(_loadTrips),
                  child: Text(context.l10n.retry),
                ),
              );
            }
            final saved = snapshot.data ?? const <Itinerary>[];
            if (active == null && saved.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.folder_open_outlined,
                        size: 40,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context
                            .l10n
                            .youHaveNoActiveOrSavedTripsSetYourTravelPreferencesToGenerateASmartDayByDaySchedule,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.muted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            final count = saved.length + (active == null ? 0 : 1);
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              itemCount: count + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Semantics(
                    header: true,
                    child: Text(
                      context.l10n.selectPlannedItinerary,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  );
                }
                final isActive = active != null && index == 1;
                final savedIndex = index - 1 - (active == null ? 0 : 1);
                final trip = isActive
                    ? active
                    : saved[savedIndex].toSavedTrip();
                final id = isActive ? null : saved[savedIndex].itineraryId;
                final status = isActive
                    ? context.l10n.activeItinerary
                    : saved[savedIndex].isDraft
                    ? context.l10n.draftLabel
                    : null;
                return Material(
                  color: AppColors.nightSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.nightLine),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _openTrip(id),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.nightAccentContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.place_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (status != null) ...[
                                  Text(
                                    status,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                Text(
                                  context.tripTitle(trip),
                                  style: const TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  trip.destination,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    if (trip.startsOn != null)
                                      context.localDate(trip.startsOn!),
                                    context.l10n.valueDays(
                                      context.localNumber(trip.totalDays),
                                    ),
                                  ].join(' · '),
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Icon(
                              Icons.chevron_right,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
