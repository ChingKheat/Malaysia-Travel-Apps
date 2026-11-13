import 'package:flutter/material.dart';
import 'package:smart_travel_planner/core/localization/language_controller.dart';
import 'package:smart_travel_planner/features/onboarding/services/onboarding_service.dart';

import 'package:smart_travel_planner/app/smart_travel_app.dart';
import 'package:smart_travel_planner/core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LanguageController.instance.load();
  await OnboardingService.instance.load();

  // Initialize Supabase backend (safe with local fallback)
  await SupabaseConfig.initialize();

  runApp(const SmartTravelApp());
}
