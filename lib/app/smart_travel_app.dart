import 'package:flutter/material.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/shared/utils/demo_feedback.dart';
import 'package:smart_travel_planner/features/auth/screens/welcome_screen.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'travel_shell.dart';

class SmartTravelApp extends StatelessWidget {
  const SmartTravelApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

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
      home: ListenableBuilder(
        listenable: authService,
        builder: (context, _) {
          if (authService.isLoggedIn) {
            return const TravelShell();
          } else {
            return const WelcomeScreen();
          }
        },
      ),
    );
  }
}

