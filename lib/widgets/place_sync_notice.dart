import 'package:flutter/material.dart';
import '../models/place_sync_record.dart';

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
                      ? 'Checking sync history for $state…'
                      : history == null
                      ? '$state — sync time not recorded'
                      : '$state — last synced ${history.ageLabel(now ?? DateTime.now())}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                if (!loading)
                  Text(
                    history == null
                        ? 'Older imports have no recorded date. Check the existing places before syncing again.'
                        : '${history.malaysiaDateLabel}\n${history.placeCount} places found · ${history.requestCount} search requests in that sync.\nReview the existing places before using more API quota.',
                  ),
                if (!loading && (offline || history?.localOnly == true)) ...[
                  const SizedBox(height: 4),
                  Text(
                    history?.localOnly == true
                        ? 'Timestamp saved on this device only.'
                        : 'Showing saved history; cloud history is unavailable.',
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
