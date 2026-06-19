import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

void demoHaptic() => HapticFeedback.lightImpact();

void showDemoSnackBar(BuildContext context, String message, {IconData? icon}) {
  demoHaptic();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
}

Future<void> showDemoSheet(
  BuildContext context, {
  required String title,
  required String body,
  String actionLabel = 'Got it',
  IconData? icon,
}) {
  demoHaptic();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(color: AppColors.muted, height: 1.45),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: primaryFilledButtonStyle(),
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> runDemoLoadingAction(
  BuildContext context, {
  required String loadingLabel,
  required String successMessage,
  IconData? icon,
  Duration delay = const Duration(milliseconds: 1400),
}) async {
  demoHaptic();
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      content: Row(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              loadingLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );

  await Future.delayed(delay);
  if (!context.mounted) return;
  Navigator.of(context).pop();
  showDemoSnackBar(context, successMessage, icon: icon);
}

ButtonStyle primaryFilledButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(52),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

ButtonStyle demoOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    minimumSize: const Size.fromHeight(52),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    side: const BorderSide(color: AppColors.line),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}
