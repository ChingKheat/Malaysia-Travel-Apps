import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/demo_feedback.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.muted, fontSize: 14),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: () => showDemoSheet(
            context,
            title: 'Notifications',
            body:
                '• Weather alert: light rain expected after 3 PM.\n'
                '• Route updated: Jalan Alor moved earlier to avoid crowds.\n'
                '• Reminder: Batu Caves opens at 7:00 AM tomorrow.',
            icon: Icons.notifications_active_outlined,
            actionLabel: 'Dismiss',
          ),
          icon: const Icon(Icons.notifications_none),
          tooltip: 'Notifications',
        ),
      ],
    );
  }
}
