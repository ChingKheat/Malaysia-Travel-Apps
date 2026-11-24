import 'package:smart_travel_planner/shared/data/malaysia_states.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';

enum PlanningMode { singleDestination, multiDestination }

enum MalaysianRegion {
  peninsula,
  sabah,
  sarawak,
  labuan;

  static MalaysianRegion forState(String stateName) {
    final normalized = stateName.trim().toLowerCase();
    if (normalized.contains('sabah')) return MalaysianRegion.sabah;
    if (normalized.contains('sarawak')) return MalaysianRegion.sarawak;
    if (normalized.contains('labuan')) return MalaysianRegion.labuan;
    return MalaysianRegion.peninsula;
  }

  /// True when travelling between [this] and [other] crosses the South China Sea.
  bool requiresFlightTo(MalaysianRegion other) {
    if (this == other) return false;
    if (this == MalaysianRegion.peninsula || other == MalaysianRegion.peninsula) {
      return true;
    }
    return false;
  }
}

/// Represents a stay in a specific Malaysian destination hub (e.g., George Town, Ipoh).
class DestinationLeg {
  final String destinationId;
  final String hubName;
  final String stateName;
  final MalaysianRegion region;
  final double latitude;
  final double longitude;
  final int allocatedDays;
  final int sequence;
  final TravelStop? accommodation;
  final double searchRadiusKm;

  const DestinationLeg({
    required this.destinationId,
    required this.hubName,
    required this.stateName,
    required this.region,
    required this.latitude,
    required this.longitude,
    required this.allocatedDays,
    required this.sequence,
    this.accommodation,
    this.searchRadiusKm = 25.0,
  });

  /// Builds a [DestinationLeg] from a Malaysian state name using [malaysiaStatesData].
  factory DestinationLeg.fromStateName(
    String stateName, {
    String? hubName,
    int allocatedDays = 1,
    int sequence = 1,
    TravelStop? accommodation,
  }) {
    final stateData = malaysiaStatesData.firstWhere(
      (s) => s.name.toLowerCase() == stateName.trim().toLowerCase(),
      orElse: () => malaysiaStatesData.firstWhere(
        (s) => s.name == 'Kuala Lumpur',
        orElse: () => malaysiaStatesData.first,
      ),
    );

    final CityArea center;
    if (hubName != null && hubName.trim().isNotEmpty) {
      center = stateData.areas.firstWhere(
        (a) => a.name.toLowerCase() == hubName.trim().toLowerCase(),
        orElse: () => stateData.browseCenter,
      );
    } else {
      center = stateData.browseCenter;
    }

    final resolvedHub = center.name;
    final id = resolvedHub
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    return DestinationLeg(
      destinationId: id.isEmpty ? 'kuala_lumpur' : id,
      hubName: resolvedHub,
      stateName: stateData.name,
      region: MalaysianRegion.forState(stateData.name),
      latitude: center.latitude,
      longitude: center.longitude,
      allocatedDays: allocatedDays.clamp(1, 30),
      sequence: sequence,
      accommodation: accommodation,
    );
  }

  DestinationLeg copyWith({
    String? destinationId,
    String? hubName,
    String? stateName,
    MalaysianRegion? region,
    double? latitude,
    double? longitude,
    int? allocatedDays,
    int? sequence,
    TravelStop? accommodation,
    bool clearAccommodation = false,
    double? searchRadiusKm,
  }) {
    return DestinationLeg(
      destinationId: destinationId ?? this.destinationId,
      hubName: hubName ?? this.hubName,
      stateName: stateName ?? this.stateName,
      region: region ?? this.region,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      allocatedDays: (allocatedDays ?? this.allocatedDays).clamp(1, 30),
      sequence: sequence ?? this.sequence,
      accommodation: clearAccommodation
          ? null
          : (accommodation ?? this.accommodation),
      searchRadiusKm: searchRadiusKm ?? this.searchRadiusKm,
    );
  }

  Map<String, dynamic> toJson() => {
        'destination_id': destinationId,
        'hub_name': hubName,
        'state': stateName,
        'region': region.name,
        'latitude': latitude,
        'longitude': longitude,
        'allocated_days': allocatedDays,
        'sequence': sequence,
        'search_radius_km': searchRadiusKm,
        if (accommodation != null) 'accommodation': accommodation!.toJson(),
      };

  factory DestinationLeg.fromJson(Map<String, dynamic> json) {
    final state = json['state']?.toString() ?? 'Kuala Lumpur';
    final rawRegion = json['region']?.toString();
    final region = MalaysianRegion.values.firstWhere(
      (r) => r.name == rawRegion,
      orElse: () => MalaysianRegion.forState(state),
    );
    return DestinationLeg(
      destinationId: json['destination_id']?.toString() ?? 'kuala_lumpur',
      hubName: json['hub_name']?.toString() ?? state,
      stateName: state,
      region: region,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 3.1390,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 101.6869,
      allocatedDays: ((json['allocated_days'] as num?)?.toInt() ?? 1).clamp(1, 30),
      sequence: (json['sequence'] as num?)?.toInt() ?? 1,
      searchRadiusKm: (json['search_radius_km'] as num?)?.toDouble() ?? 25.0,
      accommodation: json['accommodation'] is Map
          ? TravelStop.fromJson(
              Map<String, dynamic>.from(json['accommodation'] as Map),
            )
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DestinationLeg &&
          runtimeType == other.runtimeType &&
          destinationId == other.destinationId &&
          stateName == other.stateName &&
          allocatedDays == other.allocatedDays &&
          sequence == other.sequence;

  @override
  int get hashCode => Object.hash(destinationId, stateName, allocatedDays, sequence);
}
