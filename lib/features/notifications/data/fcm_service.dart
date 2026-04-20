import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import 'notification_models.dart';
import 'notification_repository.dart';

/// Single, app-wide [NotificationRepository]. Sharing the instance avoids
/// recreating it (and its underlying ApiClient binding) every time a screen
/// opens.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(apiClientProvider));
});

/// First page of the user's notification list — backs the bell badge and
/// the notifications screen. Lives in the data layer (next to the FCM
/// service that invalidates it) so foreground/tap pushes can refresh it
/// without a presentation-layer import cycle.
final notificationsProvider = FutureProvider<
    ({List<NotificationItem> items, int unreadCount, bool hasMore})>((ref) {
  ref.watch(userSessionProvider);
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.fetchNotifications();
});

final unreadCountProvider = FutureProvider<int>((ref) {
  ref.watch(userSessionProvider);
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getUnreadCount();
});

/// Single, app-wide [FcmService]. Hoisting this into Riverpod means:
///   - Only one local-notification channel + token-refresh listener is created.
///   - The same `_currentToken` cache is reused across screens, so logout
///     correctly unregisters the active token (no orphaned device records).
///   - Screens (settings sheet, verify-email, logout flow) can call
///     `requestAndRegister` / `unregister` without re-instantiating the
///     service.
///
/// We pass `ref` into the service so it can invalidate the notification
/// list / unread badge providers whenever a push arrives, instead of
/// waiting for the user to manually pull-to-refresh the bell.
final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService(ref.watch(notificationRepositoryProvider), ref);
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
  FcmService(this._repo, this._ref);

  final NotificationRepository _repo;
  /// Riverpod ref used purely to invalidate the in-app notification list
  /// + unread badge whenever a push is received or tapped. Stored as
  /// `Ref` (not `Reader`) so we don't accidentally hold a BuildContext.
  final Ref _ref;
  final FlutterLocalNotificationsPlugin _localNotifs =
      FlutterLocalNotificationsPlugin();

  String? _currentToken;
  GoRouter? _router;
  bool _tokenRefreshAttached = false;

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
    if (initial != null) {
      _handleTap(initial);
    }

    _ensureTokenRefreshListener();
  }

  /// Firebase may rotate the token; register once so we do not stack listeners
  /// when [requestAndRegister] runs multiple times.
  void _ensureTokenRefreshListener() {
    if (_tokenRefreshAttached) return;
    _tokenRefreshAttached = true;
    FirebaseMessaging.instance.onTokenRefresh.listen(
      (newToken) async {
        if (newToken == _currentToken) return;
        try {
          if (_currentToken != null) {
            await _repo.unregisterToken(_currentToken!).catchError((_) {});
          }
          await _repo.registerToken(newToken);
          _currentToken = newToken;
        } catch (_) {}
      },
    );
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

      _ensureTokenRefreshListener();

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        return FcmRegisterResult.error;
      }
      if (token == _currentToken) {
        return FcmRegisterResult.registered;
      }

      if (_currentToken != null) {
        await _repo.unregisterToken(_currentToken!).catchError((_) {});
      }
      await _repo.registerToken(token);
      _currentToken = token;

      return FcmRegisterResult.registered;
    } catch (_) {
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
    // Always refresh the in-app list + bell badge so the new row appears
    // immediately, regardless of whether we end up displaying a heads-up
    // notification below. The previous implementation only invalidated
    // when the user manually pulled to refresh, so follow-up chat
    // messages never showed up in the notifications screen.
    _refreshNotifProviders();

    // Prefer the rendered `notification` payload, but fall back to the
    // data payload so chat pushes (which include title/body in both
    // blocks since the backend started mirroring them) still ring even
    // if Firebase strips the notification block on some Android variants
    // — Xiaomi/OnePlus/Realme are common offenders for high-priority
    // pushes.
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
    // Tapping a backgrounded/terminated push reveals the app — refresh
    // the bell so the badge reflects reality the moment the user lands.
    _refreshNotifProviders();

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
      case 'test':
        _router!.push('/notifications');
        break;
      default:
        _router!.push('/notifications');
    }
  }

  void _refreshNotifProviders() => refreshNotifProviders();

  /// Force the notifications screen + bell badge to re-fetch from the
  /// API. We `invalidate` (not `refresh`) so we don't trigger a fetch
  /// when nothing is currently watching the providers — they'll re-run
  /// the next time the user opens the screen.
  ///
  /// Public so the chat socket listener in [AppShell] can call it when
  /// a `chat:new_message` event arrives off-thread (the server has
  /// already created the notification row by then; we just need to
  /// invalidate the cached page so the bell + list re-fetch).
  void refreshNotifProviders() {
    try {
      _ref.invalidate(notificationsProvider);
      _ref.invalidate(unreadCountProvider);
    } catch (_) {
      // Defensive: if the container is mid-disposal (logout race) just
      // skip the bump — the next user-session epoch invalidation will
      // recover anyway.
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
      case 'test':
        _router!.push('/notifications');
        break;
      default:
        _router!.push('/notifications');
    }
  }
}
