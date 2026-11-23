import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_travel_planner/features/auth/services/password_recovery.dart';
import 'package:smart_travel_planner/features/auth/widgets/login_form.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';

void main() {
  testWidgets('login opens recovery with the email already entered', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: LoginForm()),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'invalid-email');
    await tester.ensureVisible(find.text('Forgot password?'));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    final emailField = find.byKey(const ValueKey('recovery-email'));
    expect(
      tester.widget<TextFormField>(emailField).controller!.text,
      'invalid-email',
    );
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a valid email address.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Reset password'), findsNothing);
  });

  PasswordRecovery recoveryWith(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final recovery = PasswordRecovery(
      client: MockClient(handler),
      projectUrl: 'https://test.supabase.co',
      publicKey: 'test-public-key',
    );
    addTearDown(recovery.dispose);
    return recovery;
  }

  test('recovery uses the emailed code and its scoped credentials', () async {
    final requests = <http.Request>[];
    var passwordAttempts = 0;
    final recovery = recoveryWith((request) async {
      requests.add(request);
      switch (request.url.path) {
        case '/auth/v1/recover':
          return http.Response('{}', 200);
        case '/auth/v1/verify':
          return http.Response('{"access_token":"recovery-token"}', 200);
        case '/auth/v1/user':
          passwordAttempts++;
          return passwordAttempts == 1
              ? http.Response('{}', 503)
              : http.Response('{}', 200);
        default:
          return http.Response('', 204);
      }
    });

    expect(
      await recovery.setPassword('A-new-password1!'),
      RecoveryResult.expired,
    );
    expect(requests, isEmpty);
    expect(
      await recovery.sendCode(' TEST@example.com '),
      RecoveryResult.success,
    );
    expect(await recovery.verifyCode('012345'), RecoveryResult.success);
    expect(
      await recovery.setPassword('A-new-password1!'),
      RecoveryResult.unavailable,
    );
    expect(
      await recovery.setPassword('A-new-password1!'),
      RecoveryResult.success,
    );
    expect(
      await recovery.setPassword('A-new-password1!'),
      RecoveryResult.expired,
    );

    expect(requests.map((r) => r.method), [
      'POST',
      'POST',
      'PUT',
      'PUT',
      'POST',
    ]);
    expect(jsonDecode(requests[0].body), {'email': 'test@example.com'});
    expect(jsonDecode(requests[1].body), {
      'email': 'test@example.com',
      'token': '012345',
      'type': 'recovery',
    });
    expect(requests[0].headers['apikey'], 'test-public-key');
    expect(requests[1].headers['authorization'], isNull);
    expect(requests[2].headers['authorization'], 'Bearer recovery-token');
    expect(jsonDecode(requests[2].body), {'password': 'A-new-password1!'});
    expect(requests.last.url.path, '/auth/v1/logout');
    expect(requests.last.url.queryParameters['scope'], 'local');
  });

  test('unknown and recently emailed accounts get the same response', () async {
    var requests = 0;
    final recovery = recoveryWith((_) async {
      return requests++ == 0
          ? http.Response('{"code":"user_not_found"}', 404)
          : http.Response('{"code":"over_email_send_rate_limit"}', 429);
    });
    expect(await recovery.sendCode('invalid'), RecoveryResult.invalidEmail);
    expect(await recovery.sendCode('test@example.com'), RecoveryResult.success);
    expect(await recovery.sendCode('test@example.com'), RecoveryResult.success);
    expect(requests, 2);
  });

  test(
    'a rejected or expired code cannot authorize a password update',
    () async {
      final recovery = recoveryWith((request) async {
        if (request.url.path.endsWith('/recover')) {
          return http.Response('{}', 200);
        }
        expect(request.url.path, '/auth/v1/verify');
        return http.Response('{"code":"otp_expired"}', 403);
      });
      await recovery.sendCode('test@example.com');
      expect(await recovery.verifyCode('012345'), RecoveryResult.invalidCode);
      expect(
        await recovery.setPassword('A-new-password1!'),
        RecoveryResult.expired,
      );
    },
  );

  test('offline requests return a recoverable error', () async {
    final recovery = recoveryWith(
      (_) async => throw http.ClientException('offline'),
    );
    expect(
      await recovery.sendCode('test@example.com'),
      RecoveryResult.unavailable,
    );
  });

  test('parses real Supabase GoTrue responses with error_code and integer code', () async {
    final recovery = recoveryWith((request) async {
      switch (request.url.path) {
        case '/auth/v1/recover':
          return http.Response(
            '{"code":429,"error_code":"over_email_send_rate_limit","msg":"Rate limited"}',
            429,
          );
        case '/auth/v1/verify':
          return http.Response(
            '{"code":403,"error_code":"otp_expired","msg":"Token expired"}',
            403,
          );
        default:
          return http.Response('', 204);
      }
    });

    // Rate-limited recovery should succeed and move forward to code entry
    expect(await recovery.sendCode('test@example.com'), RecoveryResult.success);
    // Expired OTP code should correctly report invalidCode rather than unavailable
    expect(await recovery.verifyCode('123456'), RecoveryResult.invalidCode);
  });
}
