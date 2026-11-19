import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';
import 'package:smart_travel_planner/features/admin/models/place_sync_record.dart';

class PlaceSyncNotice extends StatelessWidget {
  const PlaceSyncNotice({
    super.key,
    required this.state,
    required this.record,
    this.loading = false,
    this.offline = false,
    this.now,
  });
  final String state;
  final PlaceSyncRecord? record;
  final bool loading;
  final bool offline;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final history = record;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDark
        ? const Color(0xFF161F2E)
        : const Color(0xFFEFF6FF);
    final borderColor = isDark
        ? const Color(0xFF263750)
        : const Color(0xFFBFDBFE);
    final iconColor = isDark
        ? const Color(0xFF60A5FA)
        : const Color(0xFF2563EB);
    final titleColor = isDark
        ? AppColors.nightBody
        : const Color(0xFF1E3A8A);
    final bodyColor = isDark
        ? AppColors.nightMuted
        : const Color(0xFF1E40AF);
    final noteColor = isDark
        ? AppColors.nightMuted.withValues(alpha: 0.8)
        : const Color(0xFF3B82F6);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.history, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loading
                      ? context.l10n.checkingSyncHistoryForValue(
                          (state).toString(),
                        )
                      : history == null
                      ? context.l10n.valueSyncTimeNotRecorded(
                          (state).toString(),
                        )
                      : context.l10n.valueLastSyncedValue(
                          (state).toString(),
                          (history.ageLabel(now ?? DateTime.now())).toString(),
                        ),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                if (!loading)
                  Text(
                    history == null
                        ? context
                              .l10n
                              .olderImportsHaveNoRecordedDateCheckTheExistingPlacesBeforeSyncingAgain
                        : context.l10n
                              .valueValuePlacesFoundValueSearchRequestsInThatSyncReviewTheExistingPlacesBeforeUsingMoreAp(
                                (history.malaysiaDateLabel).toString(),
                                (history.placeCount).toString(),
                                (history.requestCount).toString(),
                              ),
                    style: TextStyle(
                      color: bodyColor,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                if (!loading && (offline || history?.localOnly == true)) ...[
                  const SizedBox(height: 4),
                  Text(
                    history?.localOnly == true
                        ? context.l10n.timestampSavedOnThisDeviceOnly
                        : context
                              .l10n
                              .showingSavedHistoryCloudHistoryIsUnavailable,
                    style: TextStyle(
                      color: noteColor,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
