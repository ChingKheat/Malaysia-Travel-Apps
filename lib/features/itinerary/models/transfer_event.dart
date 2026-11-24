enum InterCityTransportMode {
  privateCar,
  expressBus,
  etsTrain,
  domesticFlight,
  ferry,
}

extension InterCityTransportModeX on InterCityTransportMode {
  String get key => name;

  String get label => switch (this) {
        InterCityTransportMode.privateCar => 'Private Car',
        InterCityTransportMode.expressBus => 'Express Bus',
        InterCityTransportMode.etsTrain => 'ETS / Train',
        InterCityTransportMode.domesticFlight => 'Domestic Flight',
        InterCityTransportMode.ferry => 'Ferry',
      };

  /// Average inter-city speed (km/h) for offline estimation fallback.
  double get averageSpeedKmh => switch (this) {
        InterCityTransportMode.privateCar => 80.0,
        InterCityTransportMode.expressBus => 70.0,
        InterCityTransportMode.etsTrain => 110.0,
        InterCityTransportMode.domesticFlight => 450.0,
        InterCityTransportMode.ferry => 35.0,
      };

  /// Fixed terminal access + boarding + arrival + contingency buffer (minutes).
  int get fixedOverheadMinutes => switch (this) {
        InterCityTransportMode.privateCar => 30,
        InterCityTransportMode.expressBus => 75,
        InterCityTransportMode.etsTrain => 75,
        InterCityTransportMode.domesticFlight => 165,
        InterCityTransportMode.ferry => 90,
      };

  static InterCityTransportMode fromString(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return InterCityTransportMode.privateCar;
    }
    return InterCityTransportMode.values.firstWhere(
      (e) => e.name == raw || e.label.toLowerCase() == raw.toLowerCase(),
      orElse: () => InterCityTransportMode.privateCar,
    );
  }
}

/// First-class inter-city transition event between two consecutive DestinationLegs.
class TransferEvent {
  final String fromDestinationId;
  final String toDestinationId;
  final String fromLabel;
  final String toLabel;
  final DateTime travelDate;
  final InterCityTransportMode transportMode;
  final int accessMinutes;
  final int mainTransitMinutes;
  final int arrivalMinutes;
  final int bufferMinutes;
  final double distanceKm;
  final bool isEstimated;

  const TransferEvent({
    required this.fromDestinationId,
    required this.toDestinationId,
    required this.fromLabel,
    required this.toLabel,
    required this.travelDate,
    required this.transportMode,
    this.accessMinutes = 30,
    required this.mainTransitMinutes,
    this.arrivalMinutes = 30,
    this.bufferMinutes = 30,
    this.distanceKm = 0.0,
    this.isEstimated = true,
  });

  int get totalTransferMinutes =>
      accessMinutes + mainTransitMinutes + arrivalMinutes + bufferMinutes;

  Map<String, dynamic> toJson() => {
        'from': fromDestinationId,
        'to': toDestinationId,
        'from_label': fromLabel,
        'to_label': toLabel,
        'travel_date': travelDate.toIso8601String(),
        'transport_mode': transportMode.key,
        'access_minutes': accessMinutes,
        'main_transit_minutes': mainTransitMinutes,
        'arrival_minutes': arrivalMinutes,
        'buffer_minutes': bufferMinutes,
        'distance_km': distanceKm,
        'is_estimated': isEstimated,
      };

  factory TransferEvent.fromJson(Map<String, dynamic> json) {
    return TransferEvent(
      fromDestinationId: json['from']?.toString() ?? '',
      toDestinationId: json['to']?.toString() ?? '',
      fromLabel: json['from_label']?.toString() ?? json['from']?.toString() ?? '',
      toLabel: json['to_label']?.toString() ?? json['to']?.toString() ?? '',
      travelDate:
          DateTime.tryParse(json['travel_date']?.toString() ?? '') ?? DateTime.now(),
      transportMode: InterCityTransportModeX.fromString(
        json['transport_mode']?.toString(),
      ),
      accessMinutes: (json['access_minutes'] as num?)?.toInt() ?? 30,
      mainTransitMinutes: (json['main_transit_minutes'] as num?)?.toInt() ?? 180,
      arrivalMinutes: (json['arrival_minutes'] as num?)?.toInt() ?? 30,
      bufferMinutes: (json['buffer_minutes'] as num?)?.toInt() ?? 30,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      isEstimated: json['is_estimated'] != false,
    );
  }
}
