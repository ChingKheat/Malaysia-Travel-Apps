import 'package:flutter/material.dart';

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

  String? get primaryPhotoUrl => photoUrls.isNotEmpty ? photoUrls.first : null;
}
