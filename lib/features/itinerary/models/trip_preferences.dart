import 'package:flutter/material.dart';
import 'package:smart_travel_planner/features/itinerary/models/destination_leg.dart';
import 'package:smart_travel_planner/features/itinerary/models/transfer_event.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';

enum TravelerType { solo, couple, family, friends, seniors }

enum PaceCategory { relaxed, balanced, packed }

enum DietaryPreference { unrestricted, halalFriendly, vegetarian, streetFood }

class TripPreferences {
  TravelStop? get dailyOrigin => departurePoint ?? accommodationArea;

  static int? minutesOf(TimeOfDay? time) =>
      time == null ? null : time.hour * 60 + time.minute;

  final TravelerType travelerType;
  final PaceCategory? paceCategory;
  final DietaryPreference dietaryPreference;
  final TravelStop? accommodationArea;
  final TimeOfDay? arrivalTime;
  final TimeOfDay? departureTime;
  final int departureBufferMinutes;
  final int departureTransferMinutes;
  final List<TravelStop> mustVisitPlaces;
  final List<TravelStop> selectedPlaces;
  final List<String> secondaryTransportModes;

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
  final int? transitPlanningMinutes;
  final TravelStop? departurePoint;
  final PlanningMode planningMode;
  final List<DestinationLeg> legs;
  final List<TransferEvent> transitions;
  final bool autoOptimizeRouteOrder;

  bool get isMultiDestination =>
      planningMode == PlanningMode.multiDestination && legs.length > 1;

  /// Safe composite display label (< 100 chars for PostgreSQL VARCHAR(100)).
  String? get effectiveDestinationLabel {
    if (legs.isEmpty) return destination;
    if (legs.length == 1) return legs.first.stateName;
    if (legs.length <= 3) {
      final joined = legs.map((l) => l.stateName).join(' • ');
      if (joined.length <= 96) return joined;
    }
    final prefix = legs.take(2).map((l) => l.stateName).join(' • ');
    final label = '$prefix +${legs.length - 2} more';
    return label.length <= 100 ? label : 'Malaysia Tour (${legs.length} stops)';
  }

  /// Resolves active legs, synthesizing a single-state leg for legacy trips.
  List<DestinationLeg> get effectiveLegs {
    if (legs.isNotEmpty) return legs;
    final state = destination?.trim();
    if (state == null || state.isEmpty) return const [];
    return [
      DestinationLeg.fromStateName(
        state,
        allocatedDays: numberOfDays ?? 3,
        sequence: 1,
        accommodation: accommodationArea,
      ),
    ];
  }

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
    this.transitPlanningMinutes,
    this.departurePoint,
    this.travelerType = TravelerType.solo,
    this.paceCategory,
    this.dietaryPreference = DietaryPreference.unrestricted,
    this.accommodationArea,
    this.arrivalTime,
    this.departureTime,
    this.departureBufferMinutes = 60,
    this.departureTransferMinutes = 0,
    this.mustVisitPlaces = const [],
    this.selectedPlaces = const [],
    this.secondaryTransportModes = const [],
    this.planningMode = PlanningMode.singleDestination,
    this.legs = const [],
    this.transitions = const [],
    this.autoOptimizeRouteOrder = true,

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
    'traveler_type': travelerType.name,
    'pace_category': paceCategory?.name,
    'dietary_preference': dietaryPreference.name,
    'accommodation_area': accommodationArea?.toJson(),
    'arrival_minutes': minutesOf(arrivalTime),
    'departure_minutes': minutesOf(departureTime),
    'departure_buffer_minutes': departureBufferMinutes,
    'departure_transfer_minutes': departureTransferMinutes,
    'must_visit_places': mustVisitPlaces.map((stop) => stop.toJson()).toList(),
    'selected_places': selectedPlaces.map((stop) => stop.toJson()).toList(),
    'secondary_transport_modes': secondaryTransportModes,

