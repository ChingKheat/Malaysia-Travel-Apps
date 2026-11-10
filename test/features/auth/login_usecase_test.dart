import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';

void main() {
  test(
    'UC300 local profile updates survive logout and login in the same session',
    () async {
      final auth = AuthService();
      await auth.logout();
      final email =
          'profile_${DateTime.now().microsecondsSinceEpoch}@example.com';
      final registered = await auth.registerUser(
        name: 'Original Name',
        email: email,
        password: 'Password123!',
        confirmPassword: 'Password123!',
      );
      expect(registered.success, isTrue);
      expect(await auth.updateProfile(name: '  Updated Name  '), isTrue);
      expect(auth.currentUser?.name, 'Updated Name');
      expect(await auth.updateProfile(name: '  '), isFalse);
      await auth.logout();
      final login = await auth.loginUser(
        email: email,
        password: 'Password123!',
      );
      expect(login.success, isTrue);
      expect(login.user?.name, 'Updated Name');
      await auth.logout();
    },
  );
  group('UC200_Login Unit & Requirement Tests', () {
    late AuthService authService;

    setUp(() {
      authService = AuthService();
      authService.logout();
    });

    test(
      'C1 / A1: Empty fields return M2 and empty field highlights',
      () async {
        final result = await authService.loginUser(email: '', password: '');

        expect(result.success, isFalse);
        expect(result.message, equals(AuthService.m2LoginMandatory));
        expect(result.emptyFields.contains('email'), isTrue);
        expect(result.emptyFields.contains('password'), isTrue);
      },
    );

    test('C2 / A2: Invalid email format returns M3', () async {
      final result = await authService.loginUser(
        email: 'invalid-email-format',
        password: 'SomePassword123!',
      );

      expect(result.success, isFalse);
      expect(result.message, equals(AuthService.m3LoginInvalidEmail));
    });

    test(
      'C4 / A3: Incorrect password returns generic M4 (C6 compliance)',
      () async {
        final result = await authService.loginUser(
          email: 'chingkheat@example.com',
          password: 'IncorrectPassword999!',
        );

        expect(result.success, isFalse);
        expect(result.message, equals(AuthService.m4InvalidCredentials));
      },
    );

    test(
      'C4 / C6 / A3: Unregistered email returns generic M4 (C6 compliance)',
      () async {
        final result = await authService.loginUser(
          email: 'unregistered_tourist@example.com',
          password: 'SafeP@ss123!',
        );

        expect(result.success, isFalse);
        // Constraint C6: Must not reveal whether account exists
        expect(result.message, equals(AuthService.m4InvalidCredentials));
      },
    );

    test(
      'FR200_7 & FR200_8: Successful login establishes session and retrieves Firestore profile',
      () async {
        final result = await authService.loginUser(
          email: 'chingkheat@example.com',
          password: 'SafeP@ss123!',
        );

        expect(result.success, isTrue);
        expect(result.message, equals(AuthService.m1LoginSuccess));
        expect(result.user, isNotNull);
        expect(result.user!.name, equals('Ching Kheat'));
        expect(result.user!.email, equals('chingkheat@example.com'));

        // Check that session is established
        expect(authService.isLoggedIn, isTrue);
        expect(authService.currentUser!.uid, equals(result.user!.uid));
      },
    );
  });
}
