import 'dart:io' show Platform;

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
    final String platform;
    final String deviceLabel;
    if (Platform.isIOS) {
      platform = 'ios';
      deviceLabel = 'iOS';
    } else if (Platform.isAndroid) {
      platform = 'android';
      deviceLabel = 'Android';
    } else {
      platform = 'android';
      deviceLabel = 'Mobile';
    }
    await _api.post('/notifications/devices', data: {
      'token': token,
      'platform': platform,
      'device_label': deviceLabel,
    });
  }

  Future<void> unregisterToken(String token) async {
    await _api.delete('/notifications/devices/$token');
  }
}
