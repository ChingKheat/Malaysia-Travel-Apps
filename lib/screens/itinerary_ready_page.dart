import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_decorations.dart';
import '../core/demo_feedback.dart';
import '../data/sample_data.dart';
import '../widgets/summary_bar.dart';

class ItineraryReadyPage extends StatelessWidget {
  const ItineraryReadyPage({super.key, required this.onViewItinerary});

  final VoidCallback onViewItinerary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FD),
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: cardDecoration(),
            child: Column(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: AppColors.primary,
                  size: 52,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your Itinerary is Ready!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'The route is optimized by distance, opening hours, budget and weather conditions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, height: 1.4),
                ),
                const SizedBox(height: 18),
                const SummaryBar(),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...sampleStops
              .take(3)
              .map(
                (stop) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: cardDecoration(),
                  child: Row(
                    children: [
                      Icon(stop.icon, color: stop.color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          stop.title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        stop.time,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onViewItinerary();
            },
            icon: const Icon(Icons.list_alt),
            label: const Text('View Itinerary'),
            style: primaryFilledButtonStyle(),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              showDemoSnackBar(
                context,
                'Trip saved to My Trips — Kuala Lumpur Getaway.',
                icon: Icons.check_circle_outline,
              );
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Trip'),
            style: demoOutlinedButtonStyle(),
          ),
        ],
      ),
    );
  }
}
