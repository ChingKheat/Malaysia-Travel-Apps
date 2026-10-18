import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuration manager for Supabase Cloud Backend services.
/// Adheres to Chapter 2.7 & 4.2 Architecture (Client-Cloud Layered Model).
class SupabaseConfig {
  /// Supabase Project URL.
  /// Can be overridden via `--dart-define=SUPABASE_URL=https://xyz.supabase.co`
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://yavslytukzgphvaqspcq.supabase.co',
  );

  /// Supabase Anonymous Public Key.
  /// Can be overridden via `--dart-define=SUPABASE_ANON_KEY=eyJ...`
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_6ERkrwdS5BLYRfd-JlBj2w_WTngwXsP',
  );

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  /// Returns true if the configuration has non-placeholder credentials
  static bool get isConfigured {
    return supabaseUrl.trim().isNotEmpty &&
        supabaseAnonKey.trim().isNotEmpty &&
        !supabaseUrl.contains('placeholder') &&
        !supabaseAnonKey.contains('placeholder');
  }

  /// Safely initializes Supabase. If configuration is missing or invalid,
  /// the application will proceed with fallback in-memory cache/simulation
  /// without crashing the mobile app or unit tests.
  static Future<bool> initialize() async {
    if (_initialized) return true;

    if (!isConfigured) {
      developer.log(
        'Supabase credentials not configured or set to placeholder. '
        'Running in local/offline fallback mode.',
        name: 'SupabaseConfig',
      );
      return false;
    }

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
      _initialized = true;
      developer.log('Supabase initialized successfully.', name: 'SupabaseConfig');
      return true;
    } catch (e, stack) {
      developer.log(
        'Failed to initialize Supabase: $e',
        name: 'SupabaseConfig',
        error: e,
        stackTrace: stack,
      );
      _initialized = false;
      return false;
    }
  }

  /// Safe accessor to Supabase client instance
  static SupabaseClient? get client {
    if (_initialized) {
      try {
        return Supabase.instance.client;
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
