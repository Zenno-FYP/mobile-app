import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/format_duration.dart';
import '../../../../core/widgets/metric_tile.dart';
import '../../../../shared/widgets/lang_bar.dart';
import '../../../../shared/widgets/tag_badge.dart';
import '../../../dashboard/data/models/dashboard_models.dart';

/// Shared sections used by both [ProfileScreen] (own profile) and
/// [PublicProfileScreen] (viewing a peer). Extracting them keeps the two
/// surfaces in pixel-perfect sync with the website's profile layout —
/// previously the public profile rendered a stripped-down view that was
/// missing apps, languages-with-rows, and the full project tile.
class ProfileSections {
  const ProfileSections._();

  /// Mirror the website's `MAX_GLOBAL_VISIBLE` so Top Skills, Top Apps,
  /// and Languages cap at the same six entries everywhere.
  static const int maxGlobalVisible = 6;
}

/// Two-by-two grid of the four hero stats (Streak / Projects / App hours /
/// Flow focus) using `IntrinsicHeight` rows so each tile sizes to its
/// content (no overflow on narrow phones).
class ProfileMetricsGrid extends StatelessWidget {
  const ProfileMetricsGrid({super.key, required this.data});
  final ProfilePageResponse data;

  @override
  Widget build(BuildContext context) {
    final flow = data.globalFlowFocusPercent;
    final tiles = <Widget>[
      MetricTile(
        icon: Icons.local_fire_department,
        label: 'Streak',
        value: '${data.streakDays}d',
        gradient: const LinearGradient(
          colors: [AppColors.yellow, AppColors.yellowDark],
        ),
      ),
      MetricTile(
        icon: Icons.folder,
        label: 'Projects',
        value: '${data.totalProjects}',
      ),
      MetricTile(
        icon: Icons.timer,
        label: 'App Hours',
        value: formatHours(data.totalAppTimeHours),
        gradient: const LinearGradient(
          colors: [AppColors.teal, AppColors.tealDark],
        ),
      ),
      MetricTile(
        icon: Icons.psychology,
        label: 'Flow Focus',
        value: flow != null ? '${flow.toStringAsFixed(0)}%' : 'N/A',
        gradient: const LinearGradient(
          colors: [AppColors.pink, AppColors.pinkLight],
        ),
      ),
    ];

    Widget row(Widget a, Widget b) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: a),
              const SizedBox(width: 10),
              Expanded(child: b),
            ],
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row(tiles[0], tiles[1]),
        const SizedBox(height: 10),
        row(tiles[2], tiles[3]),
      ],
    );
  }
}

/// Skill row: name on the left, percentage on the right, and an inline
/// linear progress bar underneath. Mirrors the website's Top Skills card.
///
/// When [hidden] / [onToggleHide] are supplied, an eye icon button is
/// rendered to the right and the row dims to ~40% opacity if hidden —
/// matching the website's edit-mode UX so users can hide skills before
/// they appear on their public profile.
class ProgressRow extends StatelessWidget {
  const ProgressRow({
    super.key,
    required this.name,
    required this.percent,
    required this.isDark,
    this.hidden,
    this.onToggleHide,
  });
  final String name;
  final double percent;
  final bool isDark;
  final bool? hidden;
  final VoidCallback? onToggleHide;

  @override
  Widget build(BuildContext context) {
    final isEdit = onToggleHide != null;
    final isHidden = hidden ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: isEdit && isHidden ? 0.4 : 1,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(name, style: const TextStyle(fontSize: 14))),
                Text(
                  '${percent.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkSecondaryText
                        : AppColors.lightSecondaryText,
                  ),
                ),
                if (isEdit) _EyeButton(hidden: isHidden, onTap: onToggleHide!),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: 5,
                backgroundColor:
                    isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB),
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.primaryStart),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top-app card: name, hours, percentage, and a progress bar.
///
/// When [hidden] / [onToggleHide] are supplied, the row gets an eye
/// toggle and dims when hidden — same edit-mode pattern as
/// [ProgressRow].
class AppRow extends StatelessWidget {
  const AppRow({
    super.key,
    required this.name,
    required this.hours,
    required this.percent,
    required this.isDark,
    this.hidden,
    this.onToggleHide,
  });
  final String name;
  final double hours, percent;
  final bool isDark;
  final bool? hidden;
  final VoidCallback? onToggleHide;

