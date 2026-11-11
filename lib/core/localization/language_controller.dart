import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class LanguageStore {
  Future<String?> read();
  Future<bool> write(String code);
}

class PreferencesLanguageStore implements LanguageStore {
  static const preferenceKey = 'app_language';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(preferenceKey);

  @override
  Future<bool> write(String code) async =>
      (await SharedPreferences.getInstance()).setString(preferenceKey, code);
}

/// Device preference, deliberately independent of authentication and cloud state.
class LanguageController extends ChangeNotifier {
  LanguageController({LanguageStore? store})
    : _store = store ?? PreferencesLanguageStore();

  static final instance = LanguageController();
  static const languageNames = {
    'en': 'English',
    'ms': 'Bahasa Melayu',
    'zh': '简体中文',
  };
  final LanguageStore _store;
  Locale _locale = const Locale('en');
  Future<void> _pendingWrite = Future<void>.value();
  Locale get locale => _locale;

  Future<void> load() async {
    String? code;
    try {
      code = await _store.read();
    } catch (_) {
      // The bundled English interface remains available when storage fails.
    }
    _locale = Locale(languageNames.containsKey(code) ? code! : 'en');
    notifyListeners();
  }

  /// Changes the UI immediately; returns whether the preference was persisted.
  /// Serial writes ensure rapid selections cannot restore an older preference.
  Future<bool> changeLanguage(String code) {
    if (!languageNames.containsKey(code)) {
      throw ArgumentError.value(code, 'code', 'Unsupported app language');
    }
    _locale = Locale(code);
    notifyListeners();
    final write = _pendingWrite.then((_) async {
      try {
        return await _store.write(code);
      } catch (_) {
        return false;
      }
    });
    _pendingWrite = write.then((_) {});
    return write;
  }
}

class LanguageScope extends InheritedNotifier<LanguageController> {
  const LanguageScope({
    super.key,
    required LanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static LanguageController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanguageScope>()?.notifier ??
      LanguageController.instance;
}
