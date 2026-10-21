import 'package:flutter/material.dart';

import 'package:smart_travel_planner/app/smart_travel_app.dart';
import 'package:smart_travel_planner/core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase backend (safe with local fallback)
  await SupabaseConfig.initialize();

  runApp(const SmartTravelApp());
}
