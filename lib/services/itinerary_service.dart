import 'package:latlong2/latlong.dart';

import '../models/attraction.dart';

class ItineraryService {
  List<Attraction> generateSmartItinerary({
    required List<Attraction> attractions,
    required LatLng startPoint,
    int maxStops = 5,
    int availableHours = 6,
  }) {
    final distance = const Distance();
    final sorted = [...attractions]
      ..sort(
        (a, b) => distance
            .as(LengthUnit.Kilometer, startPoint, a.point)
            .compareTo(distance.as(LengthUnit.Kilometer, startPoint, b.point)),
      );

    final selected = <Attraction>[];
    var usedMinutes = 0;
    var previousPoint = startPoint;

    for (final attraction in sorted) {
      if (selected.length >= maxStops) break;

      final travelMinutes =
          distance.as(LengthUnit.Kilometer, previousPoint, attraction.point) /
          28 *
          60;
      const visitMinutes = 45;
      final nextTotal = usedMinutes + travelMinutes.round() + visitMinutes;

      if (nextTotal <= availableHours * 60) {
        selected.add(attraction);
        usedMinutes = nextTotal;
        previousPoint = attraction.point;
      }
    }

    return selected;
  }
}
