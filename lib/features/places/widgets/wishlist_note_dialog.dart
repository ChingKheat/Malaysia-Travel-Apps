import 'package:flutter/material.dart';
import 'package:smart_travel_planner/features/image_recognition/widgets/visual_scan_style.dart';
import 'package:smart_travel_planner/l10n/localized_labels.dart';

/// Returns null when the traveller chooses to add a note later.
Future<String?> showWishlistNoteDialog(
  BuildContext context, {
  required String placeName,
  String? initialNote,
}) async {
  final controller = TextEditingController(text: initialNote);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: VisualScanStyle.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        context.l10n.scanWishlistAddNote,
        style: VisualScanStyle.heading(20),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(placeName, style: const TextStyle(color: VisualScanStyle.muted)),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            maxLength: 200,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: context.l10n.scanWishlistNoteHint,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(context.l10n.decideLater),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: Text(context.l10n.save),
        ),
      ],
    ),
  );
}
