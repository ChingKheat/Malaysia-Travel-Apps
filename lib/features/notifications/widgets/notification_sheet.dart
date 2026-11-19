import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_travel_planner/features/community/community_page.dart';
import 'package:smart_travel_planner/features/community/community_service.dart';
import 'package:smart_travel_planner/features/itinerary/screens/itinerary_page.dart';
import 'package:smart_travel_planner/features/itinerary/services/supabase_itinerary_service.dart';
import 'package:smart_travel_planner/features/notifications/models/app_notification.dart';
import 'package:smart_travel_planner/features/notifications/services/notification_service.dart';
import 'package:smart_travel_planner/l10n/localized_labels.dart';

Future<void> showNotificationSheet(BuildContext context) async {
  unawaited(NotificationService().refresh());
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    barrierColor: Colors.black54,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const NotificationSheet(),
  );
}

class NotificationSheet extends StatelessWidget {
  const NotificationSheet({super.key, this.service});

  final NotificationService? service;

  @override
  Widget build(BuildContext context) {
    final service = this.service ?? NotificationService();
    final colors = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final notifications = service.notifications;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.88,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.notifications,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      TextButton(
                        onPressed: service.unreadCount == 0
                            ? null
                            : service.markAllRead,
                        child: Text(context.l10n.notificationMarkAllRead),
                      ),
                      IconButton(
                        tooltip: context.l10n.close,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: notifications.isEmpty && service.isRefreshing
                      ? const Center(child: CircularProgressIndicator())
                      : notifications.isEmpty
                      ? const _EmptyNotifications()
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                          itemCount: notifications.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) => _NotificationTile(
                            notification: notifications[index],
                            onTap: () => unawaited(
                              _activateNotification(
                                context,
                                service,
                                notifications[index],
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<void> _activateNotification(
  BuildContext context,
  NotificationService service,
  AppNotification notification,
) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  await service.markRead(notification.id);

  if (notification.relatedEntityId == null) return;
  if (notification.type == AppNotificationType.tripReminder) {
    final itineraryService = SupabaseItineraryService();
    await itineraryService.syncPending();
    final trips = await itineraryService.getSavedItineraries(refresh: false);
    final exists = trips.any(
      (trip) => trip.itineraryId == notification.relatedEntityId,
    );
    if (!exists) {
      if (context.mounted) {
        messenger?.showSnackBar(
          SnackBar(content: Text(context.l10n.notificationUnavailable)),
        );
      }
      return;
    }
    navigator.pop();
    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(context.l10n.myTrips)),
          body: SafeArea(
            top: false,
            child: ItineraryPage(
              initialItineraryId: notification.relatedEntityId,
            ),
          ),
        ),
      ),
    );
    return;
  }

  final row = await CommunityService().loadPostById(
    notification.relatedEntityId!,
  );
  if (row == null) {
    if (context.mounted) {
      messenger?.showSnackBar(
        SnackBar(content: Text(context.l10n.notificationUnavailable)),
      );
    }
    return;
  }
  final post = CommunityPost.fromFeed(row);
  navigator.pop();
  await navigator.push<void>(
    MaterialPageRoute<void>(
      builder: (_) => CommunityPostDetailPage(post: post),
    ),
  );
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final unread = !notification.isRead;
    final icon = switch (notification.type) {
      AppNotificationType.tripReminder => Icons.luggage_outlined,
      AppNotificationType.communityComment => Icons.chat_bubble_outline_rounded,
    };
    final title = switch (notification.type) {
      AppNotificationType.tripReminder => context.l10n.notificationTripReminder,
      AppNotificationType.communityComment =>
        context.l10n.notificationCommunityComment,
    };
    final message = switch (notification.type) {
      AppNotificationType.tripReminder => context.l10n.notificationTripMessage(
        notification.relatedTitle ?? '',
        notification.relatedDestination ?? '',
        notification.relatedDate == null
            ? ''
            : DateFormat.yMMMd(
                Localizations.localeOf(context).toString(),
              ).format(notification.relatedDate!),
      ),
      AppNotificationType.communityComment =>
        context.l10n.notificationCommentMessage(
          notification.commentPreview ?? '',
        ),
    };
    final actionLabel = switch (notification.type) {
      AppNotificationType.tripReminder => context.l10n.notificationViewTrip,
      AppNotificationType.communityComment => context.l10n.notificationViewPost,
    };

    return Material(
      color: unread
          ? colors.primary.withValues(alpha: 0.08)
          : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: colors.primary.withValues(alpha: 0.14),
                foregroundColor: colors.primary,
                child: Icon(icon, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat.yMMMd(
                        Localizations.localeOf(context).toString(),
                      ).add_jm().format(notification.createdAt.toLocal()),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (notification.relatedEntityId != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        actionLabel,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 42),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 31,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.notifications_none_rounded,
              size: 29,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.notificationEmptyTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.notificationEmptyBody,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}
