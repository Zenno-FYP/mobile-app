import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/core_providers.dart';
import '../core/widgets/app_background.dart';
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

/// Subtle fade + tiny scale-up transition for deep-link / detail screens.
///
/// We intentionally avoid the default platform slide here so push/pop feels
/// closer to a native modal-into-detail and lets [Hero] tags blend in.
/// `MediaQuery.disableAnimationsOf(context)` is honoured so users with
/// reduced-motion accessibility settings still get an instant transition.
///
/// The child is wrapped in [AppBackground] because every screen using this
/// helper is pushed at the root navigator level (above the [AppShell]) and
/// therefore does NOT inherit the shell's gradient/orb background. The app's
/// theme sets `scaffoldBackgroundColor: Colors.transparent`, so without this
/// wrapper the screen would appear over the platform window default — which
/// is solid black in light mode and makes glass cards nearly invisible in
/// dark mode.
CustomTransitionPage<T> _fadeScalePage<T>({
  required GoRouterState state,
  required Widget child,
}) {
  final wrapped = AppBackground(child: child);
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: wrapped,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (context, animation, _, page) {
      if (MediaQuery.disableAnimationsOf(context)) {
        return page;
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.985, end: 1.0).animate(curved),
          child: page,
        ),
      );
    },
  );
}

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

      // For password (non-OAuth) users with an unverified email, force them to
      // the verification screen. This must take precedence over the
      // "isAuthRoute -> /dashboard" rule below to avoid a one-tick flash of the
      // dashboard during the redirect chain.
      final needsVerification = user != null &&
          !user.emailVerified &&
          user.providerData.every((p) => p.providerId == 'password');

      if (needsVerification && !isVerifyRoute) {
        return '/verify-email';
      }

      if (user != null && !needsVerification && isAuthRoute) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      // Standalone routes (no bottom nav)
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

      // Full-screen routes that push above the shell (no bottom nav).
      // These live at the root navigator level on purpose; defining them as
      // direct children of the ShellRoute with parentNavigatorKey =
      // _rootNavigatorKey is not allowed by go_router.
      GoRoute(
        path: '/analytics/metrics',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeScalePage(state: state, child: const MetricsDetailScreen()),
      ),
      GoRoute(
        path: '/analytics/apps-languages',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeScalePage(state: state, child: const AppsLanguagesScreen()),
      ),
      GoRoute(
        path: '/analytics/skills-projects',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeScalePage(state: state, child: const SkillsProjectsScreen()),
      ),
      GoRoute(
        path: '/projects/:projectName',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadeScalePage(
          state: state,
          child: ProjectDetailScreen(
            projectName: state.pathParameters['projectName']!,
          ),
        ),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeScalePage(state: state, child: const NotificationsScreen()),
      ),

      // Bottom-nav shell routes
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
              // Nested sub-route - allowed to escape to root navigator
              // because it isn't a direct child of the ShellRoute.
              GoRoute(
                path: ':conversationId',
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (context, state) => _fadeScalePage(
                  state: state,
                  child: ThreadScreen(
                    conversationId: state.pathParameters['conversationId']!,
                    otherUser: state.extra is ConversationUser
                        ? state.extra as ConversationUser
                        : null,
                  ),
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
                pageBuilder: (context, state) => _fadeScalePage(
                  state: state,
                  child: PublicProfileScreen(
                    userId: state.pathParameters['userId']!,
                  ),
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
                pageBuilder: (context, state) =>
                    _fadeScalePage(state: state, child: const EditProfileScreen()),
              ),
            ],
          ),
          GoRoute(
            path: '/agent',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AgentScreen(),
            ),
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
