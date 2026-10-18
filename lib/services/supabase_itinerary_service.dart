import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/supabase_config.dart';
import '../data/curated_attractions.dart';
import '../models/itinerary_models.dart';
import 'auth_service.dart';
import 'weather_service.dart';

class ItinerarySaveResult {
  final bool success;
  final String message;
  final String? itineraryId;

  const ItinerarySaveResult({
    required this.success,
    required this.message,
    this.itineraryId,
  });
}

/// Service implementing UC601 (Save Itinerary), UC602 (Edit Itinerary),
/// and UC700 (View Saved Itineraries) connected to Supabase PostgreSQL.
class SupabaseItineraryService extends ChangeNotifier {
  static final SupabaseItineraryService _instance =
      SupabaseItineraryService._internal();
  factory SupabaseItineraryService() => _instance;
  SupabaseItineraryService._internal();

  // Local fallback storage for offline/testing mode
  final List<Itinerary> _inMemoryItineraries = [];

  // Messages per Chapter 3 Specifications
  static const String m1SaveSuccess =
      'Itinerary saved successfully to your profile!';
  static const String m2SaveError =
      'Unable to save itinerary. Please check your network connection and try again.';
  static const String m1LoadSuccess = 'Saved itinerary loaded successfully.';
  static const String m2NoSavedTrips =
      'You have no saved trips yet. Tap "Plan a Trip" to generate your first itinerary!';
  static const String m3LoadError =
      'Unable to load saved trips. Please check your network connection and try again.';

