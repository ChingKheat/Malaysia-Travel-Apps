import 'package:flutter/material.dart';
import 'package:smart_travel_planner/core/localization/language_controller.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';

Future<void> showLanguageSelector(BuildContext context) async {
  final controller = LanguageScope.of(context);
  final selected = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final strings = AppLocalizations.of(sheetContext);
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.appLanguage,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                for (final entry in LanguageController.languageNames.entries)
                  ListTile(
                    key: ValueKey('language-${entry.key}'),
                    minVerticalPadding: 16,
                    title: Text(entry.value),
                    selected: controller.locale.languageCode == entry.key,
                    trailing: controller.locale.languageCode == entry.key
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(sheetContext, entry.key),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
  if (selected == null || selected == controller.locale.languageCode) return;
  final saved = await controller.changeLanguage(selected);
  if (!context.mounted || controller.locale.languageCode != selected) return;
  // Resolve from the chosen locale, even before the next frame rebuilds.
  final strings = lookupAppLocalizations(controller.locale);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          saved ? strings.languageChanged : strings.languageSessionOnly,
        ),
      ),
    );
}

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key, this.foregroundColor});
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: const ValueKey('app-language-button'),
    onPressed: () => showLanguageSelector(context),
    style: TextButton.styleFrom(
      foregroundColor: foregroundColor,
      minimumSize: const Size(48, 48),
    ),
    icon: const Icon(Icons.language),
    label: Text(AppLocalizations.of(context).appLanguage),
  );
}
