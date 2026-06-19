import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_decorations.dart';
import '../models/attraction.dart';

class AttractionDetailPage extends StatelessWidget {
  const AttractionDetailPage({super.key, required this.attraction});

  final Attraction attraction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Attraction Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            height: 170,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF54A0FF), AppColors.primary],
              ),
            ),
            child: const Align(
              alignment: Alignment.bottomLeft,
              child: Icon(Icons.travel_explore, color: Colors.white, size: 58),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            attraction.name,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            attraction.category,
            style: const TextStyle(color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDecoration(),
            child: Text(
              attraction.description ??
                  'OpenTripMap returned this attraction without a long description. It can still be used for map marker and route planning in the demo.',
              style: const TextStyle(color: AppColors.muted, height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.my_location,
            label: 'Latitude',
            value: attraction.latitude.toStringAsFixed(5),
          ),
          _InfoTile(
            icon: Icons.explore,
            label: 'Longitude',
            value: attraction.longitude.toStringAsFixed(5),
          ),
          _InfoTile(
            icon: Icons.api,
            label: 'OpenTripMap XID',
            value: attraction.xid,
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
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
      margin: const EdgeInsets.only(top: 10),
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
