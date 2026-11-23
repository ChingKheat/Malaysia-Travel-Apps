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
  final Map<String, (DateTime, List<dynamic>)> _googleCache = {};

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
  (double, double)? _getCoordinates(String state) {
    final clean = state.trim().toLowerCase();
    if (clean.isEmpty) return null;
    for (final entry in stateCoordinates.entries) {
      if (clean.contains(entry.key) || entry.key.contains(clean)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Fetches up to 10-day daily forecast snapshot from Google Maps Platform Weather API.
  Future<WeatherForecast?> _fetchGoogleWeather({
    required String state,
    required DateTime date,
    required double lat,
    required double lng,
    String itineraryId = '',
  }) async {
    final key = ApiKeys.googleMaps;
    if (key.trim().isEmpty) return null;

    try {
      final cached = _googleCache[state.toLowerCase()];
      List<dynamic> daysList;
      if (cached != null &&
          DateTime.now().difference(cached.$1).inMinutes < 30) {
        daysList = cached.$2;
      } else {
        final url = Uri.parse(
          'https://weather.googleapis.com/v1/forecast/days:lookup'
          '?key=$key&location.latitude=$lat&location.longitude=$lng&days=10&unitsSystem=METRIC',
        );
        var response = await (_injectedClient ?? _client)
            .get(url, headers: const {
              'X-Android-Package': 'com.example.smart_travel_planner',
              'X-Android-Cert': '3DA9D45DA96884FCF31911528985A3C5D62F593F',
            })
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 403) {
          // Retry without restriction headers in case key is unrestricted/server-side
          try {
            final unconstrained = await (_injectedClient ?? _client)
                .get(url)
                .timeout(const Duration(seconds: 6));
            if (unconstrained.statusCode == 200) {
              response = unconstrained;
            }
          } catch (_) {}
        }

        if (response.statusCode != 200) {
          debugPrint(
            'Google Weather API notice (${response.statusCode}): ${response.body}. Falling back to OpenWeatherMap.',
          );
          return null;
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        daysList = data['forecastDays'] as List<dynamic>? ?? [];
        _googleCache[state.toLowerCase()] = (DateTime.now(), daysList);
      }

      Map<String, dynamic>? bestMatch;
      for (final item in daysList) {
        if (item is! Map<String, dynamic>) continue;
        final displayDate = item['displayDate'] as Map<String, dynamic>?;
        if (displayDate != null) {
          final y = displayDate['year'] as int?;
          final m = displayDate['month'] as int?;
          final d = displayDate['day'] as int?;
          if (y == date.year && m == date.month && d == date.day) {
            bestMatch = item;
            break;
          }
        }
      }

      if (bestMatch != null) {
        final daytime = bestMatch['daytimeForecast'] as Map<String, dynamic>?;
        final condition =
            daytime?['weatherCondition']?['description']?['text']?.toString() ??
            'Partly Cloudy';
        final pop =
            (daytime?['precipitation']?['probability']?['percent'] as num?)
                ?.toDouble() ??
            0.0;
        final maxTemp =
            (bestMatch['maxTemperature']?['degrees'] as num?)?.toDouble() ??
            30.5;

        return WeatherForecast(
          itineraryId: itineraryId,
          locationState: state,
          scheduleDate: date,
          condition: condition,
          rainProbability: double.parse(pop.toStringAsFixed(1)),
          temperatureC: double.parse(maxTemp.toStringAsFixed(1)),
          adviceText: pop >= 60.0
              ? 'Heavy rain anticipated. Indoor backup places recommended.'
              : (pop >= 35.0
                    ? 'Afternoon showers possible. Carry an umbrella.'
                    : 'Clear and pleasant for outdoor sights.'),
        );
      }
    } catch (e) {
      debugPrint(
        'Google Weather API fetch notice: $e. Falling back to OpenWeatherMap.',
      );
    }
    return null;
  }

  /// Fetches real-time / multi-day forecast snapshot for an itinerary schedule date
  Future<WeatherForecast> getForecastForDate({
    required String state,
    required DateTime date,
    String itineraryId = '',
  }) async {
    final coordinates = _getCoordinates(state);
    if (coordinates == null) return unavailable(state, date, itineraryId);
    final (lat, lng) = coordinates;

    // 1. Try Google Maps Platform Weather API first (up to 10 days horizon).
    if (ApiKeys.hasGoogleMapsKey && _injectedClient == null) {
      final googleForecast = await _fetchGoogleWeather(
        state: state,
        date: date,
        lat: lat,
        lng: lng,
        itineraryId: itineraryId,
      );
      if (googleForecast != null) {
        return googleForecast;
      }
    }

    // 2. Fallback to OpenWeatherMap REST API (5-day horizon).

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
  ]) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diffDays = target.difference(today).inDays;
    final advice = diffDays > 5
        ? 'Weather forecast is available within 5 days of travel. Check again closer to your trip.'
        : 'Weather data is unavailable for this date. Check again closer to travel.';
    return WeatherForecast(
      itineraryId: itineraryId,
      locationState: state,
      scheduleDate: date,
      condition: 'Forecast unavailable',
      rainProbability: 0,
      isAvailable: false,
      adviceText: advice,
    );
  }

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
