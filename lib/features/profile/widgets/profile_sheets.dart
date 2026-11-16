import 'package:flutter/material.dart';
import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/core/theme/app_decorations.dart';
import 'package:smart_travel_planner/features/auth/models/travel_preferences.dart';
import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';
import 'package:smart_travel_planner/features/profile/services/profile_preferences_service.dart';
import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:url_launcher/url_launcher.dart';

String profilePaceLabel(BuildContext context, PaceCategory value) =>
    switch (value) {
      PaceCategory.relaxed => context.l10n.relaxed,
      PaceCategory.balanced => context.l10n.profileModerate,
      PaceCategory.packed => context.l10n.profileFastPaced,
    };

String profileBudgetLabel(BuildContext context, BudgetTier value) =>
    switch (value) {
      BudgetTier.budget => context.l10n.profileBudget,
      BudgetTier.standard => context.l10n.standard,
      BudgetTier.luxury => context.l10n.profileLuxury,
    };

String profileDietLabel(BuildContext context, DietaryPreference value) =>
    switch (value) {
      DietaryPreference.halalFriendly => context.l10n.profileHalal,
      DietaryPreference.vegetarian => context.l10n.profileVegetarian,
      _ => context.l10n.profileNone,
    };

Future<T?> showProfileSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder body,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: AppColors.nightSurface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          body(context),
        ],
      ),
    ),
  ),
);

class TravelPreferencesEditor extends StatefulWidget {
  const TravelPreferencesEditor({
    super.key,
    required this.initial,
    required this.onSave,
  });

  final TravelPreferences initial;
  final Future<bool> Function(TravelPreferences) onSave;

  @override
  State<TravelPreferencesEditor> createState() =>
      _TravelPreferencesEditorState();
}

class _TravelPreferencesEditorState extends State<TravelPreferencesEditor> {
  late var _pace = widget.initial.pace;
  late var _budget = widget.initial.budget;
  late var _diet = widget.initial.diet;
  bool _saving = false;
  bool _failed = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    final saved = await widget.onSave(
      TravelPreferences(pace: _pace, budget: _budget, diet: _diet),
    );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  Widget _choices<T>(
    String title,
    Iterable<T> values,
    T current,
    String Function(T) label,
    ValueChanged<T> onSelected,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final value in values)
              ChoiceChip(
                materialTapTargetSize: MaterialTapTargetSize.padded,
                label: Text(label(value)),
                selected: current == value,
                selectedColor: AppColors.primary,
                labelStyle: current == value
                    ? const TextStyle(color: AppColors.nightSurface)
                    : null,
                checkmarkColor: AppColors.nightSurface,
                onSelected: _saving ? null : (_) => onSelected(value),
              ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !_saving,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _choices(
            l10n.profilePace,
            PaceCategory.values,
            _pace,
            (value) => profilePaceLabel(context, value),
            (value) => setState(() => _pace = value),
          ),
          _choices(
            l10n.profileBudgetTier,
            BudgetTier.values,
            _budget,
            (value) => profileBudgetLabel(context, value),
            (value) => setState(() => _budget = value),
          ),
          _choices(
            l10n.profileDiet,
            const [
              DietaryPreference.unrestricted,
              DietaryPreference.halalFriendly,
              DietaryPreference.vegetarian,
            ],
            _diet,
            (value) => profileDietLabel(context, value),
            (value) => setState(() => _diet = value),
          ),
          if (_failed)
            Text(
              l10n.profileSaveFailed,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.save),
          ),
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }
}

Future<PreferredCurrency?> showCurrencySheet(
  BuildContext context,
  PreferredCurrency current,
) => showProfileSheet<PreferredCurrency>(
  context,
  title: context.l10n.profileCurrency,
  body: (context) => Column(
    children: [
      for (final currency in PreferredCurrency.values)
        ListTile(
          selected: currency == current,
          selectedColor: AppColors.primary,
          leading: Icon(
            currency == current
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
          ),
          title: Text(currency.label),
          subtitle: Text(switch (currency) {
            PreferredCurrency.myr => context.l10n.profileMyr,
            PreferredCurrency.sgd => context.l10n.profileSgd,
            PreferredCurrency.usd => context.l10n.profileUsd,
            PreferredCurrency.cny => context.l10n.profileCny,
            PreferredCurrency.eur => context.l10n.profileEur,
          }),
          onTap: () => Navigator.pop(context, currency),
        ),
    ],
  ),
);

Future<void> showEmergencyHotlines(BuildContext context) async {
  String? failedNumber;
  var openingDialer = false;
  await showProfileSheet<void>(
    context,
    title: context.l10n.profileHotlines,
    body: (context) {
      final l10n = context.l10n;
      final contacts = [
        (
          Icons.emergency_outlined,
          l10n.profilePoliceAmbulance,
          '999',
          '999',
          l10n.profilePoliceAmbulanceInfo,
        ),
        (
          Icons.phone_android,
          l10n.profileMobileEmergency,
          '112',
          '112',
          l10n.profileMobileEmergencyInfo,
        ),
        // MOTAC's MaTiC station announcement, 7 October 2023.
        (
          Icons.local_police_outlined,
          l10n.profileTouristPolice,
          '03-9235 4999',
          '+60392354999',
          l10n.profileTouristPoliceInfo,
        ),
      ];
      return StatefulBuilder(
        builder: (context, setSheetState) => Column(
          children: [
            for (final (icon, title, displayNumber, number, description)
                in contacts)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: cardDecoration(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        displayNumber,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(description),
                      TextButton.icon(
                        onPressed: openingDialer
                            ? null
                            : () async {
                                setSheetState(() {
                                  openingDialer = true;
                                  failedNumber = null;
                                });
                                final opened = await _openDialer(number);
                                if (!context.mounted) return;
                                setSheetState(() {
                                  openingDialer = false;
                                  failedNumber = opened ? null : number;
                                });
                              },
                        icon: const Icon(Icons.call_outlined),
                        label: Text(l10n.profileCall),
                      ),
                      if (failedNumber == number)
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            l10n.profileDialerError,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

Future<bool> _openDialer(String number) async {
  try {
    return await launchUrl(
      Uri(scheme: 'tel', path: number),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}