  @override
  Widget build(BuildContext context) {
    final secondary =
        isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;
    final isEdit = onToggleHide != null;
    final isHidden = hidden ?? false;
    return Opacity(
      opacity: isEdit && isHidden ? 0.4 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0x0DFFFFFF) : const Color(0x99FFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? const Color(0x1AFFFFFF)
                : const Color(0x33000000).withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatHours(hours),
                        style: TextStyle(fontSize: 11, color: secondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${percent.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryStart,
                  ),
                ),
                if (isEdit) _EyeButton(hidden: isHidden, onTap: onToggleHide!),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (percent / 100).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor:
                    isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB),
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.primaryStart),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Language card: colored dot + name on the left, percent + LOC on the
/// right, with a progress bar in the language's brand colour underneath.
class LanguageRow extends StatelessWidget {
  const LanguageRow({
    super.key,
    required this.name,
    required this.percent,
    required this.lines,
    required this.isDark,
    required this.color,
    this.hidden,
    this.onToggleHide,
  });
  final String name;
  final double percent;
  final int lines;
  final bool isDark;
  final Color color;
  final bool? hidden;
  final VoidCallback? onToggleHide;

  @override
  Widget build(BuildContext context) {
    final secondary =
        isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;
    final isEdit = onToggleHide != null;
    final isHidden = hidden ?? false;
    return Opacity(
      opacity: isEdit && isHidden ? 0.4 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0x0DFFFFFF) : const Color(0x99FFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? const Color(0x1AFFFFFF)
                : const Color(0x33000000).withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(name, style: const TextStyle(fontSize: 14))),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${percent.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryStart,
                      ),
                    ),
                    Text(
                      '${_formatLines(lines)} lines',
                      style: TextStyle(fontSize: 10, color: secondary),
                    ),
                  ],
                ),
                if (isEdit) _EyeButton(hidden: isHidden, onTap: onToggleHide!),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (percent / 100).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor:
                    isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatLines(int n) {
    if (n < 1000) return '$n';
    if (n < 1000000) {
      return '${(n / 1000).toStringAsFixed(n < 10000 ? 1 : 0)}k';
    }
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }
}

/// Project tile mirroring the website's profile project card: title (with
/// optional code-style key when a display name is set), description (with
/// "No project description." fallback), a stats row of last active /
/// app hours / project insight, language distribution bar with legend,
/// and chip lists for top apps and top skills with their durations.
///
/// Pass `interactive: false` from the public-profile screen so peer
/// project tiles don't try to navigate to the *viewer's* project page —
/// matching the website where peer project headings are not links.
class ProjectTile extends StatelessWidget {
  const ProjectTile({
    super.key,
    required this.project,
    required this.isDark,
    this.interactive = true,
    this.hidden,
    this.onToggleHide,
    this.onMoveUp,
    this.onMoveDown,
    this.canMoveUp = false,
    this.canMoveDown = false,
  });
  final ProfileProjectCard project;
  final bool isDark;
  final bool interactive;

  /// Edit-mode controls. Mirror the website's profile edit-mode UX: an
  /// eye toggle to hide the card from the public profile and up/down
  /// arrows to reorder within the projects list.
  final bool? hidden;
  final VoidCallback? onToggleHide;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final bool canMoveUp;
  final bool canMoveDown;

  @override
  Widget build(BuildContext context) {
    final secondary =
        isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;
    final muted = isDark ? const Color(0xFF7B8294) : const Color(0xFF6B7280);
    final title = (project.displayName?.trim().isNotEmpty ?? false)
        ? project.displayName!.trim()
        : project.projectName;
    final showProjectKey = project.displayName != null &&
        project.displayName!.trim().isNotEmpty &&
        project.displayName!.trim() != project.projectName;
    final isEdit = onToggleHide != null;
    final isHidden = hidden ?? false;

    final card = Opacity(
      opacity: isEdit && isHidden ? 0.45 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0x0DFFFFFF) : const Color(0x66FFFFFF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? const Color(0x1AFFFFFF) : const Color(0x33FFFFFF),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isEdit && (onMoveUp != null || onMoveDown != null)) ...[
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ArrowButton(
                        icon: Icons.keyboard_arrow_up,
                        enabled: canMoveUp,
                        onTap: onMoveUp,
                        isDark: isDark,
                      ),
                      _ArrowButton(
                        icon: Icons.keyboard_arrow_down,
                        enabled: canMoveDown,
                        onTap: onMoveDown,
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (showProjectKey) ...[
                        const SizedBox(height: 2),
                        Text(
                          project.projectName,
                          style: TextStyle(
                            fontSize: 11,
                            color: muted,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isEdit)
                  _EyeButton(hidden: isHidden, onTap: onToggleHide!)
                else if (interactive)
                  Icon(Icons.chevron_right, color: secondary, size: 20),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            project.description.trim().isNotEmpty
                ? project.description.trim()
                : 'No project description.',
            style: TextStyle(
              fontSize: 13,
              color: secondary,
              fontStyle: project.description.trim().isEmpty
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),
          const SizedBox(height: 12),
          ProjectStatsRow(project: project, isDark: isDark),
          if (project.languages.isNotEmpty) ...[
            const SizedBox(height: 14),
            LanguageDistribution(
              languages: project.languages,
              isDark: isDark,
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              'No LOC snapshot yet.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ],
          if (project.topApps.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Top apps',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: project.topApps
                  .map((a) => AppChip(
                        label: '${a.name} · ${formatHours(a.durationHours)}',
                        isDark: isDark,
                      ))
                  .toList(),
            ),
          ],
          if (project.topSkills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Top skills',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: project.topSkills
                  .map((s) => TagBadge(
                        label: '${s.name} · ${formatHours(s.durationHours)}',
                        isGradient: true,
                      ))
                  .toList(),
            ),
          ],
        ],
        ),
      ),
    );

    // In edit mode the tile is a controls surface, not a navigation
    // target — tapping the body shouldn't deep-link to the project.
    if (isEdit || !interactive) return card;
    return GestureDetector(
      onTap: () => context
          .push('/projects/${Uri.encodeComponent(project.projectName)}'),
      child: card,
    );
  }
}

