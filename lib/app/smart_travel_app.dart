import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';
import 'package:smart_travel_planner/core/localization/language_controller.dart';
import 'package:smart_travel_planner/features/onboarding/screens/onboarding_setup_screen.dart';
import 'package:smart_travel_planner/features/onboarding/services/onboarding_service.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/shared/utils/demo_feedback.dart';
import 'package:smart_travel_planner/features/auth/screens/auth_screen.dart';
import 'package:smart_travel_planner/features/auth/screens/welcome_screen.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'travel_shell.dart';

class SmartTravelApp extends StatelessWidget {
  const SmartTravelApp({
    super.key,
    this.languageController,
    this.onboardingService,
    this.skipOnboarding = false,
  });

  final LanguageController? languageController;
  final OnboardingService? onboardingService;
  final bool skipOnboarding;

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final onboarding = onboardingService ?? OnboardingService.instance;

    final controller = languageController ?? LanguageController.instance;
    return LanguageScope(
      controller: controller,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => MaterialApp(
          locale: controller.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          onGenerateTitle: (context) => context.l10n.smartTravelPlanning2,
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
            listenable: Listenable.merge([authService, onboarding]),
            builder: (context, _) {
              if (authService.isLoggedIn) {
                return const TravelShell();
              }
              if (!skipOnboarding && !onboarding.isCompleted) {
                return const OnboardingSetupScreen();
              }
              if (skipOnboarding) {
                return const WelcomeScreen(showLanguageSelector: true);
              }
              return const AuthScreen(
                initialTabIndex: 0,
                showLanguageSelector: false,
              );
            },
          ),
        ),
      ),
    );
  }
}
