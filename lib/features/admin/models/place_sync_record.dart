class PlaceSyncRecord {
  const PlaceSyncRecord({
    required this.state,
    required this.lastSyncedAt,
    required this.placeCount,
    required this.requestCount,
    this.localOnly = false,
  });

  final String state;
  final DateTime lastSyncedAt;
  final int placeCount;
  final int requestCount;
  final bool localOnly;

  factory PlaceSyncRecord.fromJson(Map<String, dynamic> data) =>
      PlaceSyncRecord(
        state: data['state'] as String,
        lastSyncedAt: DateTime.parse(data['last_synced_at'] as String).toUtc(),
        placeCount: (data['place_count'] as num).toInt(),
        requestCount: (data['request_count'] as num).toInt(),
        localOnly: data['local_only'] == true,
      );

  Map<String, dynamic> toJson() => {
    'state': state,
    'last_synced_at': lastSyncedAt.toUtc().toIso8601String(),
    'place_count': placeCount,
    'request_count': requestCount,
    'local_only': localOnly,
  };

  String ageLabel(DateTime now) {
    final elapsed = now.toUtc().difference(lastSyncedAt.toUtc());
    if (elapsed.inMinutes < 1) return 'just now';
    if (elapsed.inHours < 1) {
      return '${elapsed.inMinutes} ${elapsed.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    }
    if (elapsed.inDays < 1) {
      return '${elapsed.inHours} ${elapsed.inHours == 1 ? 'hour' : 'hours'} ago';
    }
    return '${elapsed.inDays} ${elapsed.inDays == 1 ? 'day' : 'days'} ago';
  }

  String get malaysiaDateLabel {
    final date = lastSyncedAt.toUtc().add(const Duration(hours: 8));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)} MYT';
  }
}
