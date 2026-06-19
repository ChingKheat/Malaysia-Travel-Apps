import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_decorations.dart';

class SummaryBar extends StatelessWidget {
  const SummaryBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(const Color(0xFFEFF7FF)),
      child: const Row(
        children: [
          Expanded(
            child: SummaryItem(title: 'Travel Time', value: '1 h 25 min'),
          ),
          Expanded(
            child: SummaryItem(title: 'Distance', value: '18.6 km'),
          ),
          Expanded(
            child: SummaryItem(title: 'Est. Cost', value: 'RM120-180'),
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
