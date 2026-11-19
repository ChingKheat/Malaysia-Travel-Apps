import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/profile/services/profile_avatar_service.dart';

void main() {
  test(
    'profile photo is validated and remains available from local storage',
    () async {
      SharedPreferences.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp('avatar-test-');
      addTearDown(() => directory.delete(recursive: true));
      final service = ProfileAvatarService(rootDirectory: directory);
      final image = Uint8List.fromList(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/rZkAAAAASUVORK5CYII=',
        ),
      );
      expect(ProfileAvatarService.format(image), ('png', 'image/png'));
      expect(ProfileAvatarService.format(Uint8List(12)), isNull);
      expect(
        ProfileAvatarService.format(
          Uint8List(ProfileAvatarService.maxBytes + 1),
        ),
        isNull,
      );

      final saved = await service.saveLocal('account-a', image);
      expect(saved, isNotNull);
      expect(await File.fromUri(Uri.parse(saved!)).readAsBytes(), image);
      expect(await service.localUrl('account-a'), saved);
      expect(await service.localUrl('account-b'), isNull);
      expect(ProfileAvatarService.imageProvider(saved), isNotNull);
    },
  );
}
