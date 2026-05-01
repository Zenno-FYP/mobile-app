import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/agent_repository.dart';
import '../data/agent_models.dart';

final _agentRepoProvider =
    Provider((ref) => AgentRepository(ref.watch(apiClientProvider)));

final _prefsProvider = FutureProvider<AgentPreferences>((ref) {
  ref.watch(userSessionProvider);
  return ref.watch(_agentRepoProvider).getPreferences();
});

final _statsProvider = FutureProvider<NudgeStats>((ref) {
  ref.watch(userSessionProvider);
  return ref.watch(_agentRepoProvider).getNudgeStats();
});

const _desktopSyncMaxAge = Duration(minutes: 30);

bool desktopAgentSyncedRecently(String? iso) {
  if (iso == null || iso.isEmpty) return false;
  final t = DateTime.tryParse(iso);
  if (t == null) return false;
  return DateTime.now().difference(t) <= _desktopSyncMaxAge;
}

class AgentScreen extends ConsumerStatefulWidget {
  const AgentScreen({super.key});

  @override
  ConsumerState<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends ConsumerState<AgentScreen> {
  /// Local snapshot used to back optimistic toggles (so the switch flips
  /// instantly while the PATCH is in flight). Kept in sync with the
  /// server through [ref.listen] *and* through `prefsAsync.valueOrNull`
  /// fallback in [build] — without the fallback the screen would hang on
  /// a spinner forever the second time it was opened, because Riverpod
  /// already had cached data so no state change fires the listener.
  AgentPreferences? _prefs;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prefsAsync = ref.watch(_prefsProvider);
    final statsAsync = ref.watch(_statsProvider);

    // Keep the local _prefs cache in lockstep with the latest server data
    // when a *new* fetch resolves (refresh / first-load). Optimistic
    // toggles already setState directly. Note: this listener only fires
    // on state *changes*, so we still need the `valueOrNull` fallback
    // below for the case where Riverpod already has cached data when the
    // screen mounts.
    ref.listen<AsyncValue<AgentPreferences>>(_prefsProvider, (_, next) {
      next.whenData((d) {
        if (!mounted) return;
        setState(() => _prefs = d);
      });
    });

    // Effective prefs: prefer the locally-edited copy (optimistic
    // toggles), fall back to whatever Riverpod has cached for the
    // provider. This makes a re-mount of the screen render instantly
    // from cache instead of hanging on a spinner forever — the bug we
    // hit when navigating away and back.
    final prefs = _prefs ?? prefsAsync.valueOrNull;

    final isRefreshing = prefsAsync.isLoading || statsAsync.isLoading;
    final user = ref.watch(currentUserProvider);
    final syncFresh = desktopAgentSyncedRecently(user?.activitySyncAt);
    final showAgentControls = isRefreshing || syncFresh;
    final showOfflineBanner = !isRefreshing && !syncFresh;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zenno Agent'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: isRefreshing ? null : _refresh,
            icon: isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryStart,
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: prefs == null
          ? prefsAsync.when(
              loading: () => const Center(
                child:
                    CircularProgressIndicator(color: AppColors.primaryStart),
              ),
              error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(_prefsProvider),
              ),
              // `prefs` is non-null whenever `prefsAsync` has data (via
              // `valueOrNull` above), so this branch is only reached when
              // there is genuinely no value yet. Treat it as a brief
              // post-resolution gap and show the spinner for one frame.
              data: (_) => const Center(
                child:
                    CircularProgressIndicator(color: AppColors.primaryStart),
              ),
            )
          : RefreshIndicator(
              color: AppColors.primaryStart,
              onRefresh: () async => _refresh(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _StatsCard(stats: statsAsync, isDark: isDark, ref: ref),
                  if (showOfflineBanner) ...[
                    const SizedBox(height: 16),
                    _DesktopOfflineBanner(isDark: isDark),
                  ],
                  if (showAgentControls) ...[
                    const SizedBox(height: 16),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(title: 'Controls', icon: Icons.tune),
                          const SizedBox(height: 12),
                          _SwitchRow(
                            icon: Icons.power_settings_new,
                            label: 'Nudges Enabled',
                            subtitle: prefs.nudgeEnabled
                                ? 'Agent is running'
                                : 'All nudges are off',
                            value: prefs.nudgeEnabled,
                            isDark: isDark,
                            danger: !prefs.nudgeEnabled,
                            onChanged: (v) => _update(
                              {'nudge_enabled': v},
                              prefs.copyWith(nudgeEnabled: v),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _SwitchRow(
                            icon: Icons.volume_up,
                            label: 'Notification Sound',
                            subtitle: prefs.notificationSound
                                ? 'Chime plays with each nudge'
                                : 'Silent notifications',
                            value: prefs.notificationSound,
                            isDark: isDark,
                            onChanged: (v) => _update(
                              {'notification_sound': v},
                              prefs.copyWith(notificationSound: v),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _OptionSection(
                      title: 'Work Schedule',
                      icon: Icons.schedule,
                      options: const {
                        'morning': 'Morning Bird',
                        'standard': 'Standard Day',
                        'evening': 'Evening Shift',
                        'night_owl': 'Night Owl',
                      },
                      selected: prefs.workSchedule,
                      onSelected: (v) => _update(
                        {'work_schedule': v},
                        prefs.copyWith(workSchedule: v),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _OptionSection(
                      title: 'Focus Style',
                      icon: Icons.center_focus_strong,
                      options: const {
                        'deep': 'Deep Focus',
                        'moderate': 'Moderate',
                        'pomodoro': 'Pomodoro',
                      },
                      selected: prefs.focusStyle,
                      onSelected: (v) => _update(
                        {'focus_style': v},
                        prefs.copyWith(focusStyle: v),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _OptionSection(
                      title: 'Wellbeing Goal',
                      icon: Icons.favorite,
                      options: const {
                        'focused': 'Stay Focused',
                        'burnout': 'Prevent Burnout',
                        'habits': 'Build Habits',
                        'minimal': 'Minimal Mode',
                      },
                      selected: prefs.wellbeingGoal,
                      onSelected: (v) => _update(
                        {'wellbeing_goal': v},
                        prefs.copyWith(wellbeingGoal: v),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _OptionSection(
                      title: 'Agent Personality',
                      icon: Icons.record_voice_over,
                      options: const {
                        'friendly': 'Friendly',
                        'motivational': 'Motivational',
                        'professional': 'Professional',
                        'casual': 'Casual',
                      },
                      selected: prefs.agentTone,
                      onSelected: (v) => _update(
                        {'agent_tone': v},
                        prefs.copyWith(agentTone: v),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(_prefsProvider);
    ref.invalidate(_statsProvider);
    try {
      final u = await ref.read(userRemoteDataSourceProvider).getMe();
      ref.read(currentUserProvider.notifier).state = u;
    } catch (_) {
      // Keep cached user; sync timestamp may be stale until next successful refresh.
    }
  }

  Future<void> _update(
    Map<String, dynamic> patch,
    AgentPreferences newPrefs,
  ) async {
    HapticFeedback.selectionClick();
    // Capture the current effective prefs so a failed PATCH can revert
    // cleanly. If the user toggled before [ref.listen] ever fired (the
    // valueOrNull cache path on remount), `_prefs` would be null; fall
    // back to the cached provider value so rollback never wipes the UI
    // back into the spinner state.
    final previous = _prefs ?? ref.read(_prefsProvider).valueOrNull;
    setState(() => _prefs = newPrefs);
    try {
      await ref.read(_agentRepoProvider).updatePreferences(patch);
    } catch (_) {
      if (!mounted) return;
      setState(() => _prefs = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your preference. Reverted.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}

class _DesktopOfflineBanner extends StatelessWidget {
  const _DesktopOfflineBanner({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final border = isDark ? const Color(0x59FFC107) : const Color(0xFFFFE082);
    final bg = isDark ? const Color(0x33FFC107) : const Color(0xFFFFF8E1);
    final titleColor = isDark ? const Color(0xFFFFECB3) : const Color(0xFFBF360C);
    final bodyColor = isDark ? const Color(0xE6FFE082) : const Color(0xFF5D4037);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Desktop agent is not running',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start the Zenno desktop agent on your computer so it can sync at least once every 30 minutes. Until then, only statistics are shown.',
            style: TextStyle(fontSize: 13, height: 1.35, color: bodyColor),
          ),
        ],
      ),
    );
  }
}

/// Three-tile stats row + optional suppression-by-reason chips. Mirrors
/// the website layout: All Time / This Week / Suppressed, plus a bucketed
/// list when the desktop agent reports `suppressed_by_reason`.
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats, required this.isDark, required this.ref});
  final AsyncValue<NudgeStats> stats;
  final bool isDark;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    AppColors.primaryEnd.withValues(alpha: 0.2),
                    AppColors.primaryStart.withValues(alpha: 0.1),
                  ]
                : [const Color(0xFFF5F0FF), const Color(0xFFEEF2FF)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Agent Statistics',
              icon: Icons.bar_chart,
            ),
            const SizedBox(height: 4),
            Text(
              'Live nudge metrics',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkSecondaryText
                    : AppColors.lightSecondaryText,
              ),
            ),
            const SizedBox(height: 14),
            stats.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.primaryStart,
                    ),
                  ),
                ),
              ),
              error: (e, _) => _buildError(),
              data: (data) => _buildTiles(data),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTiles(NudgeStats data) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: MetricTile(
              icon: Icons.trending_up,
              label: 'All Time',
              value: _formatCount(data.totalNudges),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: MetricTile(
              icon: Icons.event,
              label: 'This Week',
              value: _formatCount(data.thisWeekNudges),
              gradient: const LinearGradient(
                colors: [AppColors.teal, AppColors.tealDark],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: MetricTile(
              icon: Icons.notifications_off_outlined,
              label: 'Suppressed',
              value: _formatCount(data.totalSuppressed),
              gradient: const LinearGradient(
                colors: [AppColors.yellow, AppColors.yellowDark],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load agent stats',
            style: TextStyle(
              color: isDark
                  ? AppColors.darkSecondaryText
                  : AppColors.lightSecondaryText,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => ref.invalidate(_statsProvider),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatCount(int n) {
    if (n < 1000) return '$n';
    if (n < 1000000) return '${(n / 1000).toStringAsFixed(n < 10000 ? 1 : 0)}k';
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.isDark,
    required this.onChanged,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final bool isDark;
  final bool danger;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? (isDark ? const Color(0x33FF4444) : const Color(0xFFFFEDED))
        : (isDark ? const Color(0x0DFFFFFF) : const Color(0x99FFFFFF));
    final borderColor = danger
        ? (isDark ? const Color(0x80FF4444) : const Color(0xFFFCA5A5))
        : (isDark ? const Color(0x1AFFFFFF) : const Color(0x14000000));
    final iconColor = danger
        ? (isDark ? const Color(0xFFFF8A80) : const Color(0xFFEF4444))
        : (isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText);
    final titleColor = danger
        ? (isDark ? const Color(0xFFFF8A80) : const Color(0xFFEF4444))
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: titleColor ??
                        (isDark
                            ? AppColors.darkSecondaryText
                            : AppColors.lightSecondaryText),
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _OptionSection extends StatelessWidget {
  const _OptionSection({
    required this.title,
    required this.icon,
    required this.options,
    required this.selected,
    required this.onSelected,
  });
  final String title;
  final IconData icon;
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title, icon: icon),
          const SizedBox(height: 12),
          ...options.entries.map((e) {
            final isSelected = e.key == selected;
            return GestureDetector(
              onTap: () => onSelected(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isSelected
                      ? (isDark
                          ? AppColors.primaryStart.withValues(alpha: 0.15)
                          : AppColors.primaryStart.withValues(alpha: 0.08))
                      : (isDark
                          ? const Color(0x0DFFFFFF)
                          : const Color(0x33FFFFFF)),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryStart.withValues(alpha: 0.5)
                        : (isDark
                            ? const Color(0x1AFFFFFF)
                            : const Color(0x33FFFFFF)),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? AppColors.primaryStart : null,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.primaryStart,
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
