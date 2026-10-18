import 'package:flutter/material.dart';

import 'app/smart_travel_app.dart';
import 'core/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase backend (safe with local fallback)
  await SupabaseConfig.initialize();

  runApp(const SmartTravelApp());
}
