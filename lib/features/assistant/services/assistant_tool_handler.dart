import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/local_itinerary_store.dart';
import 'package:smart_travel_planner/features/places/services/place_catalog_service.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';
import 'package:smart_travel_planner/shared/services/weather_service.dart';

class AssistantToolHandler {
  AssistantToolHandler({
    PlaceCatalogService? places,
    WeatherService? weather,
    LocalItineraryStore? itineraries,
  }) : _places = places ?? PlaceCatalogService(),
       _weather = weather ?? WeatherService(),
       _itineraries = itineraries ?? LocalItineraryStore();

  final PlaceCatalogService _places;
  final WeatherService _weather;
  final LocalItineraryStore _itineraries;

  static const declarations = [
    {
      'name': 'get_weather_forecast',
      'description':
          'Get actual cached/live OpenWeatherMap forecast for a Malaysian city or destination.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'city': {
            'type': 'STRING',
            'description': 'Malaysian city, state, or destination',
          },
        },
        'required': ['city'],
      },
    },
    {
      'name': 'search_malaysia_places',
      'description': 'Search places in the application catalog.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'keyword': {'type': 'STRING'},
          'category': {
            'type': 'STRING',
            'enum': ['attraction', 'food', 'culture', 'shopping', 'nature'],
          },
          'indoor_only': {'type': 'BOOLEAN'},
        },
        'required': ['keyword'],
      },
    },
    {
      'name': 'add_to_itinerary',
      'description':
          'Add a catalog place by place_id to the most recently saved trip, on its first day.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'place_id': {'type': 'STRING'},
        },
        'required': ['place_id'],
      },
    },
  ];

  Future<Map<String, dynamic>> execute(
    String name,
    Map<String, dynamic> args,
  ) async {
    try {
      switch (name) {
        case 'get_weather_forecast':
          final city = args['city']?.toString().trim() ?? '';
          if (city.isEmpty)
            return {'success': false, 'error': 'A Malaysian city is required.'};
          final forecast = await _weather.getForecastForDate(
            state: city,
            date: DateTime.now(),
          );
          if (!forecast.isAvailable)
            return {
              'success': false,
              'city': city,
              'error': 'Weather forecast unavailable for this destination.',
            };
          if (forecast.rainProbability == 20.0 &&
              forecast.adviceText == 'Clear and pleasant for outdoor sights.') {
            // Existing WeatherService substitutes a demo probability when
            // OpenWeatherMap omits `pop`; do not present it as verified.
            return {
              'success': true,
              'city': city,
              'temperature_c': forecast.temperatureC,
              'condition': forecast.condition,
              'advisory':
                  'Precipitation probability was not provided by the weather response.',
              'forecast_date': forecast.scheduleDate
                  .toIso8601String()
                  .split('T')
                  .first,
            };
          }
          return {
            'success': true,
            'city': city,
            'temperature_c': forecast.temperatureC,
            'condition': forecast.condition,
            'rain_probability_percent': forecast.rainProbability,
            'advisory': forecast.adviceText,
            'forecast_date': forecast.scheduleDate
                .toIso8601String()
                .split('T')
                .first,
          };
        case 'search_malaysia_places':
          final rows = await _places.load();
          final keyword = (args['keyword']?.toString() ?? '').toLowerCase();
          final category = (args['category']?.toString() ?? '').toLowerCase();
          final indoor = args['indoor_only'] == true;
          final matches = rows
              .where((row) {
                final text = '${row['name']} ${row['category']} ${row['state']}'
                    .toLowerCase();
                final cat = (row['category']?.toString() ?? '').toLowerCase();
                final categoryMatch =
                    category.isEmpty ||
                    cat.contains(category) ||
                    (category == 'attraction' && cat.contains('attraction')) ||
                    (category == 'food' && PlaceCatalogService.isMeal(row));
                return text.contains(keyword) &&
                    categoryMatch &&
                    (!indoor || row['is_indoor'] == true);
              })
              .take(8)
              .map(
                (row) => {
                  'place_id': row['place_id'],
                  'name': row['name'],
                  'category': row['category'],
                  'state': row['state'],
                  'rating': row['rating'],
                  'latitude': row['latitude'],
                  'longitude': row['longitude'],
                  'is_indoor': row['is_indoor'],
                  'photo_url': row['photo_url'],
                },
              )
              .toList();
          return {
            'success': true,
            'offline_catalog': _places.lastLoadOffline,
            'places': matches,
          };
        case 'add_to_itinerary':
          return await _addToItinerary(args['place_id']?.toString() ?? '');
        default:
          return {'success': false, 'error': 'Unknown assistant tool.'};
      }
    } catch (_) {
      return {
        'success': false,
        'error': 'The requested travel service is currently unavailable.',
      };
    }
  }

  Future<Map<String, dynamic>> _addToItinerary(String placeId) async {
    final userId = AuthService().currentUser?.uid;
    if (userId == null || userId.isEmpty)
      return {
        'success': false,
        'error': 'Sign in to add a place to a saved itinerary.',
      };
    final rows = await _places.load();
    final matches = rows.where((row) => row['place_id'] == placeId);
    if (matches.isEmpty)
      return {
        'success': false,
        'error': 'That place is no longer in the available catalog.',
      };
    final place = matches.first;
    final journal = await _itineraries.read(userId);
    final records =
        journal.entries
            .where(
              (entry) =>
                  entry.value is Map && (entry.value as Map)['trip'] is Map,
            )
            .toList()
          ..sort(
            (a, b) => ((b.value as Map)['trip'] as Map)['created_at']
                .toString()
                .compareTo(
                  ((a.value as Map)['trip'] as Map)['created_at'].toString(),
                ),
          );
    if (records.isEmpty)
      return {
        'success': false,
        'error': 'Create or save an itinerary before adding places.',
      };
    final record = Map<String, dynamic>.from(records.first.value as Map);
    final trip = Map<String, dynamic>.from(record['trip'] as Map);
    final days = (trip['daily_schedules'] as List? ?? [])
        .map((d) => Map<String, dynamic>.from(d as Map))
        .toList();
    if (days.isEmpty)
      return {
        'success': false,
        'error': 'The selected itinerary has no day available.',
      };
    final day = days.first;
    final stops = (day['itinerary_stops'] as List? ?? [])
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();
    if (stops.any((stop) => stop['place_id'] == placeId))
      return {
        'success': false,
        'error': 'This place is already on the selected day.',
      };
    final now = DateTime.now();
    final snapshot = TravelStop(
      title: place['name']?.toString() ?? 'Attraction',
      time: '09:00 - 10:30',
      note: '${place['category'] ?? 'Attraction'} • Added by travel assistant',
      description: 'Scheduled visit.',
      duration: '90 min',
      openingHours: 'Hours unverified',
      tips: const [],
      icon: Icons.place,
      color: const Color(0xFF6652E8),
      category: place['category']?.toString() ?? 'Attraction',
      placeId: placeId,
      latitude: (place['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (place['longitude'] as num?)?.toDouble() ?? 0,
      isIndoor: place['is_indoor'] as bool?,
    ).toJson();
    stops.add({
      'id': const Uuid().v4(),
      'schedule_id': day['schedule_id'],
      'place_id': placeId,
      'place_name': place['name'],
      'stop_order': stops.length + 1,
      'arrival_time': '09:00:00',
      'departure_time': '10:30:00',
      'is_visited': false,
      'place_state': place['state'],
      'category': place['category'],
      'latitude': place['latitude'],
      'longitude': place['longitude'],
      'snapshot': snapshot,
    });
    day['itinerary_stops'] = stops;
    trip['daily_schedules'] = days;
    record['trip'] = trip;
    record['pending'] = true;
    record['updated_at'] = now.toIso8601String();
    journal[records.first.key] = record;
    await _itineraries.write(userId, journal);
    return {
      'success': true,
      'place_id': placeId,
      'place_name': place['name'],
      'itinerary_title': trip['title'],
      'day_number': day['day_number'] ?? 1,
      'synced': false,
    };
  }
}
