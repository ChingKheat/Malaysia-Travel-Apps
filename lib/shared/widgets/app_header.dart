import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/shared/utils/demo_feedback.dart';
import 'package:smart_travel_planner/features/profile/screens/profile_page.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({super.key, this.title, this.subtitle, this.isDark = false});

  const AppHeader.home({super.key, this.subtitle, this.isDark = true})
      : title = null;

  const AppHeader.explore({
    super.key,
    this.title = 'Explore Malaysia',
    this.subtitle = 'Live Google Places API active for Malaysia',
    this.isDark = false,
  });

  const AppHeader.plan({
    super.key,
    this.title = 'Plan Your Trip',
    this.subtitle = 'Tell us your preferences',
    this.isDark = false,
  });

  const AppHeader.itinerary({
    super.key,
    this.title = 'My Itinerary',
    this.subtitle = 'Smart schedule & daily stops',
    this.isDark = false,
  });

  const AppHeader.ai({
    super.key,
    this.title = 'Trip Assistant',
    this.subtitle = 'AI help, translation and weather alerts',
    this.isDark = false,
  });

  final String? title;
  final String? subtitle;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService(),
      builder: (context, _) {
        final user = AuthService().currentUser;

        // When title == null or isDark is true, display the refined Citylore dark header.
        if (title == null || isDark) {
          final isExplore = title != null;
          final headerSubtitle = isExplore
              ? (subtitle ?? 'Kuala Lumpur · Community')
              : 'Kuala Lumpur';

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Citylore',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'serif',
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (isExplore) ...[
                          const SizedBox(width: 8),
                          // Retains the localized tab title for accessibility and test matching
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5A93C).withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFE5A93C).withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              context.tr(title!),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFE5A93C),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      headerSubtitle,
                      style: const TextStyle(
                        color: Color(0xFF8F93A0),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _HeaderBadgeButton(
                icon: Icons.chat_bubble_outline_rounded,
                badgeText: '1',
                tooltip: 'Messages',
                onTap: () {
                  demoHaptic();
                  showDemoSheet(
                    context,
                    title: 'Community Messages',
                    body:
                        'Amina Rahman: "Check out early morning Kaya Toast along Jalan Tun H.S. Lee before Central Market opens!"',
                    icon: Icons.chat_bubble_outline_rounded,
                    actionLabel: context.l10n.dismiss,
                  );
                },
              ),
              const SizedBox(width: 8),
              _HeaderBadgeButton(
                icon: Icons.notifications_none_outlined,
                badgeText: '1',
                tooltip: context.l10n.notifications,
                onTap: () {
                  demoHaptic();
                  showDemoSheet(
                    context,
                    title: context.l10n.notifications,
                    body: context
                        .l10n
                        .weatherAlertLightRainExpectedAfter3PmRouteUpdatedJalanAlorMovedEarlierToAvoidCrowdsReminde,
                    icon: Icons.notifications_active_outlined,
                    actionLabel: context.l10n.dismiss,
                  );
                },
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
                    border: Border.all(
                      color: const Color(0xFFE5A93C).withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 19,
                    backgroundColor: const Color(0xFF1E2026),
                    backgroundImage: user != null && user.avatarUrl.isNotEmpty
                        ? NetworkImage(user.avatarUrl)
                        : null,
                    child: user == null || user.avatarUrl.isEmpty
                        ? const Icon(
                            Icons.person_outline,
                            color: Colors.white70,
                            size: 20,
                          )
                        : null,
                  ),
                ),
              ),
            ],
          );
        }

        final displayTitle = context.tr(title!);
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

class _HeaderBadgeButton extends StatelessWidget {
  const _HeaderBadgeButton({
    required this.icon,
    required this.badgeText,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String badgeText;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: 38,
              height: 38,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, color: Colors.white70, size: 24),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5A95C),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: Color(0xFF141518),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper function to build the standardized app header across screens.
Widget buildAppHeader({String? title, String? subtitle}) {
  return AppHeader(title: title, subtitle: subtitle);
}
