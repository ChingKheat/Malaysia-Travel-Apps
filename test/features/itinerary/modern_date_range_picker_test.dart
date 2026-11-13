import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:smart_travel_planner/features/itinerary/widgets/modern_date_range_picker.dart';

void main() {
  group('ModernDateRangePicker Unit & Widget Tests', () {
    testWidgets('Renders all Modern Minimal Travel components correctly in English with close button', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final initialRange = DateTimeRange(
        start: DateTime(2026, 11, 20),
        end: DateTime(2026, 11, 24),
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('zh'), Locale('ms')],
          home: Scaffold(
            body: ModernDateRangePicker(
              initialDateRange: initialRange,
              firstDate: DateTime(2026, 11, 1),
              lastDate: DateTime(2027, 12, 31),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header: App title and clean close button (no redundant step counter or progress bars by default)
      expect(find.text('Wander Malaysia'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.text("When's your adventure?"), findsOneWidget);
      expect(find.text('Pick the dates that work for your trip.'), findsOneWidget);

      // Start & End Cards
      expect(find.text('START DATE'), findsOneWidget);
      expect(find.text('END DATE'), findsOneWidget);
      expect(find.text(DateFormat.yMMMd('en').format(initialRange.start)), findsOneWidget);
      expect(find.text(DateFormat.yMMMd('en').format(initialRange.end)), findsOneWidget);

      // Calendar Navigation & Weekdays
      expect(find.text('November 2026'), findsOneWidget);
      for (final letter in ['M', 'T', 'W', 'F', 'S']) {
        expect(find.text(letter), findsWidgets);
      }

      // Legend & Reset
      expect(find.text('Selected dates'), findsOneWidget);
      expect(find.text('Travel period'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);

      // Duration Card
      expect(find.text('Your trip duration'), findsOneWidget);
      expect(find.text('5 days · 4 nights'), findsOneWidget);

      // Sticky Button
      expect(find.text('Confirm travel dates'), findsOneWidget);
      expect(find.text('You can change your dates anytime.'), findsOneWidget);
    });

    testWidgets('Renders natural, non-repetitive Chinese localization without redundant step/progress clutter', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final initialRange = DateTimeRange(
        start: DateTime(2026, 11, 20),
        end: DateTime(2026, 11, 24),
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('zh'), Locale('ms')],
          home: Scaffold(
            body: ModernDateRangePicker(
              initialDateRange: initialRange,
              firstDate: DateTime(2026, 11, 1),
              lastDate: DateTime(2027, 12, 31),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header & Close button
      expect(find.text('探索马来西亚'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.text('步骤 02 / 04'), findsNothing);

      // Title & Subtitle: Natural headline and informative subtitle
      expect(find.text('什么时候出发？'), findsOneWidget);
      expect(find.text('挑选适合您行程的出发与返程日期。'), findsOneWidget);
      expect(find.text('请选择旅行日期。'), findsNothing);

      // Start & End Cards
      expect(find.text('出发日期'), findsOneWidget);
      expect(find.text('返程日期'), findsOneWidget);

      // Weekdays
      for (final letter in ['一', '二', '三', '四', '五', '六', '日']) {
        expect(find.text(letter), findsWidgets);
      }

      // Legend & Reset
      expect(find.text('选中日期'), findsOneWidget);
      expect(find.text('行程时段'), findsOneWidget);
      expect(find.text('重置'), findsOneWidget);

      // Duration & Confirmation
      expect(find.text('您的行程时长'), findsOneWidget);
      expect(find.text('5 天 · 4 晚'), findsOneWidget);
      expect(find.text('确认旅行日期'), findsOneWidget);
      expect(find.text('您可以随时修改旅行日期。'), findsOneWidget);
    });

    testWidgets('Close button triggers onCancel callback', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernDateRangePicker(
              onCancel: () => cancelled = true,
              firstDate: DateTime(2026, 11, 1),
              lastDate: DateTime(2026, 11, 30),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(cancelled, isTrue);
    });

    testWidgets('Calculates days and nights correctly and triggers confirmation callback', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      DateTimeRange? selectedRange;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernDateRangePicker(
              firstDate: DateTime(2026, 11, 1),
              lastDate: DateTime(2026, 11, 30),
              onDateRangeSelected: (range) {
                selectedRange = range;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially empty: CTA disabled
      expect(find.text('Select travel dates'), findsOneWidget);
      expect(find.text('Select your travel dates'), findsOneWidget);

      // Tap Nov 10
      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();

      expect(find.text('Departure selected · Choose return date'), findsOneWidget);

      // Tap Nov 14
      await tester.tap(find.text('14'));
      await tester.pumpAndSettle();

      // Verify duration: 5 days · 4 nights (10 to 14)
      expect(find.text('5 days · 4 nights'), findsOneWidget);
      expect(find.text('Confirm travel dates'), findsOneWidget);

      // Confirm button tap
      await tester.tap(find.text('Confirm travel dates'));
      await tester.pumpAndSettle();

      expect(selectedRange, isNotNull);
      expect(selectedRange!.start, equals(DateTime(2026, 11, 10)));
      expect(selectedRange!.end, equals(DateTime(2026, 11, 14)));
    });

    testWidgets('Reset button clears selections back to initial state', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final initialRange = DateTimeRange(
        start: DateTime(2026, 11, 20),
        end: DateTime(2026, 11, 24),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernDateRangePicker(
              initialDateRange: initialRange,
              firstDate: DateTime(2026, 11, 1),
              lastDate: DateTime(2026, 11, 30),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('5 days · 4 nights'), findsOneWidget);

      // Tap Reset
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(find.text('Select your travel dates'), findsOneWidget);
      expect(find.text('Select travel dates'), findsOneWidget);
    });

    testWidgets('Disables past dates prior to firstDate', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // First date is Nov 15, so Nov 1 to Nov 14 are past dates
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernDateRangePicker(
              firstDate: DateTime(2026, 11, 15),
              lastDate: DateTime(2026, 11, 30),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap disabled date Nov 10
      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();

      // Nothing selected
      expect(find.text('Select your travel dates'), findsOneWidget);
      expect(find.text('Select travel dates'), findsOneWidget);

      // Tap selectable date Nov 20
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();

      expect(find.text('Departure selected · Choose return date'), findsOneWidget);
    });

    testWidgets('Monthly chevron navigation transitions between months and spans range across months', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      DateTimeRange? confirmedRange;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernDateRangePicker(
              firstDate: DateTime(2026, 11, 1),
              lastDate: DateTime(2027, 2, 28),
              onDateRangeSelected: (range) => confirmedRange = range,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('November 2026'), findsOneWidget);

      // Select start date: Nov 28
      await tester.tap(find.text('28'));
      await tester.pumpAndSettle();

      // Navigate forward to December 2026
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();

      expect(find.text('December 2026'), findsOneWidget);

      // Select end date: Dec 3
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();

      // Duration: Nov 28 to Dec 3 = 6 days · 5 nights
      expect(find.text('6 days · 5 nights'), findsOneWidget);

      // Confirm
      await tester.tap(find.text('Confirm travel dates'));
      await tester.pumpAndSettle();

      expect(confirmedRange, isNotNull);
      expect(confirmedRange!.start, equals(DateTime(2026, 11, 28)));
      expect(confirmedRange!.end, equals(DateTime(2026, 12, 3)));
    });

    testWidgets('Responsive & accessible: fits 320px width at 2.0x text scale without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2.0),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: ModernDateRangePicker(
              initialDateRange: DateTimeRange(
                start: DateTime(2026, 11, 20),
                end: DateTime(2026, 11, 24),
              ),
              firstDate: DateTime(2026, 11, 1),
              lastDate: DateTime(2026, 11, 30),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ModernDateRangePicker), findsOneWidget);
    });

    testWidgets('showModernDateRangePicker returns DateTimeRange when confirmed', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      DateTimeRange? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showModernDateRangePicker(
                      context: context,
                      firstDate: DateTime(2026, 11, 1),
                      lastDate: DateTime(2026, 11, 30),
                      initialDateRange: DateTimeRange(
                        start: DateTime(2026, 11, 20),
                        end: DateTime(2026, 11, 24),
                      ),
                    );
                  },
                  child: const Text('Open Picker'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open bottom sheet
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.byType(ModernDateRangePickerSheet), findsOneWidget);

      // Confirm
      await tester.tap(find.text('Confirm travel dates'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.start, equals(DateTime(2026, 11, 20)));
      expect(result!.end, equals(DateTime(2026, 11, 24)));
    });
  });
}
