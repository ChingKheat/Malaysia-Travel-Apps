import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/shared/utils/demo_feedback.dart';
import 'package:smart_travel_planner/features/profile/screens/profile_page.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({super.key, this.title, this.subtitle});

  const AppHeader.home({super.key, this.subtitle}) : title = null;

  const AppHeader.explore({
    super.key,
    this.title = 'Explore Malaysia',
    this.subtitle = 'Live Google Places API active for Malaysia',
  });

  const AppHeader.plan({
    super.key,
    this.title = 'Plan Your Trip',
    this.subtitle = 'Tell us your preferences',
  });

  const AppHeader.itinerary({
    super.key,
    this.title = 'My Itinerary',
    this.subtitle = 'Smart schedule & daily stops',
  });

  const AppHeader.ai({
    super.key,
    this.title = 'Trip Assistant',
    this.subtitle = 'AI help, translation and weather alerts',
  });

  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService(),
      builder: (context, _) {
        final user = AuthService().currentUser;
        final firstName = user != null && user.name.trim().isNotEmpty
            ? user.name.trim().split(' ').first
            : 'Traveler';
        final displayTitle = title == null
            ? context.l10n.helloValue(firstName)
            : context.tr(title!);
        final displaySubtitle = subtitle == null
            ? context.l10n.whereWouldYouLikeToExploreToday
            : context.tr(subtitle!);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayTitle,
                    softWrap: true,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    displaySubtitle,
                    softWrap: true,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: () => showDemoSheet(
                context,
                title: context.l10n.notifications,
                body: context
                    .l10n
                    .weatherAlertLightRainExpectedAfter3PmRouteUpdatedJalanAlorMovedEarlierToAvoidCrowdsReminde,
                icon: Icons.notifications_active_outlined,
                actionLabel: context.l10n.dismiss,
              ),
              icon: const Icon(Icons.notifications_none),
              tooltip: context.l10n.notifications,
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                demoHaptic();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.line, width: 1.5),
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.sky,
                  backgroundImage: user != null && user.avatarUrl.isNotEmpty
                      ? NetworkImage(user.avatarUrl)
                      : null,
                  child: user == null || user.avatarUrl.isEmpty
                      ? const Icon(
                          Icons.person,
                          color: AppColors.primary,
                          size: 20,
                        )
                      : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Helper function to build the standardized app header across screens.
Widget buildAppHeader({String? title, String? subtitle}) {
  return AppHeader(title: title, subtitle: subtitle);
}
