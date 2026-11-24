import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/home/models/spotlight_destination.dart';

/// Persists whether the Destination Spotlight prompt on Home has been
/// dismissed on this device across relaunches, while resetting and rotating the
/// featured destination on fresh login.
class DestinationSpotlightStore extends ChangeNotifier {
  DestinationSpotlightStore() {
    _activeStores.add(this);
  }

  static const String keyDismissed = 'destination_spotlight_dismissed_v3';
  static bool _pendingLoginReset = false;
  static final Set<DestinationSpotlightStore> _activeStores = {};

  bool _dismissed = false;
  bool _loaded = false;
  SpotlightDestination _featuredDestination = pickFeaturedSpotlight();

  bool get isDismissed => _dismissed;
  bool get isLoaded => _loaded;
  SpotlightDestination get featuredDestination => _featuredDestination;

  /// Marks any prior dismissal to be cleared when Home loads after a fresh
  /// logged-out -> logged-in transition.
  static void resetForLogin() {
    _pendingLoginReset = true;
    for (final store in List<DestinationSpotlightStore>.from(_activeStores)) {
      store._applyLoginReset();
    }
  }

  void _applyLoginReset() {
    _dismissed = false;
    _loaded = true;
    _featuredDestination = pickFeaturedSpotlight();
    notifyListeners();
  }

  void rotateFeatured({Random? random}) {
    _featuredDestination = pickFeaturedSpotlight(random: random);
    notifyListeners();
  }

  Future<void> load({Random? random}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_pendingLoginReset) {
        _pendingLoginReset = false;
        await prefs.remove(keyDismissed);
        _featuredDestination = pickFeaturedSpotlight(random: random);
      }
      final next = prefs.getBool(keyDismissed) ?? false;
      if (_dismissed != next || !_loaded) {
        _dismissed = next;
        _loaded = true;
        notifyListeners();
      }
    } catch (_) {
      if (!_loaded) {
        _loaded = true;
        notifyListeners();
      }
    }
  }

  Future<void> setDismissed(bool dismissed) async {
    _pendingLoginReset = false;
    _dismissed = dismissed;
    _loaded = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyDismissed, dismissed);
    } catch (_) {
      // Keep in-memory state if device storage is temporarily unavailable.
    }
  }

  @override
  void dispose() {
    _activeStores.remove(this);
    super.dispose();
  }
}
