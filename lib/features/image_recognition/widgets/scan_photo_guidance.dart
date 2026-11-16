import 'package:flutter/material.dart';
import 'package:smart_travel_planner/features/image_recognition/widgets/visual_scan_style.dart';
import 'package:smart_travel_planner/l10n/localized_labels.dart';

class ScanPhotoGuidance extends StatelessWidget {
  const ScanPhotoGuidance({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.scanPhotoTips, style: VisualScanStyle.heading(19)),
        for (final (icon, title, detail) in [
          (Icons.wb_sunny_outlined, l10n.scanTipLight, l10n.scanTipLightDetail),
          (
            Icons.center_focus_strong,
            l10n.scanTipFrame,
            l10n.scanTipFrameDetail,
          ),
          (Icons.signpost_outlined, l10n.scanTipSign, l10n.scanTipSignDetail),
        ])
          Padding(
            padding: const EdgeInsets.only(top: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: VisualScanStyle.amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: VisualScanStyle.heading(15)),
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        style: const TextStyle(
                          color: VisualScanStyle.muted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
