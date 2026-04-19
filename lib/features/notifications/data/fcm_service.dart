import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/auth_controller.dart';
import 'notification_repository.dart';

/// Single, app-wide [NotificationRepository]. Sharing the instance avoids
/// recreating it (and its underlying ApiClient binding) every time a screen
/// opens.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(apiClientProvider));
});

/// Single, app-wide [FcmService]. Hoisting this into Riverpod means:
///   - Only one local-notification channel + token-refresh listener is created.
///   - The same `_currentToken` cache is reused across screens, so logout
///     correctly unregisters the active token (no orphaned device records).
///   - Screens (settings sheet, verify-email, logout flow) can call
///     `requestAndRegister` / `unregister` without re-instantiating the
///     service.
final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService(ref.watch(notificationRepositoryProvider));
});

/// Outcome of an [FcmService.requestAndRegister] call.
enum FcmRegisterResult {
  /// Permission granted and the FCM token was registered with the backend.
  registered,

  /// User denied (or hasn't yet granted) the system notification permission.
  /// On Android 13+ this is the POST_NOTIFICATIONS runtime permission.
  permissionDenied,

  /// An unexpected error happened (network, plugin, etc.).
  error,
}

class FcmService {
  FcmService(this._repo);

  final NotificationRepository _repo;
  final FlutterLocalNotificationsPlugin _localNotifs =
      FlutterLocalNotificationsPlugin();

  String? _currentToken;
  GoRouter? _router;

  /// Channel that *every* push (chat, project, digest) is delivered on.
  ///
  /// `Importance.max` (vs `high`) gives a heads-up notification + sound +
  /// vibration on Android 8+. We also set `playSound`, `enableVibration`
  /// and `showBadge` explicitly so OEM skins that ship odd defaults
  /// (Xiaomi, OnePlus, Realme) still ring on the first install.
  ///
  /// The channel id is referenced from `AndroidManifest.xml` via
  /// `com.google.firebase.messaging.default_notification_channel_id`, so
  /// background / terminated FCM payloads land on the same channel as
  /// foreground ones — no silent fallback.
  static const _androidChannel = AndroidNotificationChannel(
    'zenno_notifications',
    'Zenno Notifications',
    description: 'Chats, project updates, and daily digests from Zenno.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  Future<void> init(GoRouter router) async {
    _router = router;

    // Android local notifications setup
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifs.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: _onLocalNotifTap,
    );

    if (Platform.isAndroid) {
      await _localNotifs
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }

    // FCM foreground messages
    FirebaseMessaging.onMessage.listen(_handleForeground);

    // Background tap (app was in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // Terminated tap (app was killed)
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleTap(initial);
  }

  /// Result of [requestAndRegister].
  ///
  /// Distinguishes the "permission denied" case (Android 13+
  /// POST_NOTIFICATIONS / iOS notification settings) from generic failures so
  /// callers can surface a friendly message and a "Go to settings" affordance
  /// instead of silently failing.
  Future<FcmRegisterResult> requestAndRegister() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      switch (settings.authorizationStatus) {
        case AuthorizationStatus.denied:
          return FcmRegisterResult.permissionDenied;
        case AuthorizationStatus.notDetermined:
          // User dismissed the system prompt without choosing.
          return FcmRegisterResult.permissionDenied;
        case AuthorizationStatus.authorized:
        case AuthorizationStatus.provisional:
          break;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token != _currentToken) {
        if (_currentToken != null) {
          await _repo.unregisterToken(_currentToken!).catchError((_) {});
        }
        await _repo.registerToken(token);
        _currentToken = token;
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        if (newToken != _currentToken) {
          if (_currentToken != null) {
            await _repo.unregisterToken(_currentToken!).catchError((_) {});
          }
          await _repo.registerToken(newToken);
          _currentToken = newToken;
        }
      });

      return FcmRegisterResult.registered;
    } catch (e) {
      debugPrint('[FCM] requestAndRegister failed: $e');
      return FcmRegisterResult.error;
    }
  }

  Future<void> unregister() async {
    if (_currentToken != null) {
      await _repo.unregisterToken(_currentToken!).catchError((_) {});
      _currentToken = null;
    }
  }

  void _handleForeground(RemoteMessage message) {
    // Prefer the rendered `notification` payload, but fall back to the
    // data payload so chat pushes (which always include title/body in
    // both blocks) still ring even if Firebase strips the notification
    // block on some Android variants.
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] as String?;
    final body = notification?.body ?? message.data['body'] as String?;
    if (title == null && body == null) return;

    _localNotifs.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          ticker: title,
          icon: '@mipmap/ic_launcher',
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.public,
        ),
      ),
      payload: message.data['type'] ?? '',
    );
  }

  void _handleTap(RemoteMessage message) {
    final type = message.data['type'];
    if (_router == null) return;

    switch (type) {
      case 'chat_message':
        final convId = message.data['conversationId'];
        if (convId != null) {
          _router!.push('/chats/$convId');
        } else {
          _router!.go('/chats');
        }
        break;
      case 'new_project':
        final projectName = message.data['projectName'];
        if (projectName != null && projectName.isNotEmpty) {
          _router!.push('/projects/$projectName');
        } else {
          _router!.go('/dashboard');
        }
        break;
      case 'daily_digest':
        _router!.go('/dashboard');
        break;
      default:
        _router!.push('/notifications');
    }
  }

  void _onLocalNotifTap(NotificationResponse response) {
    final type = response.payload;
    if (_router == null || type == null) return;

    switch (type) {
      case 'chat_message':
        _router!.go('/chats');
        break;
      case 'new_project':
      case 'daily_digest':
        _router!.go('/dashboard');
        break;
      default:
        _router!.push('/notifications');
    }
  }
}
