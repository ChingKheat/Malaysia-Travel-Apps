import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_decorations.dart';
import '../core/demo_feedback.dart';
import '../data/sample_data.dart';
import '../models/itinerary_models.dart';
import '../services/smart_itinerary_service.dart';
import '../services/supabase_itinerary_service.dart';
import '../services/trip_preferences_service.dart';
import '../widgets/summary_bar.dart';


class ItineraryReadyPage extends StatelessWidget {
  const ItineraryReadyPage({super.key, required this.onViewItinerary});

  final VoidCallback onViewItinerary;

  @override
  Widget build(BuildContext context) {
    final userPrefs = TripPreferencesService.storedPreferences;
    final destination = userPrefs?.destination ?? 'Kuala Lumpur';
    final previewStops = getDailyStops(0);


    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FD),
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: cardDecoration(),
            child: Column(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: AppColors.primary,
                  size: 52,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your $destination Itinerary is Ready!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'The route is optimized for $destination by distance, daily hours, budget and weather conditions.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, height: 1.4),
                ),
                const SizedBox(height: 18),
                const SummaryBar(),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...previewStops
              .take(3)
              .map(
                (stop) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: cardDecoration(),
                  child: Row(
                    children: [
                      if (stop.primaryPhotoUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            stop.primaryPhotoUrl!,
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(stop.icon, color: stop.color),
                          ),
                        )
                      else
                        Icon(stop.icon, color: stop.color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          stop.title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        stop.time,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onViewItinerary();
            },
            icon: const Icon(Icons.list_alt),
            label: const Text('View Itinerary'),
            style: primaryFilledButtonStyle(),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final daysCount = userPrefs?.numberOfDays ?? 3;
              final dailyCost = userPrefs?.budgetCategory == 'High'
                  ? 350.0
                  : (userPrefs?.budgetCategory == 'Low' ? 120.0 : 200.0);
              final totalCost = dailyCost * daysCount;

              final dailySchedules = <DailySchedule>[];
              for (int day = 0; day < daysCount; day++) {
                final dayStops = getDailyStops(day);
                dailySchedules.add(
                  DailySchedule(
                    scheduleId: '',
                    itineraryId: '',
                    dayNumber: day + 1,
                    scheduleDate: DateTime.now().add(Duration(days: day + 1)),
                    totalDistanceKm: SmartItineraryService.calculateRouteDistanceKm(dayStops),
                    stops: [
                      for (int i = 0; i < dayStops.length; i++)
                        ItineraryStop(
                          id: '',
                          scheduleId: '',
                          placeId: (dayStops[i].placeId != null && dayStops[i].placeId!.isNotEmpty)
                              ? dayStops[i].placeId!
                              : 'poi_${destination.toLowerCase().replaceAll(' ', '_')}_d${day + 1}_$i',
                          placeName: dayStops[i].title,
                          stopOrder: i + 1,
                          arrivalTime: dayStops[i].time.contains('-')
                              ? dayStops[i].time.split('-').first.trim()
                              : '09:00 AM',
                          departureTime: dayStops[i].time.contains('-')
                              ? dayStops[i].time.split('-').last.trim()
                              : '11:00 AM',
                          category: dayStops[i].category,
                          latitude: dayStops[i].latitude,
                          longitude: dayStops[i].longitude,
                          photoUrl: dayStops[i].photoUrls.isNotEmpty
                              ? dayStops[i].photoUrls.join('|')
                              : (dayStops[i].primaryPhotoUrl ?? ''),
                          photoUrls: dayStops[i].photoUrls,
                        ),
                    ],
                  ),
                );
              }

              final result = await SupabaseItineraryService().saveItinerary(
                title: '$destination Custom Schedule',
                destinationState: destination,
                totalCost: totalCost,
                dailySchedules: dailySchedules,
              );
              if (context.mounted) {
                Navigator.pop(context);
                showDemoSnackBar(
                  context,
                  result.message,
                  icon: result.success ? Icons.check_circle_outline : Icons.error_outline,
                );
              }
            },
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Save to Database'),
            style: demoOutlinedButtonStyle(),
          ),
        ],
      ),
    );
  }
}