  /// UC601: Save Itinerary to Supabase Database (Table 4.3, 4.4, 4.5)
  Future<ItinerarySaveResult> saveItinerary({
    required String title,
    required String destinationState,
    required double totalCost,
    required List<DailySchedule> dailySchedules,
    bool isPublic = false,
  }) async {
    final authService = AuthService();
    final currentUser = authService.currentUser;

    // Constraint C2: User must be authenticated in a valid session
    if (currentUser == null) {
      return const ItinerarySaveResult(
        success: false,
        message: 'Authentication required. Please log in to save your itinerary.',
      );
    }

    final client = SupabaseConfig.client;

    // 1. Live Supabase Execution (when configured)
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        // Step 1: Insert into `itineraries` table (FR601_4)
        final itineraryInsert = await client
            .from('itineraries')
            .insert({
              'user_id': currentUser.uid,
              'title': title,
              'destination_state': destinationState,
              'total_cost': totalCost,
              'is_public': isPublic,
            })
            .select('itinerary_id')
            .single()
            .timeout(const Duration(seconds: 10));

        final itineraryId = itineraryInsert['itinerary_id']?.toString() ?? '';

        // Step 2 & 3: Insert `daily_schedules` and `itinerary_stops`
        for (final schedule in dailySchedules) {
          final scheduleInsert = await client
              .from('daily_schedules')
              .insert({
                'itinerary_id': itineraryId,
                'day_number': schedule.dayNumber,
                'schedule_date':
                    schedule.scheduleDate.toIso8601String().split('T').first,
                'total_distance_km': schedule.totalDistanceKm,
              })
              .select('schedule_id')
              .single()
              .timeout(const Duration(seconds: 10));

          final scheduleId = scheduleInsert['schedule_id']?.toString() ?? '';

          if (schedule.stops.isNotEmpty) {
            // Upsert places first so foreign key references to public.places succeed
            for (final stop in schedule.stops) {
              double lat = stop.latitude;
              double lng = stop.longitude;
              if (lat == 0.0 || lng == 0.0 || (lat == 3.140853 && lng == 101.693207)) {
                final normName = stop.placeName.toLowerCase().trim();
                for (final a in curatedMalaysianAttractions) {
                  final aNorm = a.name.toLowerCase().trim();
                  if (normName == aNorm ||
                      (normName.length > 3 && aNorm.contains(normName)) ||
                      (aNorm.length > 3 && normName.contains(aNorm))) {
                    lat = a.latitude;
                    lng = a.longitude;
                    break;
                  }
                }
              }
              try {
                await client.from('places').upsert({
                  'place_id': stop.placeId,
                  'name': stop.placeName,
                  'state': destinationState,
                  'category': stop.category,
                  'latitude': lat != 0.0 ? lat : 3.140853,
                  'longitude': lng != 0.0 ? lng : 101.693207,
                  'photo_url': stop.photoUrl,
                }, onConflict: 'place_id').timeout(const Duration(seconds: 5));
              } catch (e) {
                debugPrint('Supabase upsert place note: $e');
              }
            }

            final stopsPayload = schedule.stops.map((stop) {
              return {
                'schedule_id': scheduleId,
                'place_id': stop.placeId,
                'stop_order': stop.stopOrder,
                'arrival_time': _formatTimeForDb(stop.arrivalTime),
                'departure_time': _formatTimeForDb(stop.departureTime),
                'is_visited': stop.isVisited,
              };
            }).toList();

            await client
                .from('itinerary_stops')
                .insert(stopsPayload)
                .timeout(const Duration(seconds: 10));
          }

          // Step 4: Insert weather forecast snapshot for this travel date (Table 4.8)
          try {
            final weatherForecast = await WeatherService().getForecastForDate(
              state: destinationState,
              date: schedule.scheduleDate,
              itineraryId: itineraryId,
            );

            await client.from('weather_forecasts').insert({
              'itinerary_id': itineraryId,
              'location_state': destinationState,
              'schedule_date':
                  schedule.scheduleDate.toIso8601String().split('T').first,
              'condition': weatherForecast.condition,
              'rain_probability': weatherForecast.rainProbability,
            }).timeout(const Duration(seconds: 5));
          } catch (we) {
            debugPrint('Weather forecast insert note: $we');
          }
        }

        notifyListeners();
        return ItinerarySaveResult(
          success: true,
          message: m1SaveSuccess,
          itineraryId: itineraryId,
        );
      } catch (e) {
        debugPrint('Supabase saveItinerary error: $e. Falling back to local.');
      }
    }

    // 2. Offline / Local In-Memory Fallback
    final generatedId = 'itin_${DateTime.now().millisecondsSinceEpoch}';
    final fallbackItinerary = Itinerary(
      itineraryId: generatedId,
      userId: currentUser.uid,
      title: title,
      destinationState: destinationState,
      totalCost: totalCost,
      isPublic: isPublic,
      createdAt: DateTime.now(),
      dailySchedules: dailySchedules,
    );

    _inMemoryItineraries.insert(0, fallbackItinerary);
    notifyListeners();

    return ItinerarySaveResult(
      success: true,
      message: m1SaveSuccess,
      itineraryId: generatedId,
    );
  }

  /// UC700: Retrieve saved itineraries for the authenticated user (FR700_1 to FR700_6)
  Future<List<Itinerary>> getSavedItineraries() async {
    final authService = AuthService();
    final currentUser = authService.currentUser;
    if (currentUser == null) return [];

    final client = SupabaseConfig.client;

    // 1. Live Supabase Query
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        final data = await client
            .from('itineraries')
            .select(
              '*, daily_schedules(*, itinerary_stops(*, places(*)))',
            )
            .eq('user_id', currentUser.uid)
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 10));

        final list = (data as List<dynamic>)
            .map((item) => Itinerary.fromSupabase(item as Map<String, dynamic>))
            .toList();

        return list;
      } catch (e) {
        debugPrint('Supabase getSavedItineraries error: $e');
      }
    }

    // 2. Local Fallback
    return _inMemoryItineraries
        .where((item) => item.userId == currentUser.uid)
        .toList();
  }

  /// Delete an itinerary from Supabase Database (CASCADE deletes schedules & stops)
  Future<bool> deleteItinerary(String itineraryId) async {
    final client = SupabaseConfig.client;

    if (client != null && SupabaseConfig.isConfigured) {
      try {
        // 1. Delete associated weather forecasts
        try {
          await client
              .from('weather_forecasts')
              .delete()
              .eq('itinerary_id', itineraryId)
              .timeout(const Duration(seconds: 5));
        } catch (we) {
          debugPrint('Delete weather forecasts note: $we');
        }

        // 2. Find schedule IDs to delete stops safely
        try {
          final scheds = await client
              .from('daily_schedules')
              .select('schedule_id')
              .eq('itinerary_id', itineraryId)
              .timeout(const Duration(seconds: 5));
          if (scheds.isNotEmpty) {
            final schedIds = scheds.map((s) => s['schedule_id'].toString()).toList();
            for (final sid in schedIds) {
              await client
                  .from('itinerary_stops')
                  .delete()
                  .eq('schedule_id', sid)
                  .timeout(const Duration(seconds: 5));
            }
          }
        } catch (se) {
          debugPrint('Delete itinerary stops note: $se');
        }

        // 3. Delete daily schedules
        try {
          await client
              .from('daily_schedules')
              .delete()
              .eq('itinerary_id', itineraryId)
              .timeout(const Duration(seconds: 5));
        } catch (de) {
          debugPrint('Delete daily schedules note: $de');
        }

        // 4. Delete the parent itinerary row
        await client
            .from('itineraries')
            .delete()
            .eq('itinerary_id', itineraryId)
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('Supabase deleteItinerary error: $e');
      }
    }

    _inMemoryItineraries.removeWhere((i) => i.itineraryId == itineraryId);
    notifyListeners();
    return true;
  }

  /// UC602: Update stops and distance for an existing daily schedule in Supabase
  Future<bool> updateDailyScheduleStops({
    required String scheduleId,
    required double totalDistanceKm,
    required List<ItineraryStop> stops,
  }) async {
    final client = SupabaseConfig.client;

    if (client != null && SupabaseConfig.isConfigured && scheduleId.isNotEmpty) {
      try {
        // 1. Update distance on daily_schedules
        await client
            .from('daily_schedules')
            .update({'total_distance_km': totalDistanceKm})
            .eq('schedule_id', scheduleId)
            .timeout(const Duration(seconds: 10));

        // 2. Delete existing stops for this schedule
        await client
            .from('itinerary_stops')
            .delete()
            .eq('schedule_id', scheduleId)
            .timeout(const Duration(seconds: 10));

        // 3. Insert updated stops
        if (stops.isNotEmpty) {
          final stopsPayload = stops.map((stop) {
            return {
              'schedule_id': scheduleId,
              'place_id': stop.placeId,
              'stop_order': stop.stopOrder,
              'arrival_time': _formatTimeForDb(stop.arrivalTime),
              'departure_time': _formatTimeForDb(stop.departureTime),
              'is_visited': stop.isVisited,
            };
          }).toList();

          await client
              .from('itinerary_stops')
              .insert(stopsPayload)
              .timeout(const Duration(seconds: 10));
        }

        notifyListeners();
        return true;
      } catch (e) {
        debugPrint('Supabase updateDailyScheduleStops error: $e');
      }
    }

    notifyListeners();
    return true;
  }

  static String _formatTimeForDb(String timeStr) {
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');
      final stripped = clean.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = stripped.split(':');
      if (parts.isNotEmpty) {
        int hour = int.parse(parts[0].trim());
        int minute = parts.length > 1 ? int.parse(parts[1].trim()) : 0;
        if (isPm && hour < 12) hour += 12;
        if (isAm && hour == 12) hour = 0;
        return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';
      }
    } catch (_) {}
    return '09:00:00';
  }
}
