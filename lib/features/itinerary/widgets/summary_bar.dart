import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/core/theme/app_decorations.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';
import 'package:smart_travel_planner/features/itinerary/services/smart_itinerary_service.dart';
import 'package:smart_travel_planner/features/itinerary/services/scheduling_engine.dart';

class SummaryBar extends StatelessWidget {
  const SummaryBar({super.key, this.stops = const []});
  final List<TravelStop> stops;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(const Color(0xFFEFF7FF)),
      child: Row(
        children: [
          Expanded(
            child: SummaryItem(
              title: context.l10n.travelTime,
              value: context.l10n.valueMin(
                context.localNumber(
                  stops.fold<int>(0, (sum, s) => sum + s.travelMinutes),
                ),
              ),
            ),
          ),
          Expanded(
            child: SummaryItem(
              title: context.l10n.estDistance,
              value:
                  '~${SmartItineraryService.calculateRouteDistanceKm(stops)} km',
            ),
          ),
          Expanded(
            child: SummaryItem(
              title: context.l10n.estCost,
              value: context.money(SchedulingEngine.cost(stops)),
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryItem extends StatelessWidget {
  const SummaryItem({super.key, required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(title),
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
