import 'package:flutter/material.dart';
import 'package:smart_travel_planner/features/places/models/google_place_details.dart';

class TravelStop {
  const TravelStop({
    required this.title,
    required this.time,
    required this.note,
    required this.description,
    required this.duration,
    required this.openingHours,
    required this.tips,
    required this.icon,
    required this.color,
    this.category = 'Attraction',
    this.photoUrls = const [],
    this.placeId,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.estimatedCost = 0,
    this.visitMinutes = 90,
    this.isIndoor,
    this.operatingHours = const {},
    this.travelMinutes = 0,
    this.travelCost = 0,
    this.travelIsEstimated = true,
    this.dataSource = 'local',
    this.googleDetails,
  });

  final String title;
  final String time;
  final String note;
  final String description;
  final String duration;
  final String openingHours;
  final List<String> tips;
  final IconData icon;
  final Color color;
  final String category;
  final List<String> photoUrls;
  final String? placeId;
  final double latitude;
  final double longitude;
  final double estimatedCost;
  final int visitMinutes;
  final bool? isIndoor;
  final Map<String, dynamic> operatingHours;
  final int travelMinutes;
  final double travelCost;
  final bool travelIsEstimated;
  final String dataSource;
  final GooglePlaceDetails? googleDetails;
  bool get isGooglePlace =>
      dataSource == 'google' ||
      googleDetails != null ||
      (placeId?.startsWith('ChIJ') ?? false);

  TravelStop withGoogleDetails(GooglePlaceDetails details) => TravelStop(
    title: details.name ?? 'Name unavailable',
    time: time,
    note: '${details.category ?? 'Category unavailable'} • Google Maps',
    description: details.description ?? 'Description unavailable',
    duration: duration,
    openingHours:
        (details.hours['weekdayDescriptions'] as List?)?.join('; ') ??
        'Hours unverified',
    tips: [
      details.rating == null
          ? 'Rating unavailable'
          : 'Rating: ${details.rating}',
      details.reviewCount == null
          ? 'Review count unavailable'
          : '${details.reviewCount} reviews',
      details.address ?? 'Address unavailable',
      'Google Maps',
    ],
    icon: icon,
    color: color,
    category: details.category ?? 'Attraction',
    placeId: details.id,
    latitude: details.latitude ?? 0,
    longitude: details.longitude ?? 0,
    estimatedCost: estimatedCost,
    visitMinutes: visitMinutes,
    isIndoor: isIndoor,
    operatingHours: details.hours,
    travelMinutes: travelMinutes,
    travelCost: travelCost,
    travelIsEstimated: travelIsEstimated,
    dataSource: 'google',
    googleDetails: details,
  );

  TravelStop scheduled(
    int start,
    int end, {
    int transit = 0,
    double transportCost = 0,
    bool estimated = true,
  }) => TravelStop(
    title: title,
    time: '${formatMinutes(start)} - ${formatMinutes(end)}',
    note: note,
    description: description,
    duration: '${end - start} min',
    openingHours: openingHours,
    tips: tips,
    icon: icon,
    color: color,
    category: category,
    photoUrls: photoUrls,
    placeId: placeId,
    latitude: latitude,
    longitude: longitude,
    estimatedCost: estimatedCost,
    visitMinutes: visitMinutes,
    isIndoor: isIndoor,
    operatingHours: operatingHours,
    travelMinutes: transit,
    travelCost: transportCost,
    travelIsEstimated: estimated,
    dataSource: dataSource,
    googleDetails: googleDetails,
  );

