import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_decorations.dart';
import '../data/sample_data.dart';
import '../models/saved_trip.dart';
import '../widgets/stop_card.dart';
import '../widgets/summary_bar.dart';
import 'place_detail_page.dart';

class TripDetailPage extends StatelessWidget {
  const TripDetailPage({super.key, required this.trip});

  final SavedTrip trip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Trip Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: cardDecoration(AppColors.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.card_travel, color: Colors.white, size: 34),
                const SizedBox(height: 14),
                Text(
                  trip.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  trip.date,
                  style: const TextStyle(color: Color(0xFFE7EAFF)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _TripMeta(
            icon: Icons.place_outlined,
            label: 'Destination',
            value: trip.destination,
          ),
          _TripMeta(
            icon: Icons.payments_outlined,
            label: 'Budget',
            value: trip.budget,
          ),
          _TripMeta(
            icon: Icons.favorite_outline,
            label: 'Interests',
            value: trip.interests.join(', '),
          ),
          const SizedBox(height: 16),
          const SummaryBar(),
          const SizedBox(height: 18),
          const Text(
            'Day 1 Plan',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          ...sampleStops.map(
            (stop) => StopCard(
              stop: stop,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PlaceDetailPage(stop: stop)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripMeta extends StatelessWidget {
  const _TripMeta({
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
