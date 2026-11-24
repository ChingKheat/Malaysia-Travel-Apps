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

    test(
      'Countrywide food starters suggest dishes and ask for a city',
      () async {
        for (final (language, prompt, question) in [
          (
            AssistantLanguage.english,
            'Suggest food options in Malaysia.',
            'Which city',
          ),
          (
            AssistantLanguage.malay,
            'Cadangkan pilihan makanan di Malaysia.',
            'Bandar mana',
          ),
          (AssistantLanguage.chinese, '请推荐马来西亚的餐饮选项。', '哪个城市'),
        ]) {
          service.clearConversation();
          service.currentLanguage = language;
          final response = await service.askAssistant(prompt);
          expect(response.text, contains(question));
          expect(response.followUpChips, contains('Kuala Lumpur'));
          expect(response.text.toLowerCase(), contains('nasi lemak'));
          expect(response.places, isEmpty);
        }
      },
    );

    test('A city follow-up to the food starter returns venue cards', () async {
      service.clearConversation();
      await service.askAssistant('Suggest food options in Malaysia.');

      final response = await service.askAssistant('Kuala Lumpur');

      expect(response.text, contains('Kuala Lumpur'));
      expect(response.places, isNotEmpty);
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
      expect(greetingBm.text, contains('perjalanan anda'));

      service.currentLanguage = AssistantLanguage.chinese;
      final greetingZh = service.getInitialGreeting();
      expect(greetingZh.text, contains('旅行'));
    });
  });

  group('UC900 Assistant Page Widget Tests', () {
    setUp(() {
      TravelAssistantService().currentLanguage = AssistantLanguage.english;
    });

    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('Select questions without typing in ${locale.languageCode}', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const Scaffold(body: AssistantPage()),
          ),
        );
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(
          tester.element(find.byType(AssistantPage)),
        )!;
        expect(find.byType(TextField), findsNothing);
        for (final question in [
          l.assistantPromptWeather,
          l.assistantPromptFood,
          l.assistantPromptTransport,
          l.assistantPromptItinerary,
        ]) {
          expect(find.widgetWithText(ListTile, question), findsOneWidget);
        }
        await tester.tap(find.text(l.assistantPromptTransport));
        await tester.pumpAndSettle();
        expect(find.byType(AssistantChatBubble), findsNWidgets(3));
        await tester.tap(find.text(l.assistantChooseQuestion));
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(ListTile, l.assistantPromptWeather),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
