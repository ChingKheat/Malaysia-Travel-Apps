import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_travel_planner/core/localization/language_controller.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';

Future<void> showLanguageSelector(BuildContext context) async {
  final controller = LanguageScope.of(context);
  final theme = Theme.of(context);
  final sheetColor =
      theme.bottomSheetTheme.modalBackgroundColor ??
      theme.bottomSheetTheme.backgroundColor ??
      (theme.useMaterial3
          ? theme.colorScheme.surfaceContainerLow
          : theme.canvasColor);
  final selected = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: sheetColor,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final strings = AppLocalizations.of(sheetContext);
      final theme = Theme.of(sheetContext);
      final colors = theme.colorScheme;
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          systemNavigationBarColor: sheetColor,
          systemNavigationBarDividerColor: sheetColor,
          systemNavigationBarIconBrightness:
              ThemeData.estimateBrightnessForColor(sheetColor) ==
                  Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.secondaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            Icons.language,
                            color: colors.onSecondaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            strings.appLanguage,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          sheetContext,
                        ).closeButtonTooltip,
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  for (final entry
                      in LanguageController.languageNames.entries) ...[
                    _LanguageOption(
                      code: entry.key,
                      label: entry.value,
                      selected: controller.locale.languageCode == entry.key,
                      onTap: () => Navigator.pop(sheetContext, entry.key),
                    ),
                    if (entry.key != LanguageController.languageNames.keys.last)
                      const SizedBox(height: 8),
                  ],
                ],
              ),
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

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.code,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = selected ? colors.onPrimaryContainer : colors.onSurface;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: selected ? colors.primary : colors.outlineVariant,
      ),
    );

    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainer,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: ValueKey('language-$code'),
        shape: shape,
        minTileHeight: 64,
        minVerticalPadding: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textColor: foreground,
        selectedColor: foreground,
        selected: selected,
        trailing: Icon(
          selected ? Icons.check_circle : Icons.radio_button_unchecked,
          color: selected ? foreground : colors.onSurfaceVariant,
        ),
        onTap: onTap,
      ),
    );
  }
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
