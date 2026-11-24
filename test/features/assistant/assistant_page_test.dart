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
      expect(greetingBm.text, contains('Pilih pintasan'));

      service.currentLanguage = AssistantLanguage.chinese;
      final greetingZh = service.getInitialGreeting();
      expect(greetingZh.text, contains('快捷选项'));
    });
  });

  group('UC900 Assistant Page Widget Tests', () {
    setUp(() {
      TravelAssistantService().currentLanguage = AssistantLanguage.english;
    });

    testWidgets('Weather and directions start editable, unsent prompts', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AssistantPage())),
      );
      final send = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Send Prompt',
      );
      final field = find.byType(TextField);
      expect(tester.widget<IconButton>(send).onPressed, isNull);

      await tester.tap(find.text('Check weather'));
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, 'Weather in ');
      expect(tester.widget<IconButton>(send).onPressed, isNull);
      expect(find.byType(AssistantChatBubble), findsOneWidget);

      await tester.tap(find.text('Get directions'));
      await tester.pump();
      expect(
        tester.widget<TextField>(field).controller!.text,
        'Directions from ',
      );
      expect(tester.widget<IconButton>(send).onPressed, isNull);
      expect(find.byType(AssistantChatBubble), findsOneWidget);

      await tester.enterText(
        field,
        'Directions from George Town to Batu Ferringhi',
      );
      await tester.pump();
      expect(tester.widget<IconButton>(send).onPressed, isNotNull);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(
        find.text('Directions from George Town to Batu Ferringhi'),
        findsOneWidget,
      );
      expect(
        find.textContaining('I can’t check directions for this route'),
        findsOneWidget,
      );
      expect(find.textContaining('KLIA Ekspres'), findsNothing);
      expect(tester.widget<IconButton>(send).onPressed, isNull);
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
      expect(
        find.text('Pick a shortcut below or type a travel question.'),
        findsOneWidget,
      );

      // Verify quick prompt chips
      for (final label in [
        'Check weather',
        'Find food',
        'Get directions',
        'Itinerary help',
      ]) {
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

        // Complete the weather draft with a destination other than its old default.
        await tester.tap(find.text('Check weather'));
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'Weather in Penang');
        await tester.pump();
        await tester.tap(find.byTooltip('Send Prompt'));
        await tester.pumpAndSettle();

        expect(find.text('Weather in Penang'), findsOneWidget);
        expect(find.textContaining('What date should I check'), findsOneWidget);
      },
    );

    for (final (locale, labels) in [
      (
        'en',
        ['Check weather', 'Find food', 'Get directions', 'Itinerary help'],
      ),
      (
        'ms',
        ['Semak cuaca', 'Cari makanan', 'Dapatkan arah', 'Bantuan itinerari'],
      ),
      ('zh', ['查天气', '找美食', '查路线', '行程帮助']),
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
        final positions = labels
            .map(
              (label) =>
                  tester.getTopLeft(find.widgetWithText(OutlinedButton, label)),
            )
            .toList();
        expect(positions[0].dy, positions[1].dy);
        expect(positions[2].dy, positions[3].dy);
        expect(positions[0].dx, positions[2].dx);
        expect(positions[1].dx, positions[3].dx);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
