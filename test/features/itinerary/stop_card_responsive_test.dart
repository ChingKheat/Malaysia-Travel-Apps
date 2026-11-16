import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/itinerary/widgets/stop_card.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';
import 'package:smart_travel_planner/shared/models/travel_stop.dart';

void main() {
  const name = 'A very long attraction name that should remain readable on a narrow screen';
  final stop = TravelStop.fromJson({
    'title': name,
    'time': '09:00 - 10:30',
    'note': 'A long address or category that wraps onto additional lines for visitors',
  });
  for (final size in [const Size(320, 640), const Size(360, 800), const Size(393, 852), const Size(430, 932)]) {
    testWidgets('stop content wraps at $size with enlarged text', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(size: size, textScaler: const TextScaler.linear(2)),
          child: Scaffold(body: SingleChildScrollView(child: StopCard(stop: stop, onTap: () {}))),
        ),
      ));
      expect(find.text(name), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
