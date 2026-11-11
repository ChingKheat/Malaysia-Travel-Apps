import 'package:flutter/material.dart';
import 'localized_labels.dart';
import 'package:smart_travel_planner/features/itinerary/models/saved_trip.dart';

/// Formats app-owned scheduling metadata without modifying saved/provider data.
extension PresentationFormatters on BuildContext {
  String tripTitle(SavedTrip trip) =>
      trip.isGenerated ? tr(trip.title) : trip.title;

  String tripDate(SavedTrip trip) => trip.startsOn == null
      ? tr(trip.date)
      : '${localDate(trip.startsOn!)} (${l10n.valueDays(localNumber(trip.totalDays))})';

  String itineraryWarnings(String warnings) {
    // The scheduler joins complete messages; some contain two sentences.
    for (final message in const [
      'No additional places fit this day. Try fewer days or wider daily hours.',
      'Forecast unavailable for this date; weather filtering was not applied.',
      'Travel times are distance-based estimates.',
      'Some opening hours are unverified. Confirm before visiting.',
      'Costs are planning estimates, excluding accommodation and travel to the first stop.',
    ]) {
      warnings = warnings.replaceAll(message, tr(message));
    }
    return warnings;
  }

  String scheduledTime(String value) {
    // Schedules retain canonical times for persistence and routing. Only their
    // presentation follows the app locale and the device's 24-hour preference.
    return value.replaceAllMapped(RegExp(r'\b(\d{1,2}):(\d{2})\s*(AM|PM)\b'), (
      match,
    ) {
      final hour = int.parse(match[1]!) % 12 + (match[3] == 'PM' ? 12 : 0);
      return TimeOfDay(hour: hour, minute: int.parse(match[2]!)).format(this);
    });
  }
}
