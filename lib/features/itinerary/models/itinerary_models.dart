import 'package:flutter/material.dart';
import 'package:smart_travel_planner/features/places/data/curated_attractions.dart';
import 'saved_trip.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';
import 'trip_preferences.dart';

/// Represents a scheduled stop in an itinerary (Table 4.5 in FYP 1 Report)
class ItineraryStop {
  final String id;
  final String scheduleId;
  final String placeId;
  final String placeName;
  final int stopOrder;
  final String arrivalTime;
  final String departureTime;
  final bool isVisited;
  final String category;
  final String photoUrl;
  final List<String> photoUrls;
  final double latitude;
  final double longitude;
  final TravelStop? snapshot;

  const ItineraryStop({
    required this.id,
    required this.scheduleId,
    required this.placeId,
    required this.placeName,
    required this.stopOrder,
    required this.arrivalTime,
    required this.departureTime,
    this.isVisited = false,
    this.category = 'Attraction',
    this.photoUrl = '',
    this.photoUrls = const [],
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.snapshot,
  });

  factory ItineraryStop.fromSupabase(Map<String, dynamic> data) {
    final snapshot = data['stop_data'] as Map<String, dynamic>? ?? data;
    final place = data['places'] as Map<String, dynamic>? ?? {};
    final rawPhoto =
        place['photo_url']?.toString() ?? data['photo_url']?.toString() ?? '';
    final parsedPhotos = rawPhoto.isNotEmpty
        ? (rawPhoto.contains('|')
              ? rawPhoto.split('|').where((s) => s.trim().isNotEmpty).toList()
              : [rawPhoto])
        : <String>[];

    return ItineraryStop(
      snapshot: snapshot['snapshot'] is Map
          ? TravelStop.fromJson(
              Map<String, dynamic>.from(snapshot['snapshot'] as Map),
            )
          : null,
      id: data['id']?.toString() ?? '',
      scheduleId: data['schedule_id']?.toString() ?? '',
      placeId: data['place_id']?.toString() ?? '',
      placeName:
          place['name']?.toString() ??
          data['place_name']?.toString() ??
          'Attraction',
      stopOrder: (data['stop_order'] as num?)?.toInt() ?? 1,
      arrivalTime: data['arrival_time']?.toString() ?? '09:00',
      departureTime: data['departure_time']?.toString() ?? '11:00',
      isVisited: data['is_visited'] == true,
      category:
          place['category']?.toString() ??
          data['category']?.toString() ??
          'Attraction',
      photoUrl: rawPhoto,
      photoUrls: parsedPhotos,
      latitude:
          (place['latitude'] as num? ?? data['latitude'] as num?)?.toDouble() ??
          0.0,
      longitude:
          (place['longitude'] as num? ?? data['longitude'] as num?)
              ?.toDouble() ??
          0.0,
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'schedule_id': scheduleId,
      'place_id': placeId,
      'stop_order': stopOrder,
      'arrival_time': arrivalTime,
      'departure_time': departureTime,
      'is_visited': isVisited,
    };
  }

  /// Converts a database stop into a UI-renderable TravelStop
  TravelStop toTravelStop() {
    if (snapshot != null) return snapshot!;
    if (placeId.startsWith('ChIJ') ||
        photoUrl.contains('places.googleapis.com')) {
      return TravelStop.fromJson({
        'data_source': 'google',
        'place_id': placeId,
        'time': '$arrivalTime - $departureTime',
        'duration': '90 min',
      });
    }
    final isDining =
        category.toLowerCase().contains('dining') ||
        category.toLowerCase().contains('food') ||
        category.toLowerCase().contains('restaurant');
    final resolvedPhotos = photoUrls.isNotEmpty
        ? photoUrls
        : (photoUrl.isNotEmpty
              ? (photoUrl.contains('|')
                    ? photoUrl
                          .split('|')
                          .where((s) => s.trim().isNotEmpty)
                          .toList()
                    : [photoUrl])
              : const <String>[]);

    double resolvedLat = latitude;
    double resolvedLng = longitude;
    if (resolvedLat == 0.0 ||
        resolvedLng == 0.0 ||
        (resolvedLat == 3.140853 && resolvedLng == 101.693207)) {
      final normName = placeName.toLowerCase().trim();
      for (final a in curatedMalaysianAttractions) {
        final aNorm = a.name.toLowerCase().trim();
        if (normName == aNorm ||
            (normName.length > 3 && aNorm.contains(normName)) ||
            (aNorm.length > 3 && normName.contains(aNorm))) {
          resolvedLat = a.latitude;
          resolvedLng = a.longitude;
          break;
        }
      }
    }

    return TravelStop(
      estimatedCost: isDining ? 25 : 40,
      title: placeName,
      time: '$arrivalTime - $departureTime',
      note: '$category • Database Saved',
      description: 'Scheduled visit to $placeName.',
      duration: '1 h 30 min',
      openingHours: 'Hours unverified',
      category: category,
      photoUrls: resolvedPhotos,
      tips: ['Category: $category', 'Saved from your custom itinerary'],
      icon: isDining ? Icons.restaurant : Icons.place,
      color: isDining ? const Color(0xFFFF8A3D) : const Color(0xFF6652E8),
      placeId: placeId,
      latitude: resolvedLat,
      longitude: resolvedLng,
    );
  }
}

