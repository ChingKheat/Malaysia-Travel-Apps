import 'package:flutter/material.dart';
import '../models/user_model.dart';

class RegisterResult {
  final bool success;
  final String message;
  final UserModel? user;
  final Set<String> emptyFields;

  RegisterResult({
    required this.success,
    required this.message,
    this.user,
    this.emptyFields = const {},
  });
}

class LoginResult {
  final bool success;
  final String message;
  final UserModel? user;
  final Set<String> emptyFields;

  LoginResult({
    required this.success,
    required this.message,
    this.user,
    this.emptyFields = const {},
  });
}

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    // Seed initial pre-registered account profiles into simulated Cloud Firestore (FR200_8)
    _seedInitialFirestoreUser(
      uid: 'usr_chingkheat_1001',
      name: 'Ching Kheat',
      email: 'chingkheat@example.com',
      password: 'SafeP@ss123!',
    );
    _seedInitialFirestoreUser(
      uid: 'usr_tourist_1002',
      name: 'Smart Tourist',
      email: 'tourist@example.com',
      password: 'SafeP@ss123!',
    );
  }

  UserModel? _currentUser;
  bool _isLoading = false;

  // Cloud Firestore simulated collection (FR100_9 & FR200_8)
  final Map<String, Map<String, dynamic>> _firestoreUsers = {};

  // Account passkeys for simulated credential check (in-memory only)
  final Map<String, String> _userPasswords = {};

  // Map email -> uid for fast Firestore lookup
  final Map<String, String> _emailToUid = {};

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  Map<String, Map<String, dynamic>> get firestoreUsers => _firestoreUsers;

  // Standard UC100 Messages (M1 to M6)
  static const String m1AccountCreated = 'Account created successfully.';
  static const String m2MandatoryFields = 'Please complete all mandatory fields.';
  static const String m3InvalidEmail = 'Please enter a valid email address.';
  static const String m4WeakPassword =
      'Password must contain at least 8 characters, including one uppercase letter, one lowercase letter, one number, and one special character.';
  static const String m5PasswordMismatch = 'Password and Confirm Password do not match.';
  static const String m6EmailAlreadyRegistered =
      'This email address has already been registered. Please log in or use another email address.';

  // Standard UC200 Messages (M1 to M6)
  static const String m1LoginSuccess = 'Login successful. Redirecting to the homepage.';
  static const String m2LoginMandatory = 'Please enter your email address and password.';
  static const String m3LoginInvalidEmail = 'Please enter a valid email address.';
  static const String m4InvalidCredentials = 'The email address or password is incorrect. Please try again.';
  static const String m5ServiceUnavailable = 'Authentication service is currently unavailable. Please try again later.';
  static const String m6RequestTimeout = 'The login request timed out. Please try again.';

  void _seedInitialFirestoreUser({
    required String uid,
    required String name,
    required String email,
    required String password,
  }) {
    final cleanEmail = email.toLowerCase();
    final user = UserModel(
      uid: uid,
      name: name,
      email: cleanEmail,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&h=150&q=80',
      nationality: 'Malaysia 🇲🇾',
      travelStyle: 'Cultural Explorer',
      tripsPlanned: 12,
      placesVisited: 45,
      memberSince: 'June 2025',
    );
    _firestoreUsers[uid] = user.toFirestore();
    _userPasswords[cleanEmail] = password;
    _emailToUid[cleanEmail] = uid;
  }

  // --- Validation Helper Methods ---

  /// C2: Valid Email Format Regex
  static bool isValidEmail(String email) {
    if (email.trim().isEmpty) return false;
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email.trim());
  }

  /// C3: Password Strength Checks
  static bool hasMinLength(String pwd) => pwd.length >= 8;
  static bool hasUppercase(String pwd) => RegExp(r'[A-Z]').hasMatch(pwd);
  static bool hasLowercase(String pwd) => RegExp(r'[a-z]').hasMatch(pwd);
  static bool hasDigit(String pwd) => RegExp(r'[0-9]').hasMatch(pwd);
  static bool hasSpecialChar(String pwd) => RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pwd);

  static bool isStrongPassword(String pwd) {
    return hasMinLength(pwd) &&
        hasUppercase(pwd) &&
        hasLowercase(pwd) &&
        hasDigit(pwd) &&
        hasSpecialChar(pwd);
  }

  // --- Core UC200 Login Flow ---

  /// UC200 Login Implementation (FR200_1 to FR200_9)
  Future<LoginResult> loginUser({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    // C1: Mandatory Fields Check (A1)
    final Set<String> emptyFields = {};
    if (email.trim().isEmpty) emptyFields.add('email');
    if (password.isEmpty) emptyFields.add('password');

    if (emptyFields.isNotEmpty) {
      _isLoading = false;
      notifyListeners();
      return LoginResult(
        success: false,
        message: m2LoginMandatory,
        emptyFields: emptyFields,
      );
    }

    // C2: Valid Email Format Check (A2)
    if (!isValidEmail(email)) {
      _isLoading = false;
      notifyListeners();
      return LoginResult(
        success: false,
        message: m3LoginInvalidEmail,
      );
    }

    // Network latency / Secure HTTPS connection simulation (C7)
    await Future.delayed(const Duration(milliseconds: 600));

    final cleanEmail = email.trim().toLowerCase();

    // FR200_5 & C4: Validate credentials against Firebase Auth
    // Constraint C6: Must NOT reveal whether email account exists (generic M4)
    final expectedPassword = _userPasswords[cleanEmail];
    if (expectedPassword == null || expectedPassword != password) {
      _isLoading = false;
      notifyListeners();
      return LoginResult(
        success: false,
        message: m4InvalidCredentials,
      );
    }

    // FR200_6: Firebase Auth returns uid
    final uid = _emailToUid[cleanEmail]!;

    // FR200_8: Retrieve user profile from Cloud Firestore
    final docData = _firestoreUsers[uid];
    final UserModel authenticatedUser = docData != null
        ? UserModel.fromFirestore(docData, uid)
        : UserModel(
            uid: uid,
            name: cleanEmail.split('@').first,
            email: cleanEmail,
            createdAt: DateTime.now(),
          );

    // FR200_7: Establish and maintain user's authenticated session
    _currentUser = authenticatedUser;
    _isLoading = false;
    notifyListeners();

    // FR200_9: Display M1 and redirect
    return LoginResult(
      success: true,
      message: m1LoginSuccess,
      user: authenticatedUser,
    );
  }

  /// Backwards-compatible login method returning boolean
  Future<bool> login(String email, String password) async {
    final res = await loginUser(email: email, password: password);
    return res.success;
  }

  // --- Core UC100 Registration Flow ---

  Future<RegisterResult> registerUser({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    _isLoading = true;
    notifyListeners();

    final Set<String> emptyFields = {};
    if (name.trim().isEmpty) emptyFields.add('name');
    if (email.trim().isEmpty) emptyFields.add('email');
    if (password.isEmpty) emptyFields.add('password');
    if (confirmPassword.isEmpty) emptyFields.add('confirmPassword');

    if (emptyFields.isNotEmpty) {
      _isLoading = false;
      notifyListeners();
      return RegisterResult(
        success: false,
        message: m2MandatoryFields,
        emptyFields: emptyFields,
      );
    }

    if (!isValidEmail(email)) {
      _isLoading = false;
      notifyListeners();
      return RegisterResult(
        success: false,
        message: m3InvalidEmail,
      );
    }

    if (!isStrongPassword(password)) {
      _isLoading = false;
      notifyListeners();
      return RegisterResult(
        success: false,
        message: m4WeakPassword,
      );
    }

    if (password != confirmPassword) {
      _isLoading = false;
      notifyListeners();
      return RegisterResult(
        success: false,
        message: m5PasswordMismatch,
      );
    }

    await Future.delayed(const Duration(milliseconds: 800));

    final cleanEmail = email.trim().toLowerCase();
    if (_userPasswords.containsKey(cleanEmail)) {
      _isLoading = false;
      notifyListeners();
      return RegisterResult(
        success: false,
        message: m6EmailAlreadyRegistered,
      );
    }

    final String uid = 'usr_fb_${DateTime.now().millisecondsSinceEpoch}';
    final DateTime createdAt = DateTime.now();

    final newUser = UserModel(
      uid: uid,
      name: name.trim(),
      email: cleanEmail,
      createdAt: createdAt,
      avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&h=150&q=80',
      nationality: 'Malaysia 🇲🇾',
      travelStyle: 'Smart Traveler',
      tripsPlanned: 0,
      placesVisited: 0,
      memberSince: 'Just now',
    );

    _firestoreUsers[uid] = newUser.toFirestore();
    _userPasswords[cleanEmail] = password;
    _emailToUid[cleanEmail] = uid;

    _currentUser = newUser;
    _isLoading = false;
    notifyListeners();

    return RegisterResult(
      success: true,
      message: m1AccountCreated,
      user: newUser,
    );
  }

  // --- Helper Guest & Logout Methods ---

  Future<void> loginAsGuest() async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    _currentUser = UserModel(
      uid: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Guest Traveler',
      email: 'guest@smarttravel.my',
      createdAt: DateTime.now(),
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
