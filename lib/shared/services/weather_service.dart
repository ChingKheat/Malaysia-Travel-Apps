import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:smart_travel_planner/core/config/api_keys.dart';
import 'package:smart_travel_planner/shared/models/weather_forecast.dart';

/// Real-time & forecast meteorological intelligence service.
/// Integrates with OpenWeatherMap REST API with offline/fallback resilience.
/// Conforms to FYP 1 Report: Chapter 2.6, Chapter 4.6 (Table 4.8).
class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  final http.Client _client = http.Client();
  final Map<String, (DateTime, List<dynamic>)> _cache = {};

  WeatherService.withClient(http.Client client) : _injectedClient = client;
  http.Client? _injectedClient;

  /// Known GPS center coordinates for Malaysian states and tourist territories
  static const Map<String, (double, double)> stateCoordinates = {
    'kuala lumpur': (3.1390, 101.6869),
    'penang': (5.4141, 100.3288),
    'george town': (5.4141, 100.3288),
    'melaka': (2.1896, 102.2501),
    'malacca': (2.1896, 102.2501),
    'selangor': (3.0738, 101.5183),
    'johor': (1.4927, 103.7414),
    'sabah': (5.9804, 116.0735),
    'sarawak': (1.5533, 110.3592),
    'kedah': (6.1184, 100.3685),
    'langkawi': (6.3500, 99.8000),
    'pahang': (3.8126, 103.3256),
    'cameron highlands': (4.4704, 101.3785),
    'perak': (4.5921, 101.0901),
    'ipoh': (4.5921, 101.0901),
    'terengganu': (5.3117, 103.1324),
    'kelantan': (6.1254, 102.2386),
    'negeri sembilan': (2.7258, 101.9424),
    'perlis': (6.4449, 100.2048),
  };

  /// Retrieves GPS center for a given Malaysian state/city
  (double, double) _getCoordinates(String state) {
    final clean = state.trim().toLowerCase();
    for (final entry in stateCoordinates.entries) {
      if (clean.contains(entry.key) || entry.key.contains(clean)) {
        return entry.value;
      }
    }
    return (3.1390, 101.6869); // Default: Kuala Lumpur central
  }

  /// Fetches real-time / 5-day forecast snapshot for an itinerary schedule date
  Future<WeatherForecast> getForecastForDate({
    required String state,
    required DateTime date,
    String itineraryId = '',
  }) async {
    final (lat, lng) = _getCoordinates(state);

    if (ApiKeys.hasOpenWeatherMapKey || _injectedClient != null) {
      try {
        final url = Uri.parse(
          'https://api.openweathermap.org/data/2.5/forecast'
          '?lat=$lat&lon=$lng&units=metric&appid=${ApiKeys.openWeatherMap}',
        );

        final cached = _cache[state.toLowerCase()];
        List<dynamic> list;
        if (cached != null &&
            DateTime.now().difference(cached.$1).inMinutes < 30) {
          list = cached.$2;
        } else {
          final response = await (_injectedClient ?? _client)
              .get(url)
              .timeout(const Duration(seconds: 8));
          if (response.statusCode != 200) {
            return unavailable(state, date, itineraryId);
          }
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          list = data['list'] as List<dynamic>? ?? [];
          _cache[state.toLowerCase()] = (DateTime.now(), list);
        }
        {
          final targetDateStr = date.toIso8601String().split('T').first;

          // Find slot on that date closest to midday (12:00 or 15:00)
          Map<String, dynamic>? bestMatch;
          for (final item in list) {
            final utc = DateTime.tryParse('${item['dt_txt']}Z');
            final local = utc?.add(const Duration(hours: 8));
            final dtTxt = local?.toIso8601String() ?? '';
            if (dtTxt.startsWith(targetDateStr)) {
              if (dtTxt.contains('12:00') || dtTxt.contains('15:00')) {
                bestMatch = item as Map<String, dynamic>;
                break;
              }
              bestMatch ??= item as Map<String, dynamic>;
            }
          }

          // Do not substitute a forecast from a different travel date.

          if (bestMatch != null) {
            final weatherArr = bestMatch['weather'] as List<dynamic>? ?? [];
            final mainWeather = weatherArr.isNotEmpty
                ? weatherArr.first['main']?.toString() ?? 'Clouds'
                : 'Clouds';
            final descWeather = weatherArr.isNotEmpty
                ? weatherArr.first['description']?.toString() ?? ''
                : '';
            final pop = ((bestMatch['pop'] as num?)?.toDouble() ?? 0.2) * 100.0;
            final main = bestMatch['main'] as Map<String, dynamic>? ?? {};
            final temp = (main['temp'] as num?)?.toDouble() ?? 30.5;

            final conditionTitle = descWeather.isNotEmpty
                ? descWeather
                      .split(' ')
                      .map(
                        (w) => w.isEmpty
                            ? ''
                            : '${w[0].toUpperCase()}${w.substring(1)}',
                      )
                      .join(' ')
                : mainWeather;

            return WeatherForecast(
              itineraryId: itineraryId,
              locationState: state,
              scheduleDate: date,
              condition: conditionTitle,
              rainProbability: double.parse(pop.toStringAsFixed(1)),
              temperatureC: double.parse(temp.toStringAsFixed(1)),
              adviceText: pop >= 60.0
                  ? 'Heavy rain anticipated. Indoor backup places recommended.'
                  : (pop >= 35.0
                        ? 'Afternoon showers possible. Carry an umbrella.'
                        : 'Clear and pleasant for outdoor sights.'),
            );
          }
        }
      } catch (e) {
        debugPrint(
          'OpenWeatherMap API live fetch notice: $e (Forecast unavailable)',
        );
      }
    }

    return unavailable(state, date, itineraryId);
  }

  static WeatherForecast unavailable(
    String state,
    DateTime date, [
    String itineraryId = '',
  ]) => WeatherForecast(
    itineraryId: itineraryId,
    locationState: state,
    scheduleDate: date,
    condition: 'Forecast unavailable',
    rainProbability: 0,
    isAvailable: false,
    adviceText:
        'Weather data is unavailable for this date. Check again closer to travel.',
  );

  /// Generates multi-day forecasts for a scheduled trip
  Future<List<WeatherForecast>> getMultiDayForecast({
    required String state,
    required List<DateTime> dates,
    String itineraryId = '',
  }) async {
    final results = <WeatherForecast>[];
    for (final date in dates) {
      final forecast = await getForecastForDate(
        state: state,
        date: date,
        itineraryId: itineraryId,
      );
      results.add(forecast);
    }
    return results;
  }
}
