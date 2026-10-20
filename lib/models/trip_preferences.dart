import 'package:flutter/material.dart';

class TripPreferences {
  final String? destination;
  final int? _numberOfDays;
  final DateTime? startDate;
  final DateTime? endDate;
  int? get numberOfDays => startDate != null && endDate != null
      ? DateTime.utc(endDate!.year, endDate!.month, endDate!.day)
                .difference(
                  DateTime.utc(
                    startDate!.year,
                    startDate!.month,
                    startDate!.day,
                  ),
                )
                .inDays +
            1
      : _numberOfDays;
  final TimeOfDay? dailyStartTime;
  final TimeOfDay? dailyEndTime;
  final List<String> interests;
  final String? budgetCategory;
  final String? travelMode;

  const TripPreferences({
    this.destination,
    int? numberOfDays,
    this.startDate,
    this.endDate,
    this.dailyStartTime,
    this.dailyEndTime,
    this.interests = const [],
    this.budgetCategory,
    this.travelMode,
    // Preserve the public named parameter used by existing forms and tests.
    // ignore: prefer_initializing_formals
  }) : _numberOfDays = numberOfDays;

  DateTime dateForDay(int dayIndex) {
    final first = startDate ?? DateTime.now();
    return DateTime(first.year, first.month, first.day + dayIndex);
  }

  double get dailyBudget => switch (budgetCategory) {
    'Low' => 120,
    'High' => 350,
    _ => 200,
  };

  Map<String, dynamic> toJson() => {
    'destination': destination,
    'number_of_days': numberOfDays,
    'start_date': startDate?.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'start_minutes': dailyStartTime == null
        ? null
        : dailyStartTime!.hour * 60 + dailyStartTime!.minute,
    'end_minutes': dailyEndTime == null
        ? null
        : dailyEndTime!.hour * 60 + dailyEndTime!.minute,
    'interests': interests,
    'budget': budgetCategory,
    'travel_mode': travelMode,
  };

  factory TripPreferences.fromJson(Map<String, dynamic> json) {
    TimeOfDay? time(dynamic value) => value is num
        ? TimeOfDay(hour: value.toInt() ~/ 60, minute: value.toInt() % 60)
        : null;
    return TripPreferences(
      destination: json['destination'] as String?,
      numberOfDays: (json['number_of_days'] as num?)?.toInt(),
      startDate: DateTime.tryParse(json['start_date']?.toString() ?? ''),
      endDate: DateTime.tryParse(json['end_date']?.toString() ?? ''),
      dailyStartTime: time(json['start_minutes']),
      dailyEndTime: time(json['end_minutes']),
      interests: (json['interests'] as List? ?? []).cast<String>(),
      budgetCategory: json['budget'] as String?,
      travelMode: json['travel_mode'] as String?,
    );
  }

  TripPreferences copyWith({
    String? destination,
    int? numberOfDays,
    DateTime? startDate,
    DateTime? endDate,
    TimeOfDay? dailyStartTime,
    TimeOfDay? dailyEndTime,
    List<String>? interests,
    String? budgetCategory,
    String? travelMode,
  }) {
    return TripPreferences(
      destination: destination ?? this.destination,
      numberOfDays: numberOfDays ?? this.numberOfDays,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      dailyStartTime: dailyStartTime ?? this.dailyStartTime,
      dailyEndTime: dailyEndTime ?? this.dailyEndTime,
      interests: interests ?? this.interests,
      budgetCategory: budgetCategory ?? this.budgetCategory,
      travelMode: travelMode ?? this.travelMode,
    );
  }
}
