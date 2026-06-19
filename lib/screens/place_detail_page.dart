import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_decorations.dart';
import '../core/demo_feedback.dart';
import '../models/travel_stop.dart';

class PlaceDetailPage extends StatelessWidget {
  const PlaceDetailPage({super.key, required this.stop});

  final TravelStop stop;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(stop.title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            height: 190,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [stop.color, AppColors.primaryDark],
              ),
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Icon(stop.icon, color: Colors.white, size: 58),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            stop.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stop.description,
            style: const TextStyle(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 18),
          _DetailStat(icon: Icons.schedule, label: 'Time', value: stop.time),
          _DetailStat(
            icon: Icons.timer_outlined,
            label: 'Duration',
            value: stop.duration,
          ),
          _DetailStat(
            icon: Icons.access_time,
            label: 'Opening Hours',
            value: stop.openingHours,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tips',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                ...stop.tips.map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.teal,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(tip)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => showDemoSheet(
              context,
              title: 'Directions to ${stop.title}',
              body:
                  'Opening in Google Maps (demo).\n\n'
                  'Estimated travel: 18 min by car · 35 min by public transit.\n'
                  'Next stop suggestion: ${stop.note}',
              icon: Icons.directions,
              actionLabel: 'Start navigation',
            ),
            icon: const Icon(Icons.directions),
            label: const Text('Get Directions'),
            style: primaryFilledButtonStyle(),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => showDemoSnackBar(
              context,
              '${stop.title} added to favorites.',
              icon: Icons.favorite_outline,
            ),
            icon: const Icon(Icons.favorite_outline),
            label: const Text('Save Place'),
            style: demoOutlinedButtonStyle(),
          ),
        ],
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  const _DetailStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
