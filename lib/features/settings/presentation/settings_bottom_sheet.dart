import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/providers/core_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../notifications/data/notification_models.dart';
import '../../notifications/data/fcm_service.dart';

void showSettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet();

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  NotificationPreferences? _prefs;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final repo = ref.read(notificationRepositoryProvider);
      final prefs = await repo.getPreferences();
      if (mounted) setState(() { _prefs = prefs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updatePref(
    Map<String, dynamic> partial, {
    NotificationPreferences? optimistic,
  }) async {
    HapticFeedback.selectionClick();
    final previous = _prefs;
    if (optimistic != null && mounted) {
      setState(() => _prefs = optimistic);
    }
    try {
      final repo = ref.read(notificationRepositoryProvider);
      final updated = await repo.updatePreferences(partial);
      if (mounted) setState(() => _prefs = updated);
    } catch (e) {
      if (mounted) {
        setState(() => _prefs = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update setting: $e')),
        );
      }
    }
  }

  bool _sendingTestPush = false;

  /// Fire a real FCM push to every device the current user has
  /// registered. Useful for QA-ing the push pipeline end-to-end without
  /// having to wait on a peer to send a chat message. The backend also
  /// drops a row into the in-app notifications list, so success is
  /// visible in two places.
  Future<void> _sendTestPush() async {
    if (_sendingTestPush) return;
    HapticFeedback.lightImpact();
    setState(() => _sendingTestPush = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(notificationRepositoryProvider);
      final result = await repo.sendTestNotification();
      if (!mounted) return;
      // Refresh the in-app list/badge immediately so the test row shows
      // up the next time the user opens the bell — without this we'd
      // wait on FCM round-trip even though the row is already in Mongo.
      ref.read(fcmServiceProvider).refreshNotifProviders();

      if (result.pushed) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Test push sent to ${result.successCount} of ${result.deviceCount} device${result.deviceCount == 1 ? '' : 's'}.',
            ),
          ),
        );
      } else {
        final reason = switch (result.reason) {
          'push_disabled' =>
            'Push notifications are turned off for your account. Toggle "Push notifications" above and try again.',
          'no_devices' =>
            'No devices are registered for push. Toggle "Push notifications" above to register this device.',
          'fcm_failed' =>
            'Firebase rejected the push. Check your network and try again.',
          _ => 'Could not send the test push. Try again in a moment.',
        };
        messenger.showSnackBar(SnackBar(content: Text(reason)));
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not send test push: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingTestPush = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeProvider);

    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkPanel.withValues(alpha: 0.95)
            : const Color(0xF2FFFFFF),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: isDark
                ? const Color(0x1AFFFFFF)
                : const Color(0x33000000),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0x33FFFFFF)
                  : const Color(0x33000000),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Appearance
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkSecondaryText
                        : AppColors.lightSecondaryText,
                  ),
                ),
                const SizedBox(height: 10),
                _ThemeOption(
                  label: 'Light',
                  icon: Icons.light_mode,
                  isSelected: themeMode == ThemeMode.light,
                  onTap: () => ref
                      .read(themeProvider.notifier)
                      .setTheme(ThemeMode.light),
                ),
                const SizedBox(height: 8),
                _ThemeOption(
                  label: 'Dark',
                  icon: Icons.dark_mode,
                  isSelected: themeMode == ThemeMode.dark,
                  onTap: () => ref
                      .read(themeProvider.notifier)
                      .setTheme(ThemeMode.dark),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Notification toggles
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkSecondaryText
                        : AppColors.lightSecondaryText,
                  ),
                ),
                const SizedBox(height: 10),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else ...[
                  _ToggleRow(
                    label: 'Push notifications',
                    value: _prefs?.pushEnabled ?? false,
                    onChanged: (v) async {
                      // Capture messenger before any await so we don't use
                      // BuildContext across an async gap.
                      final messenger = ScaffoldMessenger.of(context);
                      await _updatePref(
                        {'push_enabled': v},
                        optimistic: _prefs?.copyWith(pushEnabled: v),
                      );
                      final fcm = ref.read(fcmServiceProvider);
                      if (v) {
                        final result = await fcm.requestAndRegister();
                        if (!mounted) return;
                        if (result == FcmRegisterResult.permissionDenied) {
                          // Roll back the toggle and tell the user how to fix
                          // it. On Android 13+ the system POST_NOTIFICATIONS
                          // dialog can be denied; once denied they must enable
                          // it from system settings.
                          await _updatePref(
                            {'push_enabled': false},
                            optimistic: _prefs?.copyWith(pushEnabled: false),
                          );
                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Notification permission was denied. Enable it in system settings to receive push notifications.',
                              ),
                            ),
                          );
                        } else if (result == FcmRegisterResult.error) {
                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not enable push notifications. Please try again.',
                              ),
                            ),
                          );
                        }
                      } else {
                        await fcm.unregister();
                      }
                    },
                  ),
                  _ToggleRow(
                    label: 'Chat messages',
                    value: _prefs?.chatEnabled ?? true,
                    onChanged: (v) => _updatePref(
                      {'chat_enabled': v},
                      optimistic: _prefs?.copyWith(chatEnabled: v),
                    ),
                  ),
                  _ToggleRow(
                    label: 'Daily digest',
                    value: _prefs?.dailyDigestEnabled ?? true,
                    onChanged: (v) => _updatePref(
                      {'daily_digest_enabled': v},
                      optimistic: _prefs?.copyWith(dailyDigestEnabled: v),
                    ),
                  ),
                  _ToggleRow(
                    label: 'New projects',
                    value: _prefs?.newProjectEnabled ?? true,
                    onChanged: (v) => _updatePref(
                      {'new_project_enabled': v},
                      optimistic: _prefs?.copyWith(newProjectEnabled: v),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SendTestPushButton(
                    isDark: Theme.of(context).brightness == Brightness.dark,
                    onPressed: _sendTestPush,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Logout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  // Capture everything we need from `ref` and `context`
                  // BEFORE popping the sheet — `Navigator.pop` disposes
                  // this State, after which `ref` throws "Cannot use ref
                  // after the widget was disposed". Use the root
                  // navigator's context so router.go() still works once
                  // this sheet is gone.
                  final fcm = ref.read(fcmServiceProvider);
                  final auth = ref.read(authControllerProvider.notifier);
                  final router = GoRouter.of(context);
                  Navigator.pop(context);
                  // Unregister the active FCM token before signing out so the
                  // backend doesn't keep an orphaned device token tied to this
                  // user. If unregister fails (network), we still proceed with
                  // signOut to avoid trapping the user.
                  try {
                    await fcm.unregister();
                  } catch (_) {}
                  await auth.signOut();
                  router.go('/auth');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: const BorderSide(color: AppColors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Logout'),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? (isDark
                  ? AppColors.primaryStart.withValues(alpha: 0.15)
                  : AppColors.primaryStart.withValues(alpha: 0.08))
              : (isDark
                  ? const Color(0x0DFFFFFF)
                  : const Color(0xFFF3F3F5)),
          border: Border.all(
            color: isSelected ? AppColors.primaryStart : Colors.transparent,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: isSelected ? AppColors.primaryStart : null),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.primaryStart : null,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: AppColors.primaryStart, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 15)),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SendTestPushButton extends StatefulWidget {
  const _SendTestPushButton({required this.isDark, required this.onPressed});
  final bool isDark;
  final Future<void> Function() onPressed;

  @override
  State<_SendTestPushButton> createState() => _SendTestPushButtonState();
}

class _SendTestPushButtonState extends State<_SendTestPushButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                try {
                  await widget.onPressed();
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
        icon: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.notifications_active_outlined, size: 18),
        label: Text(_busy ? 'Sending…' : 'Send a test notification'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryStart,
          side: BorderSide(
            color: AppColors.primaryStart.withValues(alpha: 0.5),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
