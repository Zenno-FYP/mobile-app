class NotificationItem {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final Map<String, String> data;
  final String? readAt;
  final String? pushSentAt;
  final String createdAt;

  const NotificationItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    this.readAt,
    this.pushSentAt,
    required this.createdAt,
  });

  bool get isUnread => readAt == null;

  NotificationItem copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? body,
    Map<String, String>? data,
    String? readAt,
    String? pushSentAt,
    String? createdAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      readAt: readAt ?? this.readAt,
      pushSentAt: pushSentAt ?? this.pushSentAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      data: (json['data'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          {},
      readAt: json['read_at'] as String?,
      pushSentAt: json['push_sent_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class NotificationPreferences {
  final bool pushEnabled;
  final bool chatEnabled;
  final bool newProjectEnabled;
  final bool dailyDigestEnabled;

  const NotificationPreferences({
    this.pushEnabled = true,
    this.chatEnabled = true,
    this.newProjectEnabled = true,
    this.dailyDigestEnabled = true,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      pushEnabled: json['push_enabled'] as bool? ?? true,
      chatEnabled: json['chat_enabled'] as bool? ?? true,
      newProjectEnabled: json['new_project_enabled'] as bool? ?? true,
      dailyDigestEnabled: json['daily_digest_enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'push_enabled': pushEnabled,
        'chat_enabled': chatEnabled,
        'new_project_enabled': newProjectEnabled,
        'daily_digest_enabled': dailyDigestEnabled,
      };

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? chatEnabled,
    bool? newProjectEnabled,
    bool? dailyDigestEnabled,
  }) {
    return NotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      chatEnabled: chatEnabled ?? this.chatEnabled,
      newProjectEnabled: newProjectEnabled ?? this.newProjectEnabled,
      dailyDigestEnabled: dailyDigestEnabled ?? this.dailyDigestEnabled,
    );
  }
}
