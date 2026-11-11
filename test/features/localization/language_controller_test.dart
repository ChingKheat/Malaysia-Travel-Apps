import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/core/localization/language_controller.dart';

class MemoryLanguageStore implements LanguageStore {
  String? value;
  bool failRead = false, failWrite = false;
  Future<void>? wait;
  @override
  Future<String?> read() async {
    if (failRead) throw StateError('read failed');
    return value;
  }

  @override
  Future<bool> write(String code) async {
    if (wait != null) await wait;
    if (failWrite) throw StateError('write failed');
    value = code;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'English fallback for absent, unsupported and unreadable preferences',
    () async {
      for (final invalid in [null, 'fr', 'zh-CN', '']) {
        final store = MemoryLanguageStore()..value = invalid;
        final controller = LanguageController(store: store);
        await controller.load();
        expect(controller.locale.languageCode, 'en');
        store.failRead = true;
        await controller.load();
        expect(controller.locale.languageCode, 'en');
        controller.dispose();
      }
    },
  );
  test(
    'all supported choices survive a fresh controller using device storage',
    () async {
      SharedPreferences.setMockInitialValues({});
      for (final code in ['ms', 'zh', 'en']) {
        final controller = LanguageController();
        expect(await controller.changeLanguage(code), isTrue);
        final restarted = LanguageController();
        await restarted.load();
        expect(restarted.locale.languageCode, code);
        controller.dispose();
        restarted.dispose();
      }
    },
  );
  test(
    'unsupported input is rejected without changing current language',
    () async {
      final controller = LanguageController(store: MemoryLanguageStore());
      await controller.changeLanguage('ms');
      expect(() => controller.changeLanguage('fr'), throwsArgumentError);
      expect(controller.locale.languageCode, 'ms');
      controller.dispose();
    },
  );
  test(
    'write failure keeps session selection and does not block later writes',
    () async {
      final store = MemoryLanguageStore()..failWrite = true;
      final controller = LanguageController(store: store);
      expect(await controller.changeLanguage('zh'), isFalse);
      expect(controller.locale.languageCode, 'zh');
      store.failWrite = false;
      expect(await controller.changeLanguage('ms'), isTrue);
      expect(store.value, 'ms');
      controller.dispose();
    },
  );
  test('rapid changes update immediately and serialize persistence', () async {
    final gate = Completer<void>();
    final store = MemoryLanguageStore()..wait = gate.future;
    final controller = LanguageController(store: store);
    final first = controller.changeLanguage('ms');
    final last = controller.changeLanguage('zh');
    expect(controller.locale.languageCode, 'zh');
    gate.complete();
    await Future.wait([first, last]);
    expect(store.value, 'zh');
    controller.dispose();
  });
}
