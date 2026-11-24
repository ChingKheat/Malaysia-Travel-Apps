import 'dart:math' as math;
import 'package:smart_travel_planner/features/itinerary/models/transfer_event.dart';
import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/services/smart_itinerary_service.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';

class TravelFeasibilityReport {
  final int score; // 0..100
  final double transferEfficiency; // M1
  final double scheduleSlack;      // M2
  final double attractionDensity;  // M3
  final double geographicEfficiency; // M4
  final String summary;
  final bool isEstimated;

  const TravelFeasibilityReport({
    required this.score,
    required this.transferEfficiency,
    required this.scheduleSlack,
    required this.attractionDensity,
    required this.geographicEfficiency,
    required this.summary,
    this.isEstimated = true,
  });
}

/// Computes an explainable Travel Feasibility Score F in [0, 100]
/// combining Transfer Efficiency, Schedule Slack, Attraction Density, and
/// Geographic Efficiency.
class TravelFeasibilityCalculator {
  static const double wTransfer = 0.30;
  static const double wSlack = 0.25;
  static const double wDensity = 0.25;
  static const double wGeo = 0.20;

  static TravelFeasibilityReport evaluate({
    required Map<int, List<TravelStop>> days,
    required List<TransferEvent> transfers,
    required TripPreferences preferences,
  }) {
    if (days.isEmpty) {
      return const TravelFeasibilityReport(
        score: 0,
        transferEfficiency: 0,
        scheduleSlack: 0,
        attractionDensity: 0,
        geographicEfficiency: 0,
        summary: 'No scheduled days available to evaluate.',
      );
    }

    final totalDays = days.length;
    final dailyStart = TripPreferences.minutesOf(preferences.dailyStartTime) ?? 540;
    final dailyEnd = TripPreferences.minutesOf(preferences.dailyEndTime) ?? 1260;
    final wakingMinutesPerDay = math.max(240, dailyEnd - dailyStart);
    final totalWakingMinutes = totalDays * wakingMinutesPerDay;

    // M1: Transfer Efficiency
    final totalTransferMinutes = transfers.fold<int>(
      0,
      (sum, t) => sum + t.totalTransferMinutes,
    );
    final burdenRatio = totalTransferMinutes / totalWakingMinutes;
    final m1 = (1.0 - (burdenRatio / 0.35)).clamp(0.0, 1.0);

    // M2: Schedule Slack (target >= 60 min free per day)
    double slackSum = 0;
    double attractionCountSum = 0;
    double distanceSumKm = 0;
    bool missingCoords = false;

    for (final stops in days.values) {
      final activityStops = stops.where((s) => s.category != 'Transit').toList();
      attractionCountSum += activityStops.length;

      final usedMinutes = stops.fold<int>(
        0,
        (sum, s) => sum + s.visitMinutes + s.travelMinutes,
      );
      final daySlack = math.max(0, wakingMinutesPerDay - usedMinutes);
      slackSum += (daySlack / 60.0).clamp(0.0, 1.0);

      if (activityStops.length >= 2) {
        final hasInvalid = activityStops.any(
          (s) => s.latitude == 0.0 || s.longitude == 0.0,
        );
        if (hasInvalid) {
          missingCoords = true;
        } else {
          distanceSumKm +=
              SmartItineraryService.calculateRouteDistanceKm(activityStops);
        }
      }
    }

    final m2 = (slackSum / totalDays).clamp(0.0, 1.0);

    // M3: Attraction Density Balance
    final targetStops = switch (preferences.paceCategory) {
      PaceCategory.relaxed => 3.0,
      PaceCategory.packed => 5.0,
      _ => 4.0,
    };
    final avgStops = attractionCountSum / totalDays;
    final m3 = (1.0 - ((avgStops - targetStops).abs() / targetStops))
        .clamp(0.0, 1.0);

    // M4: Geographic Efficiency
    final double m4;
    if (missingCoords) {
      m4 = 0.75;
    } else {
      final avgDistKm = distanceSumKm / totalDays;
      m4 = (1.0 - (math.max(0.0, avgDistKm - 10.0) / 35.0)).clamp(0.0, 1.0);
    }

    double weighted = 100.0 *
        (wTransfer * m1 + wSlack * m2 + wDensity * m3 + wGeo * m4);

    // Anti-domination safeguard: severe transfer burden caps overall score.
    if (m1 < 0.25) {
      weighted = math.min(weighted, 65.0);
    }

    final finalScore = weighted.round().clamp(0, 100);
    final summary = _buildSummary(
      score: finalScore,
      m1: m1,
      m2: m2,
      m3: m3,
      m4: m4,
      transfers: transfers,
    );

    return TravelFeasibilityReport(
      score: finalScore,
      transferEfficiency: m1,
      scheduleSlack: m2,
      attractionDensity: m3,
      geographicEfficiency: m4,
      summary: summary,
      isEstimated: missingCoords || transfers.any((t) => t.isEstimated),
    );
  }

  static String _buildSummary({
    required int score,
    required double m1,
    required double m2,
    required double m3,
    required double m4,
    required List<TransferEvent> transfers,
  }) {
    if (score >= 85) {
      if (transfers.isNotEmpty && m1 < 0.8) {
        return 'Well-balanced itinerary overall. Inter-city transit days keep evening time light.';
      }
      return 'Well-balanced itinerary with comfortable daily pacing and minimal travel overhead.';
    }

    final metrics = <String, double>{
      'transfer': m1,
      'slack': m2,
      'density': m3,
      'geo': m4,
    };
    final weakest = metrics.entries.reduce(
      (a, b) => a.value <= b.value ? a : b,
    );

    return switch (weakest.key) {
      'transfer' =>
        'High inter-city transfer burden. Consider reducing destinations or extending trip duration.',
      'slack' =>
        'Daily schedule is tightly packed with limited buffer time between activities.',
      'density' =>
        'Attraction count per day differs from your selected travel pace.',
      _ =>
        'Daily attractions are spread out; grouping nearby stops could save travel time.',
    };
  }
}
