import 'package:smart_travel_planner/features/places/services/google_places_service.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smart_travel_planner/features/places/services/place_catalog_service.dart';
import 'package:smart_travel_planner/features/places/data/curated_attractions.dart';
import 'package:smart_travel_planner/shared/services/weather_service.dart';

class AssistantToolHandler {
  AssistantToolHandler({PlaceCatalogService? places, WeatherService? weather})
    : _places = places ?? PlaceCatalogService(),
      _weather = weather ?? WeatherService();

  final PlaceCatalogService _places;
  final WeatherService _weather;
  final _google = GooglePlacesService();

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
          'date': {
            'type': 'STRING',
            'description': 'Requested local date YYYY-MM-DD',
          },
          'time': {
            'type': 'STRING',
            'description': 'Requested local HH:mm, if specified',
          },
        },
        'required': ['city', 'date'],
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
          'reference_location': {
            'type': 'STRING',
            'description':
                'Traveler-supplied landmark or city for distance ranking',
          },
          'indoor_only': {'type': 'BOOLEAN'},
        },
        'required': ['keyword'],
      },
    },
    {
      'name': 'add_to_itinerary',
      'description':
          'Prepare a preview for adding a catalog place. Only include trip, date, day and times explicitly supplied by the traveler. The traveler confirms in the app.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'place_id': {'type': 'STRING'},
          'trip_title': {'type': 'STRING'},
          'date': {'type': 'STRING', 'description': 'YYYY-MM-DD'},
          'day_number': {'type': 'INTEGER'},
          'arrival_time': {'type': 'STRING', 'description': '24-hour HH:mm'},
          'departure_time': {'type': 'STRING', 'description': '24-hour HH:mm'},
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
          final input = args['city']?.toString().trim() ?? '';
          final city = input.toLowerCase() == 'kl' ? 'Kuala Lumpur' : input;
          final rawDate = args['date']?.toString() ?? '';
          final date = DateTime.tryParse(rawDate);
          final time = args['time']?.toString();
          final unavailable = {
            'success': false,
            'city': city,
            'forecast_date': rawDate,
            'forecast_time': time,
          };
          if (date == null ||
              city.isEmpty ||
              date.toIso8601String().split('T').first != rawDate ||
              !WeatherService.stateCoordinates.containsKey(
                city.toLowerCase(),
              )) {
            return unavailable;
          }
          final forecast = await _weather.getForecastForDate(
            state: city,
            date: date,
            localTime: time,
          );
          if (!forecast.isAvailable) return unavailable;
          return {
            'success': true,
            'city': forecast.locationState,
            'temperature_c': forecast.temperatureC,
            'condition': forecast.condition,
            if (forecast.hasRainProbability)
              'rain_probability_percent': forecast.rainProbability,
            'forecast_date': rawDate,
            'forecast_time': forecast.localTime,
            'cached': forecast.isCached,
          };
        case 'search_malaysia_places':
          final rows = await catalog();
          final keyword = (args['keyword']?.toString() ?? '').toLowerCase();
          final category = (args['category']?.toString() ?? '').toLowerCase();
          final indoor = args['indoor_only'] == true;
          final reference = args['reference_location']?.toString().trim() ?? '';
          final normalized = reference.toLowerCase();
          final named = rows.where(
            (row) => row['name']?.toString().trim().toLowerCase() == normalized,
          );
          final point = category == 'food' && normalized.isNotEmpty
              ? (named.length == 1 ? _coordinates(named.first) : null) ??
                    WeatherService.stateCoordinates[normalized == 'kl'
                        ? 'kuala lumpur'
                        : normalized]
              : null;
          final candidates = rows.where((row) {
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
          }).toList();
          final resolved = await _google.hydrateRows(
            candidates.where(
              (row) =>
                  PlaceCatalogService.isGoogleReference(row) &&
                  !PlaceCatalogService.hasLocationDetails(row),
            ),
            limit: 8,
          );
          final matches =
              [
                    ...candidates.where(
                      (row) =>
                          !PlaceCatalogService.isGoogleReference(row) ||
                          PlaceCatalogService.hasLocationDetails(row),
                    ),
                    ...resolved,
                  ]
                  .where(_hasName)
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
                      if (category == 'food') 'is_halal': row['is_halal'],
                      if ((point, _coordinates(row)) case (
                        final origin?,
                        final candidate?,
                      ))
                        'distance_km':
                            Geolocator.distanceBetween(
                              origin.$1,
                              origin.$2,
                              candidate.$1,
                              candidate.$2,
                            ) /
                            1000,
                    },
                  )
                  .toList();
          if (point != null) {
            matches.sort(
              (a, b) => ((a['distance_km'] as double?) ?? double.infinity)
                  .compareTo((b['distance_km'] as double?) ?? double.infinity),
            );
          }
          return {
            'success': true,
            'reference_location': point == null ? null : reference,
            'offline_catalog': _places.lastLoadOffline,
            'places': matches.take(8).toList(),
          };
        case 'add_to_itinerary':
          return await _preview(args);
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

  static (double, double)? _coordinates(Map<String, dynamic> row) {
    final lat = row['latitude'];
    final lng = row['longitude'];
    if (lat is! num ||
        lng is! num ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180 ||
        (lat == 0 && lng == 0)) {
      return null;
    }
    return (lat.toDouble(), lng.toDouble());
  }

  Future<List<Map<String, dynamic>>> catalog() async {
    final rows = await _places.load();
    final names = {
      for (final row in rows) row['name']?.toString().trim().toLowerCase(),
    };
    final ids = {for (final row in rows) row['place_id']};
    return [
      ...rows,
      for (final place in curatedMalaysianAttractions)
        if (!ids.contains(place.xid) &&
            !names.contains(place.name.toLowerCase()))
          {
            'place_id': place.xid,
            'name': place.name,
            'category': place.category,
            'latitude': place.latitude,
            'longitude': place.longitude,
          },
    ];
  }

  bool _hasName(Map<String, dynamic> row) {
    final name = row['name']?.toString().trim().toLowerCase();
    return name != null &&
        name.isNotEmpty &&
        name != 'saved google place' &&
        row['_loadError'] == null;
  }

  Future<Map<String, dynamic>> _preview(Map<String, dynamic> args) async {
    final rows = await catalog();
    final candidates = rows.where((row) => row['place_id'] == args['place_id']);
    for (final row in await _google.hydrateRows(candidates, limit: 1)) {
      if (!_hasName(row)) continue;
      return {
        'success': true,
        'confirmation_required': true,
        'proposal': {
          'proposal_id': const Uuid().v4(),
          'trip_title': args['trip_title'],
          'date': args['date'],
          'day_number': args['day_number'],
          'arrival_time': args['arrival_time'],
          'departure_time': args['departure_time'],
          'place_id': row['place_id'],
          'place_name': row['name'],
          'category': row['category'],
          'state': row['state'],
          'latitude': row['latitude'],
          'longitude': row['longitude'],
        },
      };
    }
    return {
      'success': false,
      'error': 'That place is unavailable in the catalog.',
    };
  }
}
