import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/core/config/supabase_config.dart';
import 'package:smart_travel_planner/features/auth/models/travel_preferences.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';

enum PreferredCurrency {
  myr('MYR', 'RM'),
  sgd('SGD', 'S\$'),
  usd('USD', '\$'),
  cny('CNY', '¥'),
  eur('EUR', '€');

  const PreferredCurrency(this.code, this.symbol);
  final String code;
  final String symbol;

  String get label => '$code ($symbol)';
}

class ProfilePreferencesService extends ChangeNotifier {
  ProfilePreferencesService._();
  static final instance = ProfilePreferencesService._();

  static const _currencyKey = 'preferred_currency';
  Future<void> _syncQueue = Future.value();

  String _key(String uid) => 'profile_travel_preferences_v1:$uid';

  Map? _decode(String? raw) {
    try {
      final data = jsonDecode(raw ?? 'null');
      return data is Map ? data : null;
    } catch (_) {
      return null;
    }
  }

  Future<({TravelPreferences? preferences, bool pending})> loadTravel() async {
    final user = AuthService().currentUser;
    if (user == null) return (preferences: null, pending: false);
    try {
      final store = await SharedPreferences.getInstance();
      final data = _decode(store.getString(_key(user.uid)));
      final value = data?['value'];
      return (
        preferences: value is Map
            ? TravelPreferences.fromJson(value)
            : user.travelPreferences,
        pending: data?['pending'] == true && !AuthService().isGuest,
      );
    } catch (_) {
      return (preferences: user.travelPreferences, pending: false);
    }
  }

  Future<bool> saveTravel(TravelPreferences preferences) async {
    final auth = AuthService();
    final uid = auth.currentUser?.uid;
    if (uid == null) return false;
    final pending = !auth.isGuest;
    try {
      final store = await SharedPreferences.getInstance();
      if (auth.currentUser?.uid != uid) return false;
      final saved = await store.setString(
        _key(uid),
        jsonEncode({'value': preferences.toJson(), 'pending': pending}),
      );
      if (saved) notifyListeners();
      return saved;
    } catch (_) {
      return false;
    }
  }

  Future<void> syncTravel({bool refresh = false}) {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return Future.value();
    return _syncQueue = _syncQueue.then((_) async {
      final auth = AuthService();
      final client = SupabaseConfig.client;
      if (auth.isGuest ||
          auth.currentUser?.uid != uid ||
          client == null ||
          client.auth.currentUser?.id != uid) {
        return;
      }
      try {
        final store = await SharedPreferences.getInstance();
        final key = _key(uid);
        final original = store.getString(key);
        final data = _decode(original);
        if (auth.currentUser?.uid != uid ||
            client.auth.currentUser?.id != uid) {
          return;
        }
        final pending = data?['pending'] == true;
        if (!pending && !refresh) return;
        final row =
            await (pending
                    ? client
                          .from('profiles')
                          .update({'travel_preferences': data!['value']})
                          .eq('user_id', uid)
                          .select('travel_preferences')
                          .maybeSingle()
                    : client
                          .from('profiles')
                          .select('travel_preferences')
                          .eq('user_id', uid)
                          .maybeSingle())
                .timeout(const Duration(seconds: 10));
        final value = row?['travel_preferences'];
        // A save can finish while the network request is in flight.
        if (value is! Map || store.getString(key) != original) return;
        final updated = jsonEncode({'value': value, 'pending': false});
        if (updated != original && await store.setString(key, updated)) {
          notifyListeners();
        }
      } catch (_) {
        // Keep the local copy and retry on the next profile visit or resume.
      }
    });
  }

  Future<PreferredCurrency> loadCurrency() async {
    try {
      final store = await SharedPreferences.getInstance();
      final code = store.getString(_currencyKey);
      return PreferredCurrency.values.firstWhere(
        (item) => item.code == code,
        orElse: () => PreferredCurrency.myr,
      );
    } catch (_) {
      return PreferredCurrency.myr;
    }
  }

  Future<bool> saveCurrency(PreferredCurrency currency) async {
    try {
      final store = await SharedPreferences.getInstance();
      return await store.setString(_currencyKey, currency.code);
    } catch (_) {
      return false;
    }
  }
}
