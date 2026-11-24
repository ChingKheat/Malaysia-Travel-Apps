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

    test('A city answers the outstanding food question only once', () async {
      service.clearConversation();
      expect(
        (await service.askAssistant('Halal food near me')).text,
        contains('Which city'),
      );
      expect(
        (await service.askAssistant('Melaka')).text,
        contains('halal status'),
      );
      expect(
        (await service.askAssistant('Melaka')).text,
        contains('What would you like help with'),
      );
    });

    test('Weather without a location asks for one', () async {
      final response = await service.askAssistant('Is it going to rain today?');
      expect(response.isUser, isFalse);
      expect(response.weatherAlert, isNull);
      expect(response.text, contains('Which location'));
    });

    test(
      'Weather without data identifies the requested location and date',
      () async {
        final response = await service.askAssistant(
          'Weather in Kuala Lumpur on 2099-01-01',
        );
        expect(response.text, contains('kuala lumpur'));
        expect(response.text, contains('2099-01-01'));
        expect(response.text, contains('Forecast unavailable'));
      },
    );

    test('FR500 & FR900: Provides multilingual greetings and responses', () {
      service.currentLanguage = AssistantLanguage.malay;
      final greetingBm = service.getInitialGreeting();
      expect(greetingBm.text, contains('Bagaimana saya boleh membantu'));

      service.currentLanguage = AssistantLanguage.chinese;
      final greetingZh = service.getInitialGreeting();
      expect(greetingZh.text, contains('您的旅行需要什么帮助'));
    });
  });

  group('UC900 Assistant Page Widget Tests', () {
    setUp(() {
      TravelAssistantService().currentLanguage = AssistantLanguage.english;
    });

    testWidgets('FR900_1: Renders the chat and four starter actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AssistantPage())),
      );
      await tester.pump();

      // Verify AI status and initial message bubble
      expect(find.textContaining('Gemini'), findsNothing);
      expect(find.byType(AssistantChatBubble), findsOneWidget);
      expect(find.text('How can I help with your trip?'), findsOneWidget);

      // Verify quick prompt chips
      for (final label in ['Weather', 'Food', 'Transport', 'Itinerary help']) {
        expect(find.text(label), findsOneWidget);
      }

      // Verify input bar and actions
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('Send Prompt'), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
      await tester.tap(find.byTooltip('Chat options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New chat'));
      await tester.pumpAndSettle();
      expect(find.text('Clear Chat History?'), findsOneWidget);
    });

    testWidgets(
      'FR900_3 & FR900_6: Typing and sending a prompt renders user bubble and response',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: AssistantPage())),
        );
        await tester.pump();

        // Enter a prompt in the textfield
        await tester.enterText(
          find.byType(TextField),
          'Weather in Kuala Lumpur on 2099-01-01',
        );
        await tester.tap(find.byTooltip('Send Prompt'));
        await tester.pump();

        // User message rendered
        expect(
          find.text('Weather in Kuala Lumpur on 2099-01-01'),
          findsOneWidget,
        );

        // Pump through assistant delay
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        // Verify AI response with place card
        expect(find.textContaining('Forecast unavailable'), findsOneWidget);
      },
    );

    for (final (locale, labels) in [
      ('en', ['Weather', 'Food', 'Transport', 'Itinerary help']),
      ('ms', ['Cuaca', 'Makanan', 'Pengangkutan', 'Bantuan itinerari']),
      ('zh', ['天气', '餐饮', '交通', '行程帮助']),
    ]) {
      testWidgets('Starter actions fit at 320 px in $locale', (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const Scaffold(body: AssistantPage()),
          ),
        );
        await tester.pumpAndSettle();
        for (final label in labels) {
          expect(find.widgetWithText(OutlinedButton, label), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  });
}
