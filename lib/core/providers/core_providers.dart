import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override in ProviderScope');
});

/// Monotonically-incrementing "user session epoch".
///
/// Every user-scoped data provider should `ref.watch(userSessionProvider)`
/// at the top of its create function. When the user logs out (or is force-
/// logged-out by [AuthInterceptor]) we bump this counter via
/// [clearUserScopedSession]; every provider watching it is then auto-
/// invalidated by Riverpod, dropping cached results, closing sockets via
/// `ref.onDispose`, and forcing a fresh fetch on next read.
///
/// This avoids the bug where stale data from the previous user (profile,
/// dashboard, chats, peer search, agent prefs, notifications) would briefly
/// flash on screen for the next account that signs in on the same device.
final userSessionProvider = StateProvider<int>((ref) => 0);

/// Tear down all user-scoped state in one shot.
///
/// Call from every logout path:
///   * [AuthController.signOut] (manual logout from settings/verify screen)
///   * [ApiClient.onForceLogout] (refresh-failure path in [AuthInterceptor])
///
/// Don't reach into individual data providers from here — they all watch
/// [userSessionProvider] and will be invalidated by the bump below.
void clearUserScopedSession(Ref ref) {
  ref.read(userSessionProvider.notifier).state++;
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeNotifier(prefs);
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier(this._prefs)
      : super(_loadTheme(_prefs));

  final SharedPreferences _prefs;
  static const _key = 'app_theme';

  static ThemeMode _loadTheme(SharedPreferences prefs) {
    final value = prefs.getString(_key);
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.dark,
    };
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    await _prefs.setString(_key, mode.name);
  }

  void toggle() {
    setTheme(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}