  Map<String, dynamic> toJson() => {
    'title': isGooglePlace ? 'Saved Google place' : title,
    'time': time,
    'note': isGooglePlace ? 'Connect to load Google place details' : note,
    'description': isGooglePlace
        ? 'Place details require an internet connection.'
        : description,
    'duration': duration,
    'opening_hours': isGooglePlace ? 'Hours unverified' : openingHours,
    'tips': isGooglePlace ? const <String>[] : tips,
    'category': isGooglePlace ? 'Attraction' : category,
    'photo_urls': isGooglePlace
        ? const <String>[]
        : photoUrls
              .where(
                (url) =>
                    !url.contains('places.googleapis.com') &&
                    !url.contains('key='),
              )
              .toList(),
    'place_id': placeId,
    'latitude': isGooglePlace ? 0 : latitude,
    'longitude': isGooglePlace ? 0 : longitude,
    'estimated_cost': estimatedCost,
    'visit_minutes': visitMinutes,
    'is_indoor': isIndoor,
    'operating_hours': isGooglePlace
        ? const <String, dynamic>{}
        : operatingHours,
    'data_source': isGooglePlace ? 'google' : dataSource,
    'travel_minutes': travelMinutes,
    'travel_cost': travelCost,
    'travel_is_estimated': travelIsEstimated,
  };

  factory TravelStop.fromJson(Map<String, dynamic> json) {
    final google =
        json['data_source'] == 'google' ||
        (json['place_id']?.toString().startsWith('ChIJ') ?? false) ||
        (json['photo_urls'] as List? ?? []).any(
          (url) => url.toString().contains('places.googleapis.com'),
        );
    final stop = TravelStop(
      title: json['title'] as String? ?? 'Attraction',
      time: json['time'] as String? ?? '',
      note: json['note'] as String? ?? '',
      description: json['description'] as String? ?? '',
      duration: json['duration'] as String? ?? '90 min',
      openingHours: json['opening_hours'] as String? ?? 'Hours unverified',
      tips: (json['tips'] as List? ?? []).cast<String>(),
      icon: Icons.place,
      color: const Color(0xFF6652E8),
      category: json['category'] as String? ?? 'Attraction',
      photoUrls: (json['photo_urls'] as List? ?? []).cast<String>(),
      placeId: json['place_id'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble() ?? 0,
      visitMinutes: (json['visit_minutes'] as num?)?.toInt() ?? 90,
      isIndoor: json['is_indoor'] as bool?,
      operatingHours: Map<String, dynamic>.from(
        json['operating_hours'] as Map? ?? {},
      ),
      travelMinutes: (json['travel_minutes'] as num?)?.toInt() ?? 0,
      travelCost: (json['travel_cost'] as num?)?.toDouble() ?? 0,
      travelIsEstimated: json['travel_is_estimated'] as bool? ?? true,
      dataSource: google ? 'google' : json['data_source'] as String? ?? 'local',
    );
    // Migrate older snapshots too: never display an expired Google photo URL or
    // treat old Google metadata as fresh API details.
    if (google) {
      final safe = stop.toJson();
      return TravelStop(
        title: safe['title'] as String,
        time: stop.time,
        note: safe['note'] as String,
        description: safe['description'] as String,
        duration: stop.duration,
        openingHours: 'Hours unverified',
        tips: const [],
        icon: stop.icon,
        color: stop.color,
        placeId: stop.placeId,
        estimatedCost: stop.estimatedCost,
        visitMinutes: stop.visitMinutes,
        isIndoor: stop.isIndoor,
        travelMinutes: stop.travelMinutes,
        travelCost: stop.travelCost,
        travelIsEstimated: stop.travelIsEstimated,
        dataSource: 'google',
      );
    }
    return stop;
  }

  static String formatMinutes(int minutes) {
    final hour = (minutes ~/ 60) % 24;
    return '${(hour % 12 == 0 ? 12 : hour % 12).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')} ${hour >= 12 ? 'PM' : 'AM'}';
  }

  String? get primaryPhotoUrl => isGooglePlace
      ? null
      : photoUrls
            .where(
              (url) =>
                  !url.contains('places.googleapis.com') &&
                  !url.contains('key='),
            )
            .firstOrNull;
}
