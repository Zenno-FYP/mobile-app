import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override in ProviderScope');
});

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
