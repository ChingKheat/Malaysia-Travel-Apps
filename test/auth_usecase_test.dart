import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/services/auth_service.dart';

void main() {
  group('UC100_Create Account Unit & Requirement Tests', () {
    late AuthService authService;

    setUp(() {
      authService = AuthService();
      authService.logout();
    });

    test('C1 / A1: Mandatory fields check returns M2 when fields are missing', () async {
      final result = await authService.registerUser(
        name: '',
        email: 'test@example.com',
        password: 'Password123!',
        confirmPassword: 'Password123!',
      );

      expect(result.success, isFalse);
      expect(result.message, equals(AuthService.m2MandatoryFields));
      expect(result.emptyFields.contains('name'), isTrue);
    });

    test('C2 / A2: Email format check returns M3 for invalid email', () async {
      final result = await authService.registerUser(
        name: 'John Doe',
        email: 'invalid-email-format',
        password: 'Password123!',
        confirmPassword: 'Password123!',
      );

      expect(result.success, isFalse);
      expect(result.message, equals(AuthService.m3InvalidEmail));
    });

    test('C3 / A3: Password strength check returns M4 for weak password', () async {
      final result = await authService.registerUser(
        name: 'John Doe',
        email: 'john@example.com',
        password: 'weakpassword1',
        confirmPassword: 'weakpassword1',
      );

      expect(result.success, isFalse);
      expect(result.message, equals(AuthService.m4WeakPassword));
    });

    test('C4 / A4: Password mismatch check returns M5', () async {
      final result = await authService.registerUser(
        name: 'John Doe',
        email: 'john@example.com',
        password: 'ValidPassword123!',
        confirmPassword: 'DifferentPassword123!',
      );

      expect(result.success, isFalse);
      expect(result.message, equals(AuthService.m5PasswordMismatch));
    });

    test('C6 / A5: Duplicate email registration check returns M6', () async {
      final result = await authService.registerUser(
        name: 'Ching Kheat',
        email: 'chingkheat@example.com', // Pre-registered email
        password: 'ValidPassword123!',
        confirmPassword: 'ValidPassword123!',
      );

      expect(result.success, isFalse);
      expect(result.message, equals(AuthService.m6EmailAlreadyRegistered));
    });

    test('FR100_7 - FR100_10 & C8: Successful account creation stores in Firestore without password', () async {
      final testEmail = 'new_tourist_${DateTime.now().millisecondsSinceEpoch}@example.com';
      final result = await authService.registerUser(
        name: 'New Tourist',
        email: testEmail,
        password: 'ValidPassword123!',
        confirmPassword: 'ValidPassword123!',
      );

      expect(result.success, isTrue);
      expect(result.message, equals(AuthService.m1AccountCreated));
      expect(result.user, isNotNull);
      expect(authService.isLoggedIn, isTrue);

      // Verify Cloud Firestore document (FR100_9)
      final firestoreDoc = authService.firestoreUsers[result.user!.uid];
      expect(firestoreDoc, isNotNull);
      expect(firestoreDoc!['name'], equals('New Tourist'));
      expect(firestoreDoc['email'], equals(testEmail));
      expect(firestoreDoc['createdAt'], isNotNull);

      // Constraint C8: Password MUST NOT be stored in Firestore document or logs
      expect(firestoreDoc.containsKey('password'), isFalse);
    });
  });
}
