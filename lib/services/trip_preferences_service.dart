import '../models/trip_preferences.dart';
import '../data/malaysia_states.dart';

class PreferencesValidationResult {
  final bool success;
  final String message;
  final Set<String> emptyFields;

  const PreferencesValidationResult({
    required this.success,
    required this.message,
    this.emptyFields = const {},
  });
}

class TripPreferencesService {
  // Messages M1 to M8
  static const String m1Success = 'Trip preferences recorded successfully. Generating your itinerary.';
  static const String m2Mandatory = 'Please complete all mandatory trip-preference fields.';
  static const String m3InvalidDestination = 'Please enter or select a valid destination.';
  static const String m4InvalidDays = 'Please select a valid number of travel days.';
  static const String m5InvalidTimeRange = 'Daily end time must be later than daily start time.';
  static const String m6NoInterests = 'Please select at least one travel interest.';
  static const String m7InvalidBudget = 'Please select a valid estimated budget category.';
  static const String m8UnsupportedMode = 'The selected travel mode is not supported. Please select Driving or Walking.';

  // Temporarily stored preferences
  static TripPreferences? _storedPreferences;
  static TripPreferences? get storedPreferences => _storedPreferences;

  /// Validates the trip preferences according to UC300 requirements (C1-C7)
  static PreferencesValidationResult validatePreferences(TripPreferences prefs) {
    final Set<String> emptyFields = {};

    // C1 / A1: Mandatory fields check
    if (prefs.destination == null || prefs.destination!.trim().isEmpty) {
      emptyFields.add('destination');
    }
    if (prefs.numberOfDays == null) {
      emptyFields.add('numberOfDays');
    }
    if (prefs.dailyStartTime == null) {
      emptyFields.add('dailyStartTime');
    }
    if (prefs.dailyEndTime == null) {
      emptyFields.add('dailyEndTime');
    }
    if (prefs.budgetCategory == null || prefs.budgetCategory!.trim().isEmpty) {
      emptyFields.add('budgetCategory');
    }
    if (prefs.travelMode == null || prefs.travelMode!.trim().isEmpty) {
      emptyFields.add('travelMode');
    }

    if (emptyFields.isNotEmpty) {
      return PreferencesValidationResult(
        success: false,
        message: m2Mandatory,
        emptyFields: emptyFields,
      );
    }

    // C2 / A2: Valid Destination Check (must exist in Malaysia state list)
    final isDestValid = malaysiaStates.any(
      (state) => state.toLowerCase() == prefs.destination!.trim().toLowerCase(),
    );
    if (!isDestValid) {
      return const PreferencesValidationResult(
        success: false,
        message: m3InvalidDestination,
      );
    }

    // C3 / A3: Valid number of travel days check (must satisfy configured range: 1 to 30 days)
    if (prefs.numberOfDays! < 1 || prefs.numberOfDays! > 30) {
      return const PreferencesValidationResult(
        success: false,
        message: m4InvalidDays,
      );
    }

    // C4 / A4: Valid Daily Time Range Check (end time must be later than start time)
    final startMinutes = prefs.dailyStartTime!.hour * 60 + prefs.dailyStartTime!.minute;
    final endMinutes = prefs.dailyEndTime!.hour * 60 + prefs.dailyEndTime!.minute;
    if (endMinutes <= startMinutes) {
      return const PreferencesValidationResult(
        success: false,
        message: m5InvalidTimeRange,
      );
    }

    // C5 / A5: Travel Interest Selection Check (must select at least one interest)
    if (prefs.interests.isEmpty) {
      return const PreferencesValidationResult(
        success: false,
        message: m6NoInterests,
      );
    }

    // C6 / A6: Valid Estimated Budget Category Check
    final validBudgets = {'Low', 'Medium', 'High'};
    if (!validBudgets.contains(prefs.budgetCategory)) {
      return const PreferencesValidationResult(
        success: false,
        message: m7InvalidBudget,
      );
    }

    // C7 / A7: Supported Travel Mode Check (Driving or Walking only in this prototype)
    final supportedModes = {'Driving', 'Walking'};
    if (!supportedModes.contains(prefs.travelMode)) {
      return const PreferencesValidationResult(
        success: false,
        message: m8UnsupportedMode,
      );
    }

    // FR300_10: Store preferences temporarily
    _storedPreferences = prefs;

    return const PreferencesValidationResult(
      success: true,
      message: m1Success,
    );
  }
}
