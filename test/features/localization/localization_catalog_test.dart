import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';
import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:smart_travel_planner/l10n/presentation_formatters.dart';
import 'package:smart_travel_planner/features/itinerary/models/saved_trip.dart';

void main() {
  test('every message and placeholder is present in all three catalogs', () {
    final catalogs = ['en', 'ms', 'zh']
        .map(
          (code) =>
              jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
                  as Map<String, dynamic>,
        )
        .toList();
    final keys = catalogs.first.keys
        .where((key) => !key.startsWith('@'))
        .toSet();
    for (final catalog in catalogs) {
      expect(catalog.keys.where((key) => !key.startsWith('@')).toSet(), keys);
      for (final key in keys) {
        expect((catalog[key] as String).trim(), isNotEmpty, reason: key);
        final placeholders = RegExp(r'\{(arg\d+)\}');
        expect(
          placeholders.allMatches(catalog[key]).map((m) => m[1]).toSet(),
          placeholders.allMatches(catalogs.first[key]).map((m) => m[1]).toSet(),
          reason: key,
        );
      }
    }
  });

  testWidgets('formatting preserves user titles and localizes typed metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            const saved = SavedTrip(
              title: 'Save',
              date: '',
              detail: '',
              destination: 'Kuala Lumpur',
              budget: 'Medium',
              interests: [],
            );
            expect(
              context.tripTitle(saved),
              'Save',
            ); // User text is never translated.
            expect(context.tr('Medium'), '中');
            expect(context.money(1234.5), contains('RM'));
            expect(context.money(1234.5), contains('1,234.50'));
            expect(context.localDate(DateTime(2026, 11, 11)), contains('2026'));
            expect(
              context.localDate(DateTime(2026, 11, 11)),
              isNot(contains('Nov')),
            );
            expect(
              context.itineraryWarnings(
                'Travel times are distance-based estimates. Some opening hours are unverified. Confirm before visiting.',
              ),
              '交通时间为基于距离的估算。 部分营业时间尚未核实，请在到访前确认。',
            );
            expect(context.tr('Day 2'), '第 2 天');
            expect(context.tr('Batu Caves'), 'Batu Caves');
            return const SizedBox();
          },
        ),
      ),
    );
  });
}
