import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../notifications/presentation/notification_bell_action.dart';
import '../data/agent_repository.dart';
import '../data/agent_models.dart';

final _agentRepoProvider = Provider((ref) => AgentRepository(ref.watch(apiClientProvider)));

final _prefsProvider = FutureProvider<AgentPreferences>((ref) {
  return ref.watch(_agentRepoProvider).getPreferences();
});

final _statsProvider = FutureProvider<NudgeStats>((ref) {
  return ref.watch(_agentRepoProvider).getNudgeStats();
});

class AgentScreen extends ConsumerStatefulWidget {
  const AgentScreen({super.key});

  @override
  ConsumerState<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends ConsumerState<AgentScreen> {
  AgentPreferences? _prefs;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prefsAsync = ref.watch(_prefsProvider);
    final statsAsync = ref.watch(_statsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zenno Agent'),
        actions: [
          const NotificationBellAction(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(_prefsProvider);
              ref.invalidate(_statsProvider);
            },
          ),
        ],
      ),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryStart)),
        error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(_prefsProvider)),
        data: (data) {
          _prefs ??= data;
          final prefs = _prefs!;
          return RefreshIndicator(
            color: AppColors.primaryStart,
            onRefresh: () async { ref.invalidate(_prefsProvider); ref.invalidate(_statsProvider); },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Nudge Stats
                statsAsync.when(
                  data: (stats) => GlassCard(
                    padding: EdgeInsets.zero,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [AppColors.primaryEnd.withValues(alpha: 0.2), AppColors.primaryStart.withValues(alpha: 0.1)]
                              : [const Color(0xFFF5F0FF), const Color(0xFFEEF2FF)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          const SectionHeader(title: 'Agent Statistics', icon: Icons.bar_chart),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: MetricTile(icon: Icons.notifications_active, label: 'Total Nudges', value: '${stats.totalNudges}')),
                              const SizedBox(width: 8),
                              Expanded(child: MetricTile(icon: Icons.today, label: 'Today', value: '${stats.nudgesToday}',
                                  gradient: const LinearGradient(colors: [AppColors.teal, AppColors.tealDark]))),
                              const SizedBox(width: 8),
                              Expanded(child: MetricTile(icon: Icons.do_not_disturb, label: 'Suppressed', value: '${stats.suppressedCount}',
                                  gradient: const LinearGradient(colors: [AppColors.yellow, AppColors.yellowDark]))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  loading: () => GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: const [
                        SectionHeader(
                          title: 'Agent Statistics',
                          icon: Icons.bar_chart,
                        ),
                        SizedBox(height: 16),
                        Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: AppColors.primaryStart,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                      ],
                    ),
                  ),
                  error: (e, _) => GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                          title: 'Agent Statistics',
                          icon: Icons.bar_chart,
                        ),
                        const SizedBox(height: 12),
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
                  ),
                ),

                const SizedBox(height: 16),

                // Controls
                GlassCard(
                  child: Column(
                    children: [
                      const SectionHeader(title: 'Controls', icon: Icons.tune),
                      const SizedBox(height: 12),
                      _SwitchRow(
                        label: 'Nudges Enabled',
                        value: prefs.nudgeEnabled,
                        onChanged: (v) => _update({'nudge_enabled': v}, prefs.copyWith(nudgeEnabled: v)),
                      ),
                      _SwitchRow(
                        label: 'Frequent Meetings',
                        value: prefs.hasMeetings,
                        onChanged: (v) => _update({'has_meetings': v}, prefs.copyWith(hasMeetings: v)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Work Schedule
                _OptionSection(
                  title: 'Work Schedule',
                  icon: Icons.schedule,
                  options: const {'morning': 'Morning', 'standard': 'Standard', 'evening': 'Evening', 'night_owl': 'Night Owl'},
                  selected: prefs.workSchedule,
                  onSelected: (v) => _update({'work_schedule': v}, prefs.copyWith(workSchedule: v)),
                ),

                const SizedBox(height: 16),

                // Focus Style
                _OptionSection(
                  title: 'Focus Style',
                  icon: Icons.center_focus_strong,
                  options: const {'deep': 'Deep', 'moderate': 'Moderate', 'pomodoro': 'Pomodoro'},
                  selected: prefs.focusStyle,
                  onSelected: (v) => _update({'focus_style': v}, prefs.copyWith(focusStyle: v)),
                ),

                const SizedBox(height: 16),

                // Wellbeing Goal
                _OptionSection(
                  title: 'Wellbeing Goal',
                  icon: Icons.favorite,
                  options: const {'focused': 'Focused', 'burnout': 'Prevent Burnout', 'habits': 'Better Habits', 'minimal': 'Minimal'},
                  selected: prefs.wellbeingGoal,
                  onSelected: (v) => _update({'wellbeing_goal': v}, prefs.copyWith(wellbeingGoal: v)),
                ),

                const SizedBox(height: 16),

                // Agent Tone
                _OptionSection(
                  title: 'Agent Personality',
                  icon: Icons.record_voice_over,
                  options: const {'friendly': 'Friendly', 'motivational': 'Motivational', 'professional': 'Professional', 'casual': 'Casual'},
                  selected: prefs.agentTone,
                  onSelected: (v) => _update({'agent_tone': v}, prefs.copyWith(agentTone: v)),
                ),

                const SizedBox(height: 16),
                Text(
                  'Changes are synced automatically every 5 minutes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _update(Map<String, dynamic> patch, AgentPreferences newPrefs) async {
    // Light tactile confirmation that the toggle/segmented control was
    // accepted before the network round-trip starts.
    HapticFeedback.selectionClick();
    // Optimistic update: snapshot the previous prefs so we can revert
    // if the API call fails. The screen already re-renders immediately.
    final previous = _prefs;
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

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.label, required this.value, required this.onChanged});
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isSelected
                      ? (isDark ? AppColors.primaryStart.withValues(alpha: 0.15) : AppColors.primaryStart.withValues(alpha: 0.08))
                      : (isDark ? const Color(0x0DFFFFFF) : const Color(0x33FFFFFF)),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryStart.withValues(alpha: 0.5)
                        : (isDark ? const Color(0x1AFFFFFF) : const Color(0x33FFFFFF)),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(e.value, style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? AppColors.primaryStart : null,
                      )),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle, color: AppColors.primaryStart, size: 20),
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
