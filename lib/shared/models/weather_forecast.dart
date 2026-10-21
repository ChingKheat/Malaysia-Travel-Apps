import 'package:flutter/material.dart';

/// Represents a weather snapshot recorded for an itinerary schedule (Table 4.8 in FYP 1 Report)
class WeatherForecast {
  final String id;
  final String itineraryId;
  final String locationState;
  final DateTime scheduleDate;
  final String condition;
  final double rainProbability;
  final double temperatureC;
  final String adviceText;
  final bool isAvailable;

  const WeatherForecast({
    this.id = '',
    required this.itineraryId,
    required this.locationState,
    required this.scheduleDate,
    required this.condition,
    required this.rainProbability,
    this.temperatureC = 30.0,
    this.adviceText = '',
    this.isAvailable = true,
  });

  /// Evaluates whether current day's weather is suitable for outdoor attractions
  bool get isSuitableForOutdoor {
    final lower = condition.toLowerCase();
    if (lower.contains('thunder') ||
        lower.contains('storm') ||
        lower.contains('heavy rain')) {
      return false;
    }
    return rainProbability < 55.0;
  }

  /// User-facing status badge label
  String get suitabilityBadge {
    if (!isAvailable) return 'Forecast unavailable';
    if (isSuitableForOutdoor) {
      return 'Outdoor Friendly';
    } else if (rainProbability >= 70.0) {
      return 'High Rain Risk (Indoor Recommended)';
    } else {
      return 'Scattered Showers (Carry Umbrella)';
    }
  }

  /// Badge color
  Color get badgeColor {
    if (!isAvailable) return const Color(0xFF64748B);
    if (isSuitableForOutdoor) {
      return const Color(0xFF16A34A); // Green
    } else if (rainProbability >= 70.0) {
      return const Color(0xFFDC2626); // Red
    } else {
      return const Color(0xFFD97706); // Amber
    }
  }

  factory WeatherForecast.fromSupabase(Map<String, dynamic> data) {
    return WeatherForecast(
      id: data['id']?.toString() ?? '',
      itineraryId: data['itinerary_id']?.toString() ?? '',
      locationState: data['location_state']?.toString() ?? '',
      scheduleDate: data['schedule_date'] != null
          ? DateTime.tryParse(data['schedule_date'].toString()) ??
                DateTime.now()
          : DateTime.now(),
      condition: data['condition']?.toString() ?? 'Partly Cloudy',
      rainProbability: (data['rain_probability'] as num?)?.toDouble() ?? 20.0,
      temperatureC: (data['temperature_c'] as num?)?.toDouble() ?? 30.0,
      adviceText: data['advice_text']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'itinerary_id': itineraryId,
      'location_state': locationState,
      'schedule_date': scheduleDate.toIso8601String().split('T').first,
      'condition': condition,
      'rain_probability': rainProbability,
    };
  }
}
