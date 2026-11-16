import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/notifications/widgets/notification_sheet.dart';
import 'package:smart_travel_planner/features/notifications/models/app_notification.dart';
import 'package:smart_travel_planner/features/notifications/services/notification_service.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('real activity rows preserve individual and bulk read state', () async {
    SharedPreferences.setMockInitialValues({});
    final service = NotificationService.forTesting(
      loader: (_) async => [
        AppNotification(
          id: 'comment:comment-1',
          type: AppNotificationType.communityComment,
          createdAt: DateTime(2026, 11, 16, 9),
          isRead: false,
          relatedEntityId: 'post-1',
          commentPreview: 'Great tip!',
        ),
        AppNotification(
          id: 'trip:trip-1:2026-11-17',
          type: AppNotificationType.tripReminder,
          createdAt: DateTime(2026, 11, 16, 10),
          isRead: false,
          relatedEntityId: 'trip-1',
          relatedTitle: 'Kuala Lumpur weekend',
          relatedDestination: 'Kuala Lumpur',
          relatedDate: DateTime(2026, 11, 17),
        ),
      ],
    );

    await service.refresh();
    expect(service.notifications, hasLength(2));
    expect(service.unreadCount, 2);

    await service.markRead('comment:comment-1');
    expect(service.unreadCount, 1);
    expect(
      service.notifications
          .firstWhere((item) => item.id == 'comment:comment-1')
          .isRead,
      isTrue,
    );

    await service.markAllRead();
    expect(service.unreadCount, 0);
    final preferences = await SharedPreferences.getInstance();
    final cached = preferences.getString('notifications.cache.v2:guest');
    expect(cached, contains('Kuala Lumpur weekend'));
    expect(cached, contains('comment:comment-1'));
  });

  testWidgets('notification sheet shows real activity and marks it read', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = NotificationService.forTesting(
      loader: (_) async => [
        AppNotification(
          id: 'comment:comment-2',
          type: AppNotificationType.communityComment,
          createdAt: DateTime(2026, 11, 16, 9),
          isRead: false,
          relatedEntityId: 'post-2',
          commentPreview: 'This is a real comment',
        ),
      ],
    );
    await service.refresh();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => NotificationSheet(service: service),
              ),
              child: const Text('Open inbox'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open inbox'));
    await tester.pumpAndSettle();

    expect(find.text('New comment'), findsOneWidget);
    expect(
      find.text('Someone commented: “This is a real comment”'),
      findsOneWidget,
    );
    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    expect(service.unreadCount, 0);
  });
}
