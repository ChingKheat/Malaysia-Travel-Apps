import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/demo_feedback.dart';
import 'travel_shell.dart';

class SmartTravelApp extends StatelessWidget {
  const SmartTravelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Travel Planning',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF7F8FD),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.teal,
          surface: Colors.white,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: primaryFilledButtonStyle(),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: demoOutlinedButtonStyle(),
        ),
      ),
      home: const TravelShell(),
    );
  }
}
