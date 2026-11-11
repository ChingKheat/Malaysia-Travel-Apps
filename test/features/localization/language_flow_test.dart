import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/core/localization/language_controller.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';
import 'package:smart_travel_planner/features/auth/screens/welcome_screen.dart';
import 'package:smart_travel_planner/features/auth/screens/auth_screen.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/profile/screens/profile_page.dart';
import 'package:smart_travel_planner/features/home/screens/home_page.dart';
import 'package:smart_travel_planner/features/itinerary/screens/planner_page.dart';
import 'package:smart_travel_planner/app/travel_shell.dart';
import 'package:smart_travel_planner/app/smart_travel_app.dart';
import 'package:smart_travel_planner/shared/widgets/language_selector.dart';
import 'language_controller_test.dart' show MemoryLanguageStore;

Widget harness(
  LanguageController controller,
  Widget page, {
  double scale = 1,
}) => LanguageScope(
  controller: controller,
  child: ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      locale: controller.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: page,
    ),
  ),
);

Future<void> choose(WidgetTester tester, String code) async {
  await tester.tap(find.byKey(const ValueKey('app-language-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('language-$code')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'root locale changes preserve a pushed route and input, then update welcome on back',
    (tester) async {
      await AuthService().logout();
      final controller = LanguageController(store: MemoryLanguageStore());
      await tester.pumpWidget(SmartTravelApp(languageController: controller));
      await tester.ensureVisible(find.text('Log In / Sign Up'));
      await tester.tap(find.text('Log In / Sign Up'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Log In'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'retained@example.com',
      );
      await choose(tester, 'ms');
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.text('retained@example.com'), findsOneWidget);
      expect(AuthService().isLoggedIn, isFalse);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('Bahasa Aplikasi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'welcome switches all three languages and gives translated confirmation',
    (tester) async {
      final controller = LanguageController(store: MemoryLanguageStore());
      await tester.pumpWidget(harness(controller, const WelcomeScreen()));
      for (final code in ['ms', 'zh', 'en']) {
        await choose(tester, code);
        final l = lookupAppLocalizations(Locale(code));
        expect(find.text(l.appLanguage), findsOneWidget);
        expect(find.text(l.languageChanged), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets('login inputs and selected tab survive language changes', (
    tester,
  ) async {
    final controller = LanguageController(store: MemoryLanguageStore());
    await tester.pumpWidget(
      harness(controller, const AuthScreen(initialTabIndex: 0)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'tourist@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'Private123!');
    await choose(tester, 'zh');
    expect(find.text('tourist@example.com'), findsOneWidget);
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.elementAt(1).controller!.text, 'Private123!');
    expect(
      find.text(lookupAppLocalizations(const Locale('zh')).welcomeBack),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('profile uses shared selector without changing auth identity', (
    tester,
  ) async {
    final auth = AuthService();
    await tester.runAsync(() => auth.loginAsGuest());
    final uid = auth.currentUser!.uid;
    final controller = LanguageController(store: MemoryLanguageStore());
    await tester.pumpWidget(harness(controller, const ProfilePage()));
    await tester.ensureVisible(find.text('App Language'));
    await tester.tap(find.text('App Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('language-ms')));
    await tester.pumpAndSettle();
    expect(find.text('Bahasa Melayu'), findsOneWidget);
    expect(auth.currentUser!.uid, uid);
    await auth.logout();
    expect(controller.locale.languageCode, 'ms');
  });
  testWidgets(
    'failed persistence gives session-only feedback in selected language',
    (tester) async {
      final store = MemoryLanguageStore()..failWrite = true;
      final controller = LanguageController(store: store);
      await tester.pumpWidget(
        harness(controller, const Scaffold(body: LanguageButton())),
      );
      await choose(tester, 'zh');
      expect(
        find.text(
          lookupAppLocalizations(const Locale('zh')).languageSessionOnly,
        ),
        findsOneWidget,
      );
    },
  );
  for (final code in ['en', 'ms', 'zh']) {
    testWidgets('$code welcome and login fit 320px at 2x text', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = LanguageController(store: MemoryLanguageStore());
      await controller.changeLanguage(code);
      await tester.pumpWidget(
        harness(controller, const WelcomeScreen(), scale: 2),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        harness(controller, const AuthScreen(initialTabIndex: 0), scale: 2),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(LanguageButton), findsOneWidget);
      await tester.tap(find.byType(Tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
    testWidgets('$code selector and navigation fit 320px at 2x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = LanguageController(store: MemoryLanguageStore());
      await controller.changeLanguage(code);
      await tester.pumpWidget(
        harness(
          controller,
          Scaffold(
            body: const LanguageButton(),
            bottomNavigationBar: TravelBottomNavigation(
              selectedIndex: 0,
              onSelected: (_) {},
            ),
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(LanguageButton));
      await tester.pumpAndSettle();
      for (final c in ['en', 'ms', 'zh']) {
        expect(find.byKey(ValueKey('language-$c')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
    testWidgets('$code planner fits 320px at 2x and preserves selections', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = LanguageController(store: MemoryLanguageStore());
      await tester.pumpWidget(
        harness(
          controller,
          Scaffold(body: PlannerPage(onItineraryReady: () {})),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      await controller.changeLanguage(code);
      await tester.pumpAndSettle();
      final l = lookupAppLocalizations(Locale(code));
      for (final label in [
        l.tripDetails2,
        l.yourDailyPace,
        l.dailyBudget,
        l.gettingAround,
        l.makeItYourKindOfTrip,
      ]) {
        final finder = find.text(label);
        await tester.scrollUntilVisible(
          finder,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, l.food))
            .selected,
        isTrue,
      );
    });
    testWidgets('$code home hero panel fits 320px at 2x text inside ListView', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = LanguageController(store: MemoryLanguageStore());
      await controller.changeLanguage(code);
      await tester.pumpWidget(
        harness(
          controller,
          Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: [HeroPanel(onSearchTap: () {})],
            ),
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      final l = lookupAppLocalizations(Locale(code));
      expect(find.text(l.smartTravelPlanning2), findsOneWidget);
      expect(find.text(l.whereToNext), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
