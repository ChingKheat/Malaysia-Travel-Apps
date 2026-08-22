import 'package:flutter/material.dart';

class TripPreferences {
  final String? destination;
  final int? numberOfDays;
  final TimeOfDay? dailyStartTime;
  final TimeOfDay? dailyEndTime;
  final List<String> interests;
  final String? budgetCategory;
  final String? travelMode;

  const TripPreferences({
    this.destination,
    this.numberOfDays,
    this.dailyStartTime,
    this.dailyEndTime,
    this.interests = const [],
    this.budgetCategory,
    this.travelMode,
  });

  TripPreferences copyWith({
    String? destination,
    int? numberOfDays,
    TimeOfDay? dailyStartTime,
    TimeOfDay? dailyEndTime,
    List<String>? interests,
    String? budgetCategory,
    String? travelMode,
  }) {
    return TripPreferences(
      destination: destination ?? this.destination,
      numberOfDays: numberOfDays ?? this.numberOfDays,
      dailyStartTime: dailyStartTime ?? this.dailyStartTime,
      dailyEndTime: dailyEndTime ?? this.dailyEndTime,
      interests: interests ?? this.interests,
      budgetCategory: budgetCategory ?? this.budgetCategory,
      travelMode: travelMode ?? this.travelMode,
    );
  }
}
