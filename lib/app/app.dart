import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/core_providers.dart';
import '../features/auth/presentation/auth_controller.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class ZennoApp extends ConsumerWidget {
  const ZennoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final router = ref.watch(routerProvider);

    // Fetch the backend profile whenever the Firebase user transitions from
    // null -> signed-in. Keeps `currentUserProvider` in sync across cold-start
    // and post-OAuth flows so screens like the dashboard can greet the user
    // without waiting for an explicit fetch.
    ref.listen(authStateChangesProvider, (previous, next) {
      next.whenData((user) {
        if (user != null && (user.emailVerified || _isOAuthUser(user))) {
          ref.read(authControllerProvider.notifier).fetchCurrentUser();
        } else if (user == null) {
          ref.read(currentUserProvider.notifier).state = null;
        }
      });
    });

    return MaterialApp.router(
      title: 'Zenno',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }

  bool _isOAuthUser(User user) {
    return user.providerData.any(
      (p) => p.providerId == 'google.com' || p.providerId == 'github.com',
    );
  }
}
