import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/providers/core_providers.dart';
import '../../auth/presentation/auth_controller.dart';

void showSettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeProvider);

    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkPanel.withValues(alpha: 0.95) : const Color(0xF2FFFFFF),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: isDark ? const Color(0x1AFFFFFF) : const Color(0x33000000)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0x33FFFFFF) : const Color(0x33000000),
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
                Text('Appearance', style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                const SizedBox(height: 10),
                _ThemeOption(
                  label: 'Light',
                  icon: Icons.light_mode,
                  isSelected: themeMode == ThemeMode.light,
                  onTap: () => ref.read(themeProvider.notifier).setTheme(ThemeMode.light),
                ),
                const SizedBox(height: 8),
                _ThemeOption(
                  label: 'Dark',
                  icon: Icons.dark_mode,
                  isSelected: themeMode == ThemeMode.dark,
                  onTap: () => ref.read(themeProvider.notifier).setTheme(ThemeMode.dark),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Notification toggles (placeholder)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notifications', style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                const SizedBox(height: 10),
                _ToggleRow(label: 'Push notifications', value: false, onChanged: (_) {}),
                _ToggleRow(label: 'Weekly digest', value: false, onChanged: (_) {}),
                _ToggleRow(label: 'Sound', value: true, onChanged: (_) {}),
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
                  Navigator.pop(context);
                  await ref.read(authControllerProvider.notifier).signOut();
                  if (context.mounted) context.go('/auth');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: const BorderSide(color: AppColors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  const _ThemeOption({required this.label, required this.icon, required this.isSelected, required this.onTap});
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
              ? (isDark ? AppColors.primaryStart.withValues(alpha: 0.15) : AppColors.primaryStart.withValues(alpha: 0.08))
              : (isDark ? const Color(0x0DFFFFFF) : const Color(0xFFF3F3F5)),
          border: Border.all(
            color: isSelected ? AppColors.primaryStart : Colors.transparent,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? AppColors.primaryStart : null),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppColors.primaryStart : null,
            )),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle, color: AppColors.primaryStart, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