    'budget': budgetCategory,
    'travel_mode': travelMode,
    if (transitPlanningMinutes != null)
      'transit_planning_minutes': transitPlanningMinutes,
    if (departurePoint != null) 'departure_point': departurePoint!.toJson(),
    'planning_mode': planningMode.name,
    'auto_optimize_route_order': autoOptimizeRouteOrder,
    if (legs.isNotEmpty) 'legs': legs.map((l) => l.toJson()).toList(),
    if (transitions.isNotEmpty)
      'transitions': transitions.map((t) => t.toJson()).toList(),
  };

  factory TripPreferences.fromJson(Map<String, dynamic> json) {
    TimeOfDay? time(dynamic value) => value is num && value >= 0 && value < 1440
        ? TimeOfDay(hour: value.toInt() ~/ 60, minute: value.toInt() % 60)
        : null;
    T? parseEnum<T extends Enum>(List<T> values, String key) =>
        values.where((value) => value.name == json[key]).firstOrNull;
    TravelStop? place(dynamic value) {
      if (value is! Map<String, dynamic>) return null;
      final stop = TravelStop.fromJson(value);
      if (stop.isGooglePlace && stop.placeId?.isNotEmpty == true) return stop;
      return stop.title.trim().isNotEmpty &&
              stop.latitude.isFinite &&
              stop.longitude.isFinite &&
              stop.latitude.abs() <= 90 &&
              stop.longitude.abs() <= 180 &&
              (stop.latitude != 0 || stop.longitude != 0)
          ? stop
          : null;
    }

    final mustVisit = json['must_visit_places'];
    final selected = json['selected_places'];
    final modes = json['secondary_transport_modes'];
    return TripPreferences(
      travelerType:
          parseEnum(TravelerType.values, 'traveler_type') ?? TravelerType.solo,
      paceCategory: parseEnum(PaceCategory.values, 'pace_category'),
      dietaryPreference:
          parseEnum(DietaryPreference.values, 'dietary_preference') ??
          DietaryPreference.unrestricted,
      accommodationArea: place(json['accommodation_area']),
      arrivalTime: time(json['arrival_minutes']),
      departureTime: time(json['departure_minutes']),
      departureTransferMinutes: switch (json['departure_transfer_minutes']) {
        final int minutes when minutes >= 0 && minutes <= 240 => minutes,
        _ => 0,
      },
      departureBufferMinutes: switch (json['departure_buffer_minutes']) {
        final int minutes when minutes >= 0 && minutes <= 360 => minutes,
        _ => 60,
      },
      mustVisitPlaces: mustVisit is List
          ? List.unmodifiable(mustVisit.map(place).whereType<TravelStop>())
          : const [],
      selectedPlaces: selected is List
          ? List.unmodifiable(selected.map(place).whereType<TravelStop>())
          : const [],
      secondaryTransportModes: modes is List
          ? List.unmodifiable(
              modes
                  .whereType<String>()
                  .where(
                    const {
                      'Driving',
                      'Walking',
                      'Public Transport',
                      'E-hailing',
                    }.contains,
                  )
                  .toSet(),
            )
          : const [],
      destination: json['destination'] as String?,
      numberOfDays: (json['number_of_days'] as num?)?.toInt(),
      startDate: DateTime.tryParse(json['start_date']?.toString() ?? ''),
      endDate: DateTime.tryParse(json['end_date']?.toString() ?? ''),
      dailyStartTime: time(json['start_minutes']),
      dailyEndTime: time(json['end_minutes']),
      interests: (json['interests'] as List? ?? []).cast<String>(),
      budgetCategory: json['budget'] as String?,
      travelMode: json['travel_mode'] as String?,
      departurePoint: json['departure_point'] is Map
          ? TravelStop.fromJson(
              Map<String, dynamic>.from(json['departure_point'] as Map),
            )
          : null,
      transitPlanningMinutes: (json['transit_planning_minutes'] as num?)
          ?.toInt(),
      planningMode: parseEnum(PlanningMode.values, 'planning_mode') ??
          ((json['legs'] is List && (json['legs'] as List).length > 1)
              ? PlanningMode.multiDestination
              : PlanningMode.singleDestination),
      autoOptimizeRouteOrder: json['auto_optimize_route_order'] != false,
      legs: json['legs'] is List
          ? List.unmodifiable(
              (json['legs'] as List)
                  .whereType<Map>()
                  .map((m) => DestinationLeg.fromJson(Map<String, dynamic>.from(m))),
            )
          : const [],
      transitions: json['transitions'] is List
          ? List.unmodifiable(
              (json['transitions'] as List)
                  .whereType<Map>()
                  .map((m) => TransferEvent.fromJson(Map<String, dynamic>.from(m))),
            )
          : const [],
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
    TravelStop? departurePoint,
    TravelerType? travelerType,
    PaceCategory? paceCategory,
    DietaryPreference? dietaryPreference,
    TravelStop? accommodationArea,
    TimeOfDay? arrivalTime,
    TimeOfDay? departureTime,
    int? departureBufferMinutes,
    int? departureTransferMinutes,
    List<TravelStop>? mustVisitPlaces,
    List<TravelStop>? selectedPlaces,
    List<String>? secondaryTransportModes,
    PlanningMode? planningMode,
    List<DestinationLeg>? legs,
    List<TransferEvent>? transitions,
    bool? autoOptimizeRouteOrder,
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
      transitPlanningMinutes: transitPlanningMinutes,
      departurePoint: departurePoint ?? this.departurePoint,
      travelerType: travelerType ?? this.travelerType,
      paceCategory: paceCategory ?? this.paceCategory,
      dietaryPreference: dietaryPreference ?? this.dietaryPreference,
      accommodationArea: accommodationArea ?? this.accommodationArea,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      departureTime: departureTime ?? this.departureTime,
      departureTransferMinutes:
          departureTransferMinutes ?? this.departureTransferMinutes,
      departureBufferMinutes:
          departureBufferMinutes ?? this.departureBufferMinutes,
      mustVisitPlaces: mustVisitPlaces ?? this.mustVisitPlaces,
      selectedPlaces: selectedPlaces ?? this.selectedPlaces,
      secondaryTransportModes:
          secondaryTransportModes ?? this.secondaryTransportModes,
      planningMode: planningMode ?? this.planningMode,
      legs: legs ?? this.legs,
      transitions: transitions ?? this.transitions,
      autoOptimizeRouteOrder:
          autoOptimizeRouteOrder ?? this.autoOptimizeRouteOrder,
    );
  }
}
