import 'package:latlong2/latlong.dart';
import 'package:smart_travel_planner/features/itinerary/models/destination_leg.dart';
import 'package:smart_travel_planner/features/itinerary/models/transfer_event.dart';

/// Handles inter-city route ordering, day distribution, and offline-safe
/// transfer time estimation across all Malaysian states and Borneo regions.
class TransferManager {
  static const _distance = Distance();

  /// Optimizes [legs] into a practical geographic sequence using nearest-neighbor
  /// ordering, keeping Peninsula hubs grouped together and Borneo hubs grouped
  /// together so tourists do not fly across the South China Sea multiple times.
  static List<DestinationLeg> optimizeLegOrder(List<DestinationLeg> legs) {
    if (legs.length <= 2) {
      return [
        for (int i = 0; i < legs.length; i++) legs[i].copyWith(sequence: i + 1),
      ];
    }

    final start = legs.first;
    final startInPeninsula = start.region == MalaysianRegion.peninsula;

    final primaryGroup = legs
        .where(
          (l) => startInPeninsula
              ? l.region == MalaysianRegion.peninsula
              : l.region != MalaysianRegion.peninsula,
        )
        .toList();
    final secondaryGroup = legs
        .where(
          (l) => startInPeninsula
              ? l.region != MalaysianRegion.peninsula
              : l.region == MalaysianRegion.peninsula,
        )
        .toList();

    final orderedPrimary = _nearestNeighborOrder(primaryGroup, anchor: start);
    final lastPrimary = orderedPrimary.isNotEmpty ? orderedPrimary.last : start;
    final orderedSecondary = _nearestNeighborOrder(
      secondaryGroup,
      anchor: lastPrimary,
    );

    final combined = [...orderedPrimary, ...orderedSecondary];
    return [
      for (int i = 0; i < combined.length; i++)
        combined[i].copyWith(sequence: i + 1),
    ];
  }

  static List<DestinationLeg> _nearestNeighborOrder(
    List<DestinationLeg> group, {
    required DestinationLeg anchor,
  }) {
    if (group.length <= 1) return List<DestinationLeg>.from(group);

    final remaining = List<DestinationLeg>.from(group);
    final ordered = <DestinationLeg>[];

    // If the anchor itself is in this group, start with it.
    final anchorIdx = remaining.indexWhere(
      (l) => l.destinationId == anchor.destinationId && l.stateName == anchor.stateName,
    );
    var current = anchorIdx >= 0 ? remaining.removeAt(anchorIdx) : _popClosest(remaining, anchor);
    ordered.add(current);

    while (remaining.isNotEmpty) {
      current = _popClosest(remaining, current);
      ordered.add(current);
    }
    return ordered;
  }

  static DestinationLeg _popClosest(
    List<DestinationLeg> pool,
    DestinationLeg from,
  ) {
    int bestIndex = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < pool.length; i++) {
      final d = _distance.as(
        LengthUnit.Kilometer,
        LatLng(from.latitude, from.longitude),
        LatLng(pool[i].latitude, pool[i].longitude),
      );
      if (d < bestDist) {
        bestDist = d;
        bestIndex = i;
      }
    }
    return pool.removeAt(bestIndex);
  }

  /// Distributes [totalDays] across [legs], guaranteeing at least 1 day per leg.
  static List<DestinationLeg> autoDistributeDays(
    List<DestinationLeg> legs,
    int totalDays,
  ) {
    if (legs.isEmpty) return const [];
    final count = legs.length;
    final safeTotal = totalDays < count ? count : totalDays;

    // Weight major hubs slightly higher when extra days exist.
    const majorHubs = {'kuala lumpur', 'george town', 'johor bahru', 'kota kinabalu', 'kuching'};
    final weights = legs
        .map((l) => majorHubs.contains(l.hubName.toLowerCase()) ? 2 : 1)
        .toList();

    final allocated = List<int>.filled(count, 1);
    int remaining = safeTotal - count;

    while (remaining > 0) {
      bool added = false;
      for (int round = 0; round < 2 && remaining > 0; round++) {
        for (int i = 0; i < count && remaining > 0; i++) {
          if (round == 0 && weights[i] == 2) {
            allocated[i]++;
            remaining--;
            added = true;
          } else if (round == 1) {
            allocated[i]++;
            remaining--;
            added = true;
          }
        }
      }
      if (!added) break;
    }

    return [
      for (int i = 0; i < count; i++)
        legs[i].copyWith(allocatedDays: allocated[i], sequence: i + 1),
    ];
  }

  /// Estimates inter-city transfer between [from] and [to] with automatic
  /// sea-crossing flight detection and offline Haversine fallback.
  static TransferEvent estimateTransfer(
    DestinationLeg from,
    DestinationLeg to,
    DateTime travelDate, {
    InterCityTransportMode? preferredMode,
  }) {
    final requiresFlight = from.region.requiresFlightTo(to.region);
    final mode = requiresFlight
        ? InterCityTransportMode.domesticFlight
        : (preferredMode ?? InterCityTransportMode.privateCar);

    final straightKm = _distance.as(
      LengthUnit.Kilometer,
      LatLng(from.latitude, from.longitude),
      LatLng(to.latitude, to.longitude),
    );
    final routeKm = mode == InterCityTransportMode.domesticFlight ||
            mode == InterCityTransportMode.ferry
        ? straightKm
        : straightKm * 1.28;

    final rawTransitMinutes =
        ((routeKm / mode.averageSpeedKmh) * 60).round().clamp(30, 720);

    final int accessMin;
    final int arrivalMin;
    final int bufferMin;

    switch (mode) {
      case InterCityTransportMode.domesticFlight:
        accessMin = 60;
        arrivalMin = 45;
        bufferMin = 60;
      case InterCityTransportMode.expressBus:
      case InterCityTransportMode.etsTrain:
        accessMin = 30;
        arrivalMin = 25;
        bufferMin = 25;
      case InterCityTransportMode.ferry:
        accessMin = 30;
        arrivalMin = 30;
        bufferMin = 30;
      case InterCityTransportMode.privateCar:
        accessMin = 15;
        arrivalMin = 15;
        bufferMin = 20;
    }

    return TransferEvent(
      fromDestinationId: from.destinationId,
      toDestinationId: to.destinationId,
      fromLabel: from.hubName,
      toLabel: to.hubName,
      travelDate: travelDate,
      transportMode: mode,
      accessMinutes: accessMin,
      mainTransitMinutes: rawTransitMinutes,
      arrivalMinutes: arrivalMin,
      bufferMinutes: bufferMin,
      distanceKm: double.parse(routeKm.toStringAsFixed(1)),
      isEstimated: true,
    );
  }
}
