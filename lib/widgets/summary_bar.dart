import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_decorations.dart';
import '../models/travel_stop.dart';
import '../services/smart_itinerary_service.dart';
import '../services/scheduling_engine.dart';

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
              title: 'Travel Time',
              value:
                  '${stops.fold<int>(0, (sum, s) => sum + s.travelMinutes)} min',
            ),
          ),
          Expanded(
            child: SummaryItem(
              title: 'Est. Distance',
              value:
                  '~${SmartItineraryService.calculateRouteDistanceKm(stops)} km',
            ),
          ),
          Expanded(
            child: SummaryItem(
              title: 'Est. Cost',
              value: 'RM ${SchedulingEngine.cost(stops).toStringAsFixed(0)}',
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
          title,
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
