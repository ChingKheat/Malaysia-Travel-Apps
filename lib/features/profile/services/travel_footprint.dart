import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/models/itinerary_models.dart';
import 'package:smart_travel_planner/features/itinerary/services/scheduling_engine.dart';

class TravelFootprint {
  const TravelFootprint(this.places, this.regions);
  final List<String> places;
  final Set<String> regions;

  static const malaysiaRegions = {
    'johor',
    'kedah',
    'kelantan',
    'melaka',
    'negeri sembilan',
    'pahang',
    'penang',
    'perak',
    'perlis',
    'sabah',
    'sarawak',
    'selangor',
    'terengganu',
    'kuala lumpur',
    'labuan',
    'putrajaya',
  };

  static String? _region(String? value) {
    final input = value?.trim().toLowerCase().replaceFirst(
      RegExp(r'^(federal territory of |wilayah persekutuan )'),
      '',
    );
    final normalized = switch (input) {
      'malacca' => 'melaka',
      'pulau pinang' => 'penang',
      _ => input,
    };
    return malaysiaRegions.contains(normalized) ? normalized : null;
  }

  static Future<TravelFootprint> fromTrips(List<Itinerary> trips) async {
    SharedPreferences? store;
    try {
      store = await SharedPreferences.getInstance();
    } catch (_) {}
    final places = <String, String>{};
    final regions = <String>{};
    for (final trip in trips) {
      for (final (index, day) in trip.dailySchedules.indexed) {
        final key =
            'trip-execution-v1:${trip.itineraryId}:$index:${day.scheduleDate.toIso8601String()}';
        var completed = <String>{};
        try {
          final progress = jsonDecode(store?.getString(key) ?? '{}');
          if (progress is Map && progress['completed'] is List) {
            completed = (progress['completed'] as List)
                .whereType<String>()
                .toSet();
          }
        } catch (_) {
          // Ignore malformed progress without losing verified itinerary visits.
        }
        for (final stop in day.stops) {
          final place = stop.toTravelStop();
          final id = SchedulingEngine.identity(place);
          if (!stop.isVisited && !completed.contains(id)) continue;
          places[id] = place.title;
          final region = _region(stop.placeState);
          if (region != null) regions.add(region);
        }
      }
    }
    return TravelFootprint(places.values.toList(), regions);
  }
}
