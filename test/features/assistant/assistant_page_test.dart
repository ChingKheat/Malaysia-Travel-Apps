import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/assistant/screens/assistant_page.dart';
import 'package:smart_travel_planner/features/assistant/services/travel_assistant_service.dart';
import 'package:smart_travel_planner/features/assistant/widgets/assistant_chat_bubble.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';

void main() {
  group('UC900 Travel Assistant Service Unit Tests', () {
    late TravelAssistantService service;

    setUp(() {
      service = TravelAssistantService();
      service.currentLanguage = AssistantLanguage.english;
    });

    test('FR900_2: Validates empty and short prompts before processing', () {
      expect(service.validatePrompt(null), isNotNull);
      expect(service.validatePrompt(''), isNotNull);
      expect(service.validatePrompt('   '), isNotNull);
      expect(service.validatePrompt('a'), isNotNull);
      expect(service.validatePrompt('Rain in KL'), isNull);
    });

    test('FR900_5: Generates context-aware weather response with indoor recommendations', () async {
      final response = await service.askAssistant('Is it going to rain today?');
      expect(response.isUser, isFalse);
      expect(response.weatherAlert, isNotNull);
      expect(response.weatherAlert?.city, 'Kuala Lumpur');
      expect(response.places, isNotEmpty);
      expect(response.places.first.name, contains('Aquaria'));
    });

    test('FR900_5: Generates food recommendations for Bukit Bintang and Jalan Alor', () async {
      final response = await service.askAssistant('Best local halal food to try');
      expect(response.isUser, isFalse);
      expect(response.places, isNotEmpty);
      expect(response.places.any((p) => p.name.contains('Jalan Alor')), isTrue);
    });

    test('FR500 & FR900: Provides multilingual greetings and responses', () {
      service.currentLanguage = AssistantLanguage.malay;
      final greetingBm = service.getInitialGreeting();
      expect(greetingBm.text, contains('Selamat Datang'));

      service.currentLanguage = AssistantLanguage.chinese;
      final greetingZh = service.getInitialGreeting();
      expect(greetingZh.text, contains('欢迎来到马来西亚'));
    });
  });

  group('UC900 Assistant Page Widget Tests', () {
    setUp(() {
      TravelAssistantService().currentLanguage = AssistantLanguage.english;
    });

    testWidgets('FR900_1: Renders chat stream, prompt carousel, and input bar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AssistantPage(),
          ),
        ),
      );
      await tester.pump();

      // Verify AI status and initial message bubble
      expect(find.textContaining('Gemini 1.5 Flash'), findsOneWidget);
      expect(find.byType(AssistantChatBubble), findsOneWidget);
      expect(find.textContaining('Selamat Datang'), findsOneWidget);

      // Verify quick prompt chips
      expect(find.textContaining('Is it going to rain'), findsWidgets);
      expect(find.textContaining('Best Halal food'), findsWidgets);

      // Verify input bar and actions
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('Send Prompt'), findsOneWidget);
      expect(find.byTooltip('Voice Search'), findsOneWidget);
      expect(find.byTooltip('Reset Conversation'), findsOneWidget);
    });

    testWidgets('FR900_3 & FR900_6: Typing and sending a prompt renders user bubble and response', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AssistantPage(),
          ),
        ),
      );
      await tester.pump();

      // Enter a prompt in the textfield
      await tester.enterText(find.byType(TextField), 'Is it going to rain in KL today?');
      await tester.tap(find.byTooltip('Send Prompt'));
      await tester.pump();

      // User message rendered
      expect(find.text('Is it going to rain in KL today?'), findsOneWidget);

      // Pump through assistant delay
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Verify AI response with place card
      expect(find.textContaining('Aquaria KLCC'), findsWidgets);
    });

    testWidgets('Status header does not overflow in Malay or narrow viewport', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('ms'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: AssistantPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('AI Pelancongan Malaysia'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
