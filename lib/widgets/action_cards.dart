import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_decorations.dart';
import '../core/demo_feedback.dart';
import 'demo_tap.dart';

class QuickAction extends StatelessWidget {
  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DemoTapCard(
      onTap: onTap,
      child: Container(
        width: quickActionWidth(context),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: cardDecoration(),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class FeatureGrid extends StatelessWidget {
  const FeatureGrid({super.key});

  static const _features = [
    (
      Icons.auto_awesome,
      'AI itinerary',
      'Built a 3-day KL plan with food and shopping stops.',
    ),
    (
      Icons.route,
      'Route optimizer',
      'Reordered stops to save about 45 minutes of travel time.',
    ),
    (
      Icons.cloud_sync_outlined,
      'Weather updates',
      'Rain after 3 PM — indoor backup stops added automatically.',
    ),
    (
      Icons.account_balance_wallet_outlined,
      'Budget filter',
      'Daily spend kept within your RM150–300 medium budget.',
    ),
    (
      Icons.translate,
      'Multi-language',
      'Itinerary labels ready in English, Malay and Chinese.',
    ),
    (
      Icons.offline_bolt_outlined,
      'Offline mode',
      'Maps and itinerary cached for use without mobile data.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = MediaQuery.sizeOf(context).width < 400 ? 1 : 2;

    return GridView.builder(
      itemCount: _features.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: crossAxisCount == 1 ? 4.2 : 2.55,
      ),
      itemBuilder: (context, index) {
        final item = _features[index];
        return DemoTapCard(
          onTap: () => showDemoSheet(
            context,
            title: item.$2,
            body: item.$3,
            icon: item.$1,
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: cardDecoration(),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Icon(item.$1, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.$2,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.muted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
