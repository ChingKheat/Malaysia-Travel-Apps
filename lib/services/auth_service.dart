import 'package:flutter/material.dart';

class TravelUser {
  final String name;
  final String email;
  final String avatarUrl;
  final String nationality;
  final String travelStyle;
  final int tripsPlanned;
  final int placesVisited;
  final String memberSince;

  const TravelUser({
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.nationality,
    required this.travelStyle,
    required this.tripsPlanned,
    required this.placesVisited,
    required this.memberSince,
  });
}

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  TravelUser? _currentUser;
  bool _isLoading = false;

  TravelUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    // Mock API call delay
    await Future.delayed(const Duration(milliseconds: 1200));

    if (email.isNotEmpty && password.length >= 6) {
      _currentUser = const TravelUser(
        name: 'Ching Kheat',
        email: 'chingkheat@example.com',
        avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&h=150&q=80',
        nationality: 'Malaysia 🇲🇾',
        travelStyle: 'Cultural Explorer',
        tripsPlanned: 12,
        placesVisited: 45,
        memberSince: 'June 2025',
      );
      _isLoading = false;
      notifyListeners();
      return true;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> loginAsGuest() async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 800));

    _currentUser = const TravelUser(
      name: 'Guest Traveler',
      email: 'guest@smarttravel.my',
      avatarUrl: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?auto=format&fit=crop&w=150&h=150&q=80',
      nationality: 'International 🌍',
      travelStyle: 'Backpacker',
      tripsPlanned: 1,
      placesVisited: 3,
      memberSince: 'Just now',
    );
    _isLoading = false;
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}