/// Represents one day in a multi-day itinerary (Table 4.4 in FYP 1 Report)
class DailySchedule {
  final String scheduleId;
  final String itineraryId;
  final int dayNumber;
  final DateTime scheduleDate;
  final double totalDistanceKm;
  final List<ItineraryStop> stops;

  const DailySchedule({
    required this.scheduleId,
    required this.itineraryId,
    required this.dayNumber,
    required this.scheduleDate,
    this.totalDistanceKm = 0.0,
    this.stops = const [],
  });

  factory DailySchedule.fromSupabase(Map<String, dynamic> data) {
    final stopsRaw = data['itinerary_stops'] as List<dynamic>? ?? [];
    final loadedStops =
        stopsRaw
            .map((s) => ItineraryStop.fromSupabase(s as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.stopOrder.compareTo(b.stopOrder));

    return DailySchedule(
      scheduleId: data['schedule_id']?.toString() ?? '',
      itineraryId: data['itinerary_id']?.toString() ?? '',
      dayNumber: (data['day_number'] as num?)?.toInt() ?? 1,
      scheduleDate: data['schedule_date'] != null
          ? DateTime.tryParse(data['schedule_date'].toString()) ??
                DateTime.now()
          : DateTime.now(),
      totalDistanceKm: (data['total_distance_km'] as num?)?.toDouble() ?? 0.0,
      stops: loadedStops,
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      if (scheduleId.isNotEmpty) 'schedule_id': scheduleId,
      'itinerary_id': itineraryId,
      'day_number': dayNumber,
      'schedule_date': scheduleDate.toIso8601String().split('T').first,
      'total_distance_km': totalDistanceKm,
    };
  }
}

/// Master class for travel itinerary (Table 4.3 in FYP 1 Report)
class Itinerary {
  final String itineraryId;
  final String userId;
  final String title;
  final String destinationState;
  final double totalCost;
  final bool isPublic;
  final DateTime createdAt;
  final List<DailySchedule> dailySchedules;
  final TripPreferences? preferences;

  const Itinerary({
    required this.itineraryId,
    required this.userId,
    required this.title,
    required this.destinationState,
    this.totalCost = 0.0,
    this.isPublic = false,
    required this.createdAt,
    this.dailySchedules = const [],
    this.preferences,
  });

  factory Itinerary.fromSupabase(Map<String, dynamic> data) {
    final schedulesRaw = data['daily_schedules'] as List<dynamic>? ?? [];
    final loadedSchedules =
        schedulesRaw
            .map((ds) => DailySchedule.fromSupabase(ds as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));

    return Itinerary(
      preferences:
          data['preferences'] is Map && (data['preferences'] as Map).isNotEmpty
          ? TripPreferences.fromJson(
              Map<String, dynamic>.from(data['preferences'] as Map),
            )
          : null,
      itineraryId: data['itinerary_id']?.toString() ?? '',
      userId: data['user_id']?.toString() ?? '',
      title: data['title']?.toString() ?? 'My Itinerary',
      destinationState: data['destination_state']?.toString() ?? 'Kuala Lumpur',
      totalCost: (data['total_cost'] as num?)?.toDouble() ?? 0.0,
      isPublic: data['is_public'] == true,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      dailySchedules: loadedSchedules,
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      if (itineraryId.isNotEmpty) 'itinerary_id': itineraryId,
      'preferences': preferences?.toJson() ?? {},
      'user_id': userId,
      'title': title,
      'destination_state': destinationState,
      'total_cost': totalCost,
      'is_public': isPublic,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Converts to SavedTrip for backwards-compatible UI widgets
  SavedTrip toSavedTrip() {
    final daysCount = dailySchedules.isEmpty ? 1 : dailySchedules.length;
    final totalStops = dailySchedules.fold<int>(
      0,
      (sum, day) => sum + day.stops.length,
    );

    return SavedTrip(
      title: title,
      date:
          '${(dailySchedules.isEmpty ? createdAt : dailySchedules.first.scheduleDate).day} ${_monthName((dailySchedules.isEmpty ? createdAt : dailySchedules.first.scheduleDate).month)} ${(dailySchedules.isEmpty ? createdAt : dailySchedules.first.scheduleDate).year} ($daysCount Days)',
      detail:
          '$totalStops stops • RM ${totalCost.toStringAsFixed(0)} estimated',
      destination: destinationState,
      budget:
          preferences?.budgetCategory ??
          (totalCost / daysCount > 200
              ? 'High'
              : totalCost / daysCount > 120
              ? 'Medium'
              : 'Low'),
      interests: preferences?.interests ?? const ['Culture', 'Food'],
      totalDays: daysCount,
    );
  }

  static String _monthName(int month) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month >= 1 && month <= 12) return m[month - 1];
    return '';
  }
}
