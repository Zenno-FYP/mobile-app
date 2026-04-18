import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/core_providers.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/verify_email_screen.dart';
import 'shell.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/chat/data/models/chat_models.dart';
import '../features/chat/presentation/conversations_screen.dart';
import '../features/chat/presentation/thread_screen.dart';
import '../features/peers/presentation/peers_screen.dart';
import '../features/peers/presentation/public_profile_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/profile/presentation/edit_profile_screen.dart';
import '../features/agent/presentation/agent_screen.dart';
import '../features/analytics/presentation/metrics_detail_screen.dart';
import '../features/analytics/presentation/apps_languages_screen.dart';
import '../features/analytics/presentation/skills_projects_screen.dart';
import '../features/projects/presentation/project_detail_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final authRefresh = _GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges());
  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    refreshListenable: authRefresh,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final onboardingSeen = prefs.getBool('onboarding_seen') ?? false;
      final user = FirebaseAuth.instance.currentUser;
      final path = state.matchedLocation;

      if (!onboardingSeen && path != '/onboarding') {
        return '/onboarding';
      }

      final isAuthRoute = path == '/auth' || path == '/onboarding';
      final isVerifyRoute = path == '/verify-email';

      if (onboardingSeen && user == null && !isAuthRoute) {
        return '/auth';
      }

      if (user != null && !user.emailVerified && !isVerifyRoute && !isAuthRoute) {
        // Allow OAuth users who may not have email verification
        final isOAuth = user.providerData.any(
          (p) => p.providerId == 'google.com' || p.providerId == 'github.com',
        );
        if (!isOAuth) return '/verify-email';
      }

      if (user != null && isAuthRoute) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/chats',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ConversationsScreen(),
            ),
            routes: [
              GoRoute(
                path: ':conversationId',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => ThreadScreen(
                  conversationId: state.pathParameters['conversationId']!,
                  otherUser: state.extra is ConversationUser
                      ? state.extra as ConversationUser
                      : null,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/peers',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PeersScreen(),
            ),
            routes: [
              GoRoute(
                path: ':userId/profile',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => PublicProfileScreen(
                  userId: state.pathParameters['userId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
            routes: [
              GoRoute(
                path: 'edit',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const EditProfileScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/agent',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AgentScreen(),
            ),
          ),
          GoRoute(
            path: '/analytics/metrics',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const MetricsDetailScreen(),
          ),
          GoRoute(
            path: '/analytics/apps-languages',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const AppsLanguagesScreen(),
          ),
          GoRoute(
            path: '/analytics/skills-projects',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const SkillsProjectsScreen(),
          ),
          GoRoute(
            path: '/projects/:projectName',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => ProjectDetailScreen(
              projectName: state.pathParameters['projectName']!,
            ),
          ),
          GoRoute(
            path: '/notifications',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const NotificationsScreen(),
          ),
        ],
      ),
    ],
  );
});

/// Bridges any [Stream] into a [Listenable] so GoRouter can react to it via
/// `refreshListenable` without us having to hand-roll a notifier.
class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
