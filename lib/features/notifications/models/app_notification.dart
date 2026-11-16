enum AppNotificationType { tripReminder, communityComment }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.isRead,
    this.relatedEntityId,
    this.relatedTitle,
    this.relatedDestination,
    this.relatedDate,
    this.commentPreview,
  });

  final String id;
  final AppNotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final String? relatedEntityId;
  final String? relatedTitle;
  final String? relatedDestination;
  final DateTime? relatedDate;
  final String? commentPreview;

  AppNotification copyWith({bool? isRead, DateTime? createdAt}) =>
      AppNotification(
        id: id,
        type: type,
        createdAt: createdAt ?? this.createdAt,
        isRead: isRead ?? this.isRead,
        relatedEntityId: relatedEntityId,
        relatedTitle: relatedTitle,
        relatedDestination: relatedDestination,
        relatedDate: relatedDate,
        commentPreview: commentPreview,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'created_at': createdAt.toIso8601String(),
    'is_read': isRead,
    'related_entity_id': relatedEntityId,
    'related_title': relatedTitle,
    'related_destination': relatedDestination,
    'related_date': relatedDate?.toIso8601String(),
    'comment_preview': commentPreview,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final type = AppNotificationType.values.firstWhere(
      (value) => value.name == json['type'],
    );
    return AppNotification(
      id: json['id'] as String,
      type: type,
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] == true,
      relatedEntityId: json['related_entity_id'] as String?,
      relatedTitle: json['related_title'] as String?,
      relatedDestination: json['related_destination'] as String?,
      relatedDate: DateTime.tryParse(json['related_date'] as String? ?? ''),
      commentPreview: json['comment_preview'] as String?,
    );
  }
}
