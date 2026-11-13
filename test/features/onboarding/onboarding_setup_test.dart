import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/core/localization/language_controller.dart';
import 'package:smart_travel_planner/features/onboarding/screens/onboarding_setup_screen.dart';
import 'package:smart_travel_planner/features/onboarding/services/onboarding_service.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';
import 'package:smart_travel_planner/shared/services/location_service.dart';

class _TestMemoryLanguageStore implements LanguageStore {
  String? value = 'en';
  @override
  Future<String?> read() async => value;
  @override
  Future<bool> write(String code) async {
    value = code;
    return true;
  }
}

Widget testHarness(
  Widget child, {
  LanguageController? controller,
  double textScale = 1.0,
}) {
  final ctrl = controller ?? LanguageController.instance;
  return LanguageScope(
    controller: ctrl,
    child: ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) => MaterialApp(
        locale: ctrl.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, widget) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: widget!,
        ),
        home: child,
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OnboardingService.instance.resetForTesting(isCompleted: false);
  });

  testWidgets('OnboardingSetupScreen renders English, Malay, Chinese (No Tamil) and dynamically updates language & location', (
    WidgetTester tester,
  ) async {
    bool completed = false;
    final controller = LanguageController(store: _TestMemoryLanguageStore());

    await tester.pumpWidget(
      testHarness(
        OnboardingSetupScreen(
          isRevisit: true,
          languageController: controller,
          onCompleted: () => completed = true,
          locationPermissionRequester: () async => true,
        ),
        controller: controller,
      ),
    );
    await tester.pumpAndSettle();

    // Step 1: Language Preference in English by default
    expect(find.text('Citylore'), findsOneWidget);
    expect(find.text('Welcome setup · Step 1 of 3'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Bahasa Melayu'), findsOneWidget);
    expect(find.text('中文 (简体)'), findsOneWidget);
    // Tamil must NOT exist per user requirement
    expect(find.text('தமிழ் (Tamil)'), findsNothing);

    // Tap Chinese option
    await tester.ensureVisible(find.byKey(const ValueKey('language-option-zh')));
    await tester.tap(find.byKey(const ValueKey('language-option-zh')));
    await tester.pumpAndSettle();

    // Verify dynamic localization to Chinese immediately
    expect(OnboardingService.instance.selectedLanguage, 'zh');
    expect(controller.locale.languageCode, 'zh');
    expect(find.text('欢迎设置 · 第 1 步，共 3 步'), findsOneWidget);
    expect(find.text('选择您的\n导览语言'), findsOneWidget);

    // Tap Continue -> advances to Step 2
    await tester.tap(find.byKey(const ValueKey('onboarding-cta-button')));
    await tester.pumpAndSettle();

    // Step 2: Location Access in Chinese
    expect(find.text('欢迎设置 · 第 2 步，共 3 步'), findsOneWidget);
    expect(find.text('探索您身边的\n地标与特色咖啡馆'), findsOneWidget);
    expect(find.text('为什么 Citylore 需要您的位置'), findsOneWidget);

    // Tap Allow Location Access
    await tester.tap(find.byKey(const ValueKey('allow-location-button')));
    await tester.pumpAndSettle();
    expect(OnboardingService.instance.locationGranted, isTrue);
    expect(LocationService().isUsingRealGps, isTrue);
    expect(find.text('已获得位置权限 ✓'), findsOneWidget);

    // Tap back to Step 1 using back button
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('欢迎设置 · 第 1 步，共 3 步'), findsOneWidget);

    // Continue again to Step 2 then Step 3
    await tester.tap(find.byKey(const ValueKey('onboarding-cta-button')));
    await tester.pumpAndSettle();
    expect(find.text('欢迎设置 · 第 2 步，共 3 步'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-cta-button')));
    await tester.pumpAndSettle();

    // Step 3: Terms & Privacy in Chinese
    expect(find.text('欢迎设置 · 第 3 步，共 3 步'), findsOneWidget);
    expect(find.text('您的隐私与\n旅行服务条款'), findsOneWidget);
    expect(find.text('Citylore 条款摘要'), findsOneWidget);

    // Open Terms & Privacy details sheet in Chinese
    await tester.tap(find.byKey(const ValueKey('read-terms-details-button')));
    await tester.pumpAndSettle();
    expect(find.text('服务条款与隐私政策'), findsOneWidget);
    expect(find.text('我已了解'), findsOneWidget);

    // Dismiss terms sheet
    await tester.tap(find.text('我已了解'));
    await tester.pumpAndSettle();

    // Tap Accept & Continue without checking agreement (shows inline warning)
    await tester.tap(find.byKey(const ValueKey('onboarding-cta-button')));
    await tester.pumpAndSettle();
    expect(completed, isFalse);
    expect(find.text('请同意条款与条件以继续'), findsOneWidget);

    // Check agreement
    await tester.ensureVisible(find.byKey(const ValueKey('terms-agreement-card')));
    await tester.tap(find.byKey(const ValueKey('terms-agreement-card')));
    await tester.pumpAndSettle();

    // Tap Accept & Continue with agreement
    await tester.tap(find.byKey(const ValueKey('onboarding-cta-button')));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(OnboardingService.instance.isCompleted, isTrue);
    expect(OnboardingService.instance.termsAcceptedAt, isNotNull);
  });

  testWidgets('OnboardingSetupScreen manual location option sets default KL location and advances', (
    WidgetTester tester,
  ) async {
    final controller = LanguageController(store: _TestMemoryLanguageStore());
    await tester.pumpWidget(
      testHarness(
        OnboardingSetupScreen(
          isRevisit: true,
          languageController: controller,
        ),
        controller: controller,
      ),
    );
    await tester.pumpAndSettle();

    // Step 1 -> Step 2
    await tester.tap(find.byKey(const ValueKey('onboarding-cta-button')));
    await tester.pumpAndSettle();

    // Tap manual browse
    await tester.ensureVisible(find.byKey(const ValueKey('manual-location-button')));
    await tester.tap(find.byKey(const ValueKey('manual-location-button')));
    await tester.pumpAndSettle();

    expect(OnboardingService.instance.locationGranted, isFalse);
    expect(LocationService().isUsingRealGps, isFalse);
    expect(LocationService().currentAreaName, 'Kuala Lumpur City Centre');
    // Advances to Step 3
    expect(find.text('Welcome setup · Step 3 of 3'), findsOneWidget);
  });

  testWidgets('OnboardingSetupScreen fits 320px width at 2x text scaler without overflow', (
    WidgetTester tester,
  ) async {
    final controller = LanguageController(store: _TestMemoryLanguageStore());
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      testHarness(
        OnboardingSetupScreen(
          isRevisit: true,
          languageController: controller,
        ),
        controller: controller,
        textScale: 2.0,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Next page
    await tester.tap(find.byKey(const ValueKey('onboarding-cta-button')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Next page
    await tester.tap(find.byKey(const ValueKey('onboarding-cta-button')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
