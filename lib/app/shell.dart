import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_background.dart';
import '../features/chat/data/chat_socket_service.dart';
import '../features/chat/presentation/conversations_screen.dart';
import '../features/notifications/data/fcm_service.dart';
import 'router.dart';
import 'theme/app_colors.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _tabs = [
    '/dashboard',
    '/chats',
    '/peers',
    '/profile',
    '/agent',
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i])) return i;
    }
    return 0;
  }

  StreamSubscription<NewMessageEvent>? _chatSub;

  @override
  void initState() {
    super.initState();
    _initFcm();
    _initChatSocket();
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    super.dispose();
  }

  Future<void> _initFcm() async {
    try {
      final fcm = ref.read(fcmServiceProvider);
      final router = ref.read(routerProvider);
      await fcm.init(router);
      await fcm.requestAndRegister();
    } catch (_) {}
  }

  /// Connect the chat socket as soon as the authenticated shell mounts
  /// (instead of waiting for the user to open the Chats tab) and listen
  /// for incoming messages app-wide. When a message arrives while the
  /// user is not on its thread we just refresh the bell badge / list —
  /// the per-thread screen still owns its own optimistic append, so
  /// we don't double-render anything.
  ///
  /// This closes the gap where, after a fresh app launch, a peer would
  /// send a message and *no* notification ever showed up because (a) the
  /// chat socket wasn't connected yet and (b) the FCM foreground handler
  /// silently no-op'd on devices that strip the `notification` block.
  Future<void> _initChatSocket() async {
    try {
      final socket = ref.read(chatSocketProvider);
      _chatSub = socket.onNewMessage.listen((event) {
        // The thread screen handles its own incoming messages (and marks
        // them read). For everyone else we just need the bell + list to
        // reflect the new server-side notification row.
        final fcm = ref.read(fcmServiceProvider);
        fcm.refreshNotifProviders();
      });
      await socket.connect();
    } catch (_) {
      // Non-fatal: per-thread screen retries on send; FCM still delivers.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final index = _currentIndex(context);

    // The notification bell used to be a floating overlay positioned over
    // every screen here. That caused two issues:
    //   1. It overlapped each inner Scaffold's AppBar actions (e.g. the
    //      settings cog on the dashboard), looking like a stray pill.
    //   2. Its red dot was hard-coded — it never reflected the unread count.
    // Both screens now use `NotificationBellAction` inside their own AppBar,
    // which integrates cleanly and is driven by `unreadCountProvider`.
    return AppBackground(
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkNavBg : AppColors.lightNavBg,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? const Color(0x1AFFFFFF)
                        : const Color(0x66FFFFFF),
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (i) => context.go(_tabs[i]),
                backgroundColor: Colors.transparent,
                elevation: 0,
                indicatorColor: isDark
                    ? AppColors.primaryStart.withValues(alpha: 0.2)
                    : AppColors.primaryStart.withValues(alpha: 0.12),
                destinations: [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined,
                        color: isDark
                            ? AppColors.darkSecondaryText
                            : AppColors.lightSecondaryText),
                    selectedIcon: const Icon(Icons.dashboard,
                        color: AppColors.primaryStart),
                    label: 'Dashboard',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.chat_bubble_outline,
                        color: isDark
                            ? AppColors.darkSecondaryText
                            : AppColors.lightSecondaryText),
                    selectedIcon: const Icon(Icons.chat_bubble,
                        color: AppColors.primaryStart),
                    label: 'Chats',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.people_outline,
                        color: isDark
                            ? AppColors.darkSecondaryText
                            : AppColors.lightSecondaryText),
                    selectedIcon: const Icon(Icons.people,
                        color: AppColors.primaryStart),
                    label: 'Peers',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline,
                        color: isDark
                            ? AppColors.darkSecondaryText
                            : AppColors.lightSecondaryText),
                    selectedIcon: const Icon(Icons.person,
                        color: AppColors.primaryStart),
                    label: 'Profile',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.smart_toy_outlined,
                        color: isDark
                            ? AppColors.darkSecondaryText
                            : AppColors.lightSecondaryText),
                    selectedIcon: const Icon(Icons.smart_toy,
                        color: AppColors.primaryStart),
                    label: 'Agent',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
