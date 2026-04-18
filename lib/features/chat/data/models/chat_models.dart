class Conversation {
  Conversation({
    required this.id,
    required this.otherUser,
    this.lastMessageText,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  final String id;
  final ConversationUser otherUser;
  final String? lastMessageText;
  final String? lastMessageAt;
  final int unreadCount;

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as String? ?? '',
        otherUser: ConversationUser.fromJson(json['other_user'] as Map<String, dynamic>),
        lastMessageText: json['last_message_text'] as String?,
        lastMessageAt: json['last_message_at'] as String?,
        unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      );
}

class ConversationUser {
  ConversationUser({required this.id, required this.name, this.profilePhoto});
  final String id, name;
  final String? profilePhoto;

  factory ConversationUser.fromJson(Map<String, dynamic> json) => ConversationUser(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        profilePhoto: json['profilePhoto'] as String?,
      );
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id, senderId, body, createdAt;
  final String? readAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String? ?? '',
        senderId: json['sender_id'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
        readAt: json['read_at'] as String?,
      );
}