class ProjectStatsRow extends StatelessWidget {
  const ProjectStatsRow({
    super.key,
    required this.project,
    required this.isDark,
  });
  final ProfileProjectCard project;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final secondary =
        isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;
    final accent = isDark ? const Color(0xFFA78BFA) : AppColors.primaryStart;

    final ins = project.insight;
    String insightLabel;
    if (ins.kind == 'flow_focus' && ins.flowFocusPercent != null) {
      insightLabel = 'Flow focus ${ins.flowFocusPercent!.toStringAsFixed(0)}%';
    } else if (ins.kind == 'dominant_context' &&
        ins.label != null &&
        ins.percent != null) {
      insightLabel =
          '${ins.label} ${ins.percent!.toStringAsFixed(0)}%';
    } else {
      insightLabel = '—';
    }

    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _StatChip(
          icon: Icons.access_time,
          label: 'Last active ${_formatLastActive(project.lastActive)}',
          color: secondary,
        ),
        _StatChip(
          icon: Icons.bolt_outlined,
          label: '${formatHours(project.appTimeHours)} in apps',
          color: secondary,
        ),
        _StatChip(
          icon: Icons.local_fire_department_outlined,
          label: insightLabel,
          color: accent,
        ),
      ],
    );
  }

  static String _formatLastActive(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso).toLocal();
      return DateFormat('MMM d, HH:mm').format(d);
    } catch (_) {
      return iso;
    }
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}

class LanguageDistribution extends StatelessWidget {
  const LanguageDistribution({
    super.key,
    required this.languages,
    required this.isDark,
  });
  final List<ProfileProjectLanguageShare> languages;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final normalized = _normalize(languages);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Language distribution',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: normalized.where((l) => l.percent > 0).map((l) {
                return Expanded(
                  flex: (l.percent * 100).round().clamp(1, 100000),
                  child: Container(color: LangBar.langColor(l.name)),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: languages.map((l) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: LangBar.langColor(l.name),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${l.name} (${l.percent.toStringAsFixed(0)}%)',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkSecondaryText
                        : AppColors.lightSecondaryText,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Normalize so segment widths sum to 100% even when API percentages
  /// don't quite reach it (matches website behaviour).
  static List<ProfileProjectLanguageShare> _normalize(
    List<ProfileProjectLanguageShare> raw,
  ) {
    final total = raw.fold<double>(
      0,
      (s, l) => s + (l.percent.isFinite && l.percent > 0 ? l.percent : 0),
    );
    if (total <= 0) return raw;
    return raw
        .map(
          (l) => ProfileProjectLanguageShare(
            name: l.name,
            percent:
                (l.percent.isFinite && l.percent > 0 ? l.percent : 0) /
                    total *
                    100,
          ),
        )
        .toList();
  }
}

class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, required this.isDark});
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x0DFFFFFF) : const Color(0xB3FFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0x14000000),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: isDark ? Colors.white70 : const Color(0xFF374151),
        ),
      ),
    );
  }
}

/// Eye / eye-off toggle used in profile edit mode to mark a row as
/// hidden from the public profile.
class _EyeButton extends StatelessWidget {
  const _EyeButton({required this.hidden, required this.onTap});
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: hidden ? 'Show on profile' : 'Hide from profile',
      child: IconButton(
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        icon: Icon(
          hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 18,
        ),
      ),
    );
  }
}

/// Compact arrow button used in profile edit mode to reorder project
/// cards. Greyed out (and inert) at list boundaries.
class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.isDark,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final disabledColor = isDark
        ? const Color(0x33FFFFFF)
        : const Color(0xFF9CA3AF).withValues(alpha: 0.4);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(
          icon,
          size: 20,
          color: enabled
              ? (isDark ? Colors.white70 : const Color(0xFF374151))
              : disabledColor,
        ),
      ),
    );
  }
}
