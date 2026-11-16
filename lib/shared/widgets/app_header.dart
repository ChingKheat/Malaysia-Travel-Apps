import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/shared/utils/demo_feedback.dart';
import 'package:smart_travel_planner/features/profile/screens/profile_page.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    this.title,
    this.subtitle,
    this.isDark = false,
    this.compactCitylore = false,
  });

  const AppHeader.home({super.key, this.subtitle, this.isDark = true})
    : title = null,
      compactCitylore = false;

  const AppHeader.explore({
    super.key,
    this.title = 'Explore Malaysia',
    this.subtitle = 'Live Google Places API active for Malaysia',
    this.isDark = false,
  }) : compactCitylore = false;

  const AppHeader.plan({
    super.key,
    this.title = 'Plan Your Trip',
    this.subtitle = 'Tell us your preferences',
    this.isDark = false,
  }) : compactCitylore = false;

  const AppHeader.itinerary({
    super.key,
    this.title = 'My Itinerary',
    this.subtitle = 'Smart schedule & daily stops',
    this.isDark = false,
  }) : compactCitylore = false;

  const AppHeader.ai({
    super.key,
    this.title = 'Trip Assistant',
    this.subtitle = 'AI help, translation & weather',
    this.isDark = false,
  }) : compactCitylore = false;

  const AppHeader.recognition({
    super.key,
    this.title = 'Image Recognition',
    this.subtitle = 'Landmarks & local dishes',
    this.isDark = false,
  }) : compactCitylore = false;

  final String? title;
  final String? subtitle;
  final bool isDark;
  final bool compactCitylore;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService(),
      builder: (context, _) {
        final user = AuthService().currentUser;

        if (compactCitylore) {
          final isExplore = title != null;
          final headerSubtitle = isExplore
              ? (subtitle ?? 'Kuala Lumpur · Community')
              : (subtitle ?? 'Kuala Lumpur');

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
                            fontSize: 21,
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
                              color: const Color(
                                0xFFE5A93C,
                              ).withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(
                                  0xFFE5A93C,
                                ).withValues(alpha: 0.35),
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
                        color: Color(0xFFB5AEA2),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _HeaderBadgeButton(
                icon: Icons.chat_bubble_outline_rounded,
                badgeText: '1',
                iconColor: const Color(0xFFB5AEA2),
                compact: true,
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
                iconColor: const Color(0xFFB5AEA2),
                compact: true,
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
                child: SizedBox.square(
                  dimension: 38,
                  child: Icon(
                    Icons.person_outline,
                    color: const Color(0xFFDFD8CB),
                    size: 21,
                    semanticLabel: context.l10n.myProfile,
                  ),
                ),
              ),
            ],
          );
        }

        final dark = title == null || isDark;
        final foreground = dark ? Colors.white : AppColors.ink;
        final muted = dark ? AppColors.nightMuted : AppColors.muted;
        final displayTitle = title == null ? 'Citylore' : context.tr(title!);
        final displaySubtitle = subtitle == null
            ? (title == null
                  ? 'Kuala Lumpur'
                  : context.l10n.whereWouldYouLikeToExploreToday)
            : context.tr(subtitle!);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'serif',
                        color: foreground,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displaySubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _HeaderBadgeButton(
              icon: Icons.chat_bubble_outline_rounded,
              badgeText: '1',
              iconColor: muted,
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
            const SizedBox(width: 4),
            _HeaderBadgeButton(
              icon: Icons.notifications_none_outlined,
              badgeText: '1',
              iconColor: muted,
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
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                demoHaptic();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              },
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: dark
                            ? AppColors.nightAccent.withValues(alpha: 0.5)
                            : AppColors.line,
                        width: 1.5,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 17,
                      backgroundColor: dark
                          ? AppColors.nightSurface
                          : AppColors.sky,
                      backgroundImage: user != null && user.avatarUrl.isNotEmpty
                          ? NetworkImage(user.avatarUrl)
                          : null,
                      child: user == null || user.avatarUrl.isEmpty
                          ? Icon(Icons.person_outline, color: muted, size: 18)
                          : null,
                    ),
                  ),
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
    required this.iconColor,
    required this.tooltip,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String badgeText;
  final Color iconColor;
  final String tooltip;
  final VoidCallback onTap;
  final bool compact;

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
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, color: iconColor, size: compact ? 21 : 22),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3.5,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.nightAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: AppColors.nightSurface,
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
