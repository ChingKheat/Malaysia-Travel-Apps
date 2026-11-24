import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/auth/models/user_model.dart';

void main() {
  test('profile contact details survive local and cloud serialization', () {
    final user = UserModel(
      uid: 'u',
      name: 'A',
      email: 'a@example.com',
      createdAt: DateTime(2024),
      phone: '+60 12 345 6789',
      nationality: 'Malaysia',
    );
    for (final data in [user.toFirestore(), user.toSupabaseMap()]) {
      final restored = UserModel.fromSupabase(data, 'u');
      expect(restored.phone, '+60 12 345 6789');
      expect(restored.nationality, 'Malaysia');
    }
  });
}
