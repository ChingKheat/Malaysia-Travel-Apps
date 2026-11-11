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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.history, color: Color(0xFF2563EB)),
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
                  style: const TextStyle(fontWeight: FontWeight.w700),
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
                  ),
                if (!loading && (offline || history?.localOnly == true)) ...[
                  const SizedBox(height: 4),
                  Text(
                    history?.localOnly == true
                        ? context.l10n.timestampSavedOnThisDeviceOnly
                        : context
                              .l10n
                              .showingSavedHistoryCloudHistoryIsUnavailable,
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
