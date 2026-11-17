import 'package:flutter/material.dart';
import 'package:smart_travel_planner/l10n/localized_labels.dart';

String scanDistanceLabel(
  BuildContext context,
  double meters, {
  required bool fromLandmark,
  bool showWalkTime = true,
}) {
  final distance = meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';
  final origin = fromLandmark
      ? context.l10n.scanScannedLandmark
      : context.l10n.scanMapLocation;
  if (showWalkTime && meters <= 2500) {
    return context.l10n.scanDistanceWalk(
      (meters / 80).ceil().clamp(1, 999),
      distance,
      origin,
    );
  }
  return context.l10n.scanDistanceAway(distance, origin);
}
