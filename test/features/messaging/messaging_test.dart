import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/messaging/messaging_screens.dart';
import 'package:smart_travel_planner/features/messaging/messaging_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService().logout();
  });
  tearDown(() async => AuthService().logout());

  test('pending messages persist and cache is isolated by account', () async {
    final auth = AuthService();
    expect(await auth.login('chingkheat@example.com', 'SafeP@ss123!'), isTrue);
    final first = MessagingService();
    final pending = await first.enqueue('chat', ' hello ');
    expect(pending['content'], 'hello');
    expect(pending['status'], 'pending');
    expect(
      (await MessagingService().read('chat:chat')).single['id'],
      pending['id'],
    );
    await auth.logout();
    expect(await first.read('chat:chat'), isEmpty);
    expect(await auth.login('tourist@example.com', 'SafeP@ss123!'), isTrue);
    expect(await MessagingService().read('chat:chat'), isEmpty);
  });

  test('rejects empty and oversized messages', () async {
    final auth = AuthService();
    await auth.login('chingkheat@example.com', 'SafeP@ss123!');
    final service = MessagingService();
    await expectLater(service.enqueue('chat', '  '), throwsArgumentError);
    await expectLater(service.enqueue('chat', 'x' * 4001), throwsArgumentError);
  });

  test('send response accepts PostgREST composite array and object', () {
    expect(
      MessagingService.parseSentMessage([
        {'id': '123'},
      ])['status'],
      'sent',
    );
    expect(MessagingService.parseSentMessage({'id': '123'})['id'], '123');
    expect(() => MessagingService.parseSentMessage([]), throwsFormatException);
  });

  testWidgets('inbox shows sign-in state without crashing offline', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MessagesInbox()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sign in to sync'), findsOneWidget);
    expect(find.textContaining('No conversations yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inbox uses the other participant photo when available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: MessagesInbox(service: _PhotoInbox())),
    );
    await tester.pumpAndSettle();
    final avatars = tester.widgetList<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatars.first.foregroundImage, isA<NetworkImage>());
    expect(avatars.last.foregroundImage, isNull);
    expect(find.byIcon(Icons.person), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _PhotoInbox extends MessagingService {
  @override
  Future<List<Map<String, dynamic>>> inbox() async => [
    {
      'display_name': 'Yi Han',
      'avatar_display_url': 'https://example.test/avatar.png',
    },
    {'display_name': 'Traveller'},
  ];
}
