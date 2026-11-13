import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Store and controller for initial onboarding / welcome setup.
class OnboardingService extends ChangeNotifier {
  OnboardingService({SharedPreferences? prefs}) {
    _prefs = prefs;
  }

  static final OnboardingService instance = OnboardingService();

  static const String keyCompleted = 'has_completed_onboarding';
  static const String keySelectedLanguage = 'onboarding_selected_language';
  static const String keyLocationGranted = 'onboarding_location_granted';
  static const String keyTermsAcceptedAt = 'onboarding_terms_accepted_at';

  SharedPreferences? _prefs;
  bool _isCompleted = false;
  String _selectedLanguage = 'en';
  bool _locationGranted = false;
  DateTime? _termsAcceptedAt;

  bool get isCompleted => _isCompleted;
  String get selectedLanguage => _selectedLanguage;
  bool get locationGranted => _locationGranted;
  DateTime? get termsAcceptedAt => _termsAcceptedAt;

  Future<void> load() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      _isCompleted = _prefs?.getBool(keyCompleted) ?? false;
      _selectedLanguage = _prefs?.getString(keySelectedLanguage) ?? 'en';
      _locationGranted = _prefs?.getBool(keyLocationGranted) ?? false;
      final termsStr = _prefs?.getString(keyTermsAcceptedAt);
      if (termsStr != null && termsStr.isNotEmpty) {
        _termsAcceptedAt = DateTime.tryParse(termsStr);
      }
      notifyListeners();
    } catch (_) {
      // In case storage is unavailable, maintain safe default.
    }
  }

  Future<void> setLanguage(String code) async {
    _selectedLanguage = code;
    notifyListeners();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setString(keySelectedLanguage, code);
    } catch (_) {}
  }

  Future<void> setLocationGranted(bool granted) async {
    _locationGranted = granted;
    notifyListeners();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setBool(keyLocationGranted, granted);
    } catch (_) {}
  }

  Future<void> completeOnboarding({DateTime? acceptedAt}) async {
    _isCompleted = true;
    _termsAcceptedAt = acceptedAt ?? DateTime.now();
    notifyListeners();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setBool(keyCompleted, true);
      await _prefs?.setString(
        keyTermsAcceptedAt,
        _termsAcceptedAt!.toIso8601String(),
      );
    } catch (_) {}
  }

  Future<void> resetOnboarding() async {
    _isCompleted = false;
    _selectedLanguage = 'en';
    _locationGranted = false;
    _termsAcceptedAt = null;
    notifyListeners();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.remove(keyCompleted);
      await _prefs?.remove(keyTermsAcceptedAt);
      await _prefs?.remove(keyLocationGranted);
      await _prefs?.remove(keySelectedLanguage);
    } catch (_) {}
  }

  void resetForTesting({bool isCompleted = false}) {
    _isCompleted = isCompleted;
    _selectedLanguage = 'en';
    _locationGranted = false;
    _termsAcceptedAt = null;
    notifyListeners();
  }
}
