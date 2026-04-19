import '../../../core/network/api_client.dart';
import 'notification_models.dart';

class NotificationRepository {
  final ApiClient _api;

  NotificationRepository(this._api);

  Future<({List<NotificationItem> items, int unreadCount, bool hasMore})>
      fetchNotifications({int page = 1}) async {
    final data = await _api.get(
      '/notifications',
      queryParams: {'page': page.toString()},
    );
    final items = ((data['items'] as List?) ?? [])
        .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return (
      items: items,
      unreadCount: (data['unreadCount'] as int?) ?? 0,
      hasMore: (data['hasMore'] as bool?) ?? false,
    );
  }

  Future<int> getUnreadCount() async {
    final data = await _api.get('/notifications/unread-count');
    return (data['count'] as int?) ?? 0;
  }

  Future<void> markRead(String id) async {
    await _api.post('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _api.post('/notifications/read-all');
  }

  Future<NotificationPreferences> getPreferences() async {
    final data = await _api.get('/notifications/preferences');
    return NotificationPreferences.fromJson(
      data['data'] as Map<String, dynamic>,
    );
  }

  Future<NotificationPreferences> updatePreferences(
    Map<String, dynamic> partial,
  ) async {
    final data = await _api.put('/notifications/preferences', data: partial);
    return NotificationPreferences.fromJson(
      data['data'] as Map<String, dynamic>,
    );
  }

  Future<void> registerToken(String token) async {
    await _api.post('/notifications/devices', data: {
      'token': token,
      'platform': 'android',
      'device_label': 'Android Device',
    });
  }

  Future<void> unregisterToken(String token) async {
    await _api.delete('/notifications/devices/$token');
  }

  /// Trigger a real FCM push to every device registered for the
  /// authenticated user. Result includes `pushed`, `deviceCount`,
  /// `successCount`, and an optional `reason` (`push_disabled` /
  /// `no_devices` / `fcm_failed`) so the caller can surface a
  /// targeted message instead of a generic error.
  Future<TestNotificationResult> sendTestNotification() async {
    final data = await _api.post('/notifications/test');
    final body = (data['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    return TestNotificationResult(
      pushed: (body['pushed'] as bool?) ?? false,
      deviceCount: (body['deviceCount'] as int?) ?? 0,
      successCount: (body['successCount'] as int?) ?? 0,
      reason: body['reason'] as String?,
    );
  }
}

class TestNotificationResult {
  const TestNotificationResult({
    required this.pushed,
    required this.deviceCount,
    required this.successCount,
    this.reason,
  });
  final bool pushed;
  final int deviceCount;
  final int successCount;
  final String? reason;
}
