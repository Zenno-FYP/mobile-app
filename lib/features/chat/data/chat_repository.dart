import '../../../core/network/api_client.dart';
import 'models/chat_models.dart';

class ChatRepository {
  ChatRepository(this._client);
  final ApiClient _client;

  Future<List<Conversation>> getConversations() async {
    final data = await _client.get('/chat/conversations');
    final list = data['conversations'] as List? ?? [];
    return list.map((e) => Conversation.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<String> createConversation(String userId) async {
    final data = await _client.post('/chat/conversations/with-user', data: {'userId': userId});
    return data['conversation_id'] as String;
  }

  Future<List<ChatMessage>> getMessages(String conversationId, {String? before, int limit = 30}) async {
    final params = <String, dynamic>{'limit': limit};
    if (before != null) params['before'] = before;
    final data = await _client.get('/chat/conversations/$conversationId/messages', queryParams: params);
    final list = data['messages'] as List? ?? [];
    return list.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> markRead(String conversationId) async {
    await _client.post('/chat/conversations/$conversationId/read');
  }

  /// Submits a moderation report for this conversation (same contract as the website).
  Future<void> reportConversation(String conversationId, {String? reason}) async {
    final t = reason?.trim();
    final data = (t == null || t.isEmpty) ? <String, dynamic>{} : <String, dynamic>{'reason': t};
    await _client.post('/chat/conversations/$conversationId/report', data: data);
  }

  /// Fetches the conversation summary for a single conversation by reusing the
  /// inbox endpoint. The chat REST API does not currently expose a single-
  /// conversation lookup, but the inbox is small and lets us recover the
  /// `otherUser` info needed to send messages.
  Future<Conversation?> findConversation(String conversationId) async {
    final all = await getConversations();
    for (final c in all) {
      if (c.id == conversationId) return c;
    }
    return null;
  }
}
