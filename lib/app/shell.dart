import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_background.dart';
import 'theme/app_colors.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final index = _currentIndex(context);

    return AppBackground(
      child: Scaffold(
        body: child,
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
                        color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                    selectedIcon: const Icon(Icons.dashboard, color: AppColors.primaryStart),
                    label: 'Dashboard',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.chat_bubble_outline,
                        color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                    selectedIcon: const Icon(Icons.chat_bubble, color: AppColors.primaryStart),
                    label: 'Chats',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.people_outline,
                        color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                    selectedIcon: const Icon(Icons.people, color: AppColors.primaryStart),
                    label: 'Peers',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline,
                        color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                    selectedIcon: const Icon(Icons.person, color: AppColors.primaryStart),
                    label: 'Profile',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.smart_toy_outlined,
                        color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                    selectedIcon: const Icon(Icons.smart_toy, color: AppColors.primaryStart),
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
