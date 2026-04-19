import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/format_duration.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/error_state.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/data/models/dashboard_models.dart';

final _detailProvider = FutureProvider<SkillsProjectsDetailResponse>((ref) {
  ref.watch(userSessionProvider);
  return DashboardRepository(ref.watch(apiClientProvider)).getSkillsProjectsDetail();
});

// Mirrors the gradient palette in `SkillsProjectsDetailPage.tsx` so a project
// renders with the same colour on web and mobile.
const _kProjectGradients = <List<Color>>[
  [Color(0xFF5B6FD8), Color(0xFF7C4DFF)],
  [Color(0xFF4ECDC4), Color(0xFF44A6A0)],
  [Color(0xFFFB542B), Color(0xFFFF8559)],
  [Color(0xFFFF6B9D), Color(0xFFFF8FA3)],
  [Color(0xFFFFD93D), Color(0xFFFFC93D)],
  [Color(0xFF9B59B6), Color(0xFFB47BD2)],
  [Color(0xFF25D366), Color(0xFF34E07A)],
  [Color(0xFF0078D4), Color(0xFF34A2E8)],
];

int _hashString(String s) {
  var hash = 0;
  for (var i = 0; i < s.length; i++) {
    hash = (hash << 5) - hash + s.codeUnitAt(i);
    hash &= 0xFFFFFFFF;
  }
  return hash.abs();
}

List<Color> _projectGradient(String name) =>
    _kProjectGradients[_hashString(name) % _kProjectGradients.length];

String _formatNum(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

/// Best-effort relative-time formatter that matches the website helper:
/// "just now", "5m ago", "2h ago", "3d ago", or "Aug 12".
String _lastActiveRelative(String? iso) {
  if (iso == null || iso.isEmpty) return 'No activity yet';
  DateTime? dt;
  try {
    dt = DateTime.parse(iso).toLocal();
  } catch (_) {
    return 'Unknown';
  }
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}

class SkillsProjectsScreen extends ConsumerWidget {
  const SkillsProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detail = ref.watch(_detailProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Skills & Projects')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryStart)),
        error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(_detailProvider)),
        data: (data) => RefreshIndicator(
          color: AppColors.primaryStart,
          onRefresh: () async => ref.invalidate(_detailProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Summary', icon: Icons.summarize),
                    const SizedBox(height: 14),
                    _SummaryGrid(summary: data.summary, isDark: isDark),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Skills', icon: Icons.emoji_events),
                    const SizedBox(height: 12),
                    if (data.skills.isEmpty)
                      _Empty(
                        icon: Icons.workspace_premium,
                        message: 'No skills detected yet. Sync some projects to populate this list.',
                        isDark: isDark,
                      )
                    else
                      ...data.skills.map((skill) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        skill.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${formatHours(skill.durationHours)}  ·  ${skill.percentOfTotal.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppColors.darkSecondaryText
                                            : AppColors.lightSecondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: (skill.percentOfTotal / 100).clamp(0.0, 1.0),
                                    minHeight: 6,
                                    backgroundColor: isDark
                                        ? const Color(0x1AFFFFFF)
                                        : const Color(0xFFE5E7EB),
                                    valueColor: const AlwaysStoppedAnimation(AppColors.primaryStart),
                                  ),
                                ),
                              ],
                            ),
                          )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Projects', icon: Icons.folder_open),
                    const SizedBox(height: 4),
                    Text(
                      'Sorted by most recently active. Tap to open.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkSecondaryText
                            : AppColors.lightSecondaryText,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (data.projects.isEmpty)
                      _Empty(
                        icon: Icons.folder_off_outlined,
                        message: 'No projects synced yet.',
                        isDark: isDark,
                      )
                    else
                      ...data.projects.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ProjectCard(project: p, isDark: isDark),
                          )),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Summary grid ────────────────────────────────────────────────────────────

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary, required this.isDark});
  final SkillsProjectsSummary summary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // Hand-built 2×2 layout instead of GridView. The previous GridView used a
    // fixed `childAspectRatio` which clipped the icon + value + label content
    // on small phones (RenderFlex overflow). Letting each row decide its own
    // height via IntrinsicHeight + Expanded keeps both cards in a row equal
    // height while still accommodating their natural content.
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SummaryTile(
                  icon: Icons.folder,
                  label: 'Projects',
                  value: '${summary.totalProjects}',
                  gradient: const [AppColors.primaryStart, AppColors.primaryEnd],
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryTile(
                  icon: Icons.timer,
                  label: 'App Hours',
                  value: formatHours(summary.totalAppTimeHours),
                  gradient: const [AppColors.teal, AppColors.tealDark],
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SummaryTile(
                  icon: Icons.star,
                  label: 'Skills',
                  value: '${summary.uniqueSkillsCount}',
                  gradient: const [AppColors.yellow, AppColors.yellowDark],
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryTile(
                  icon: Icons.code,
                  label: 'Lines',
                  value: _formatNum(summary.totalLinesOfCode),
                  gradient: const [AppColors.pink, AppColors.pinkLight],
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.gradient,
    required this.isDark,
  });
  final IconData icon;
  final String label, value;
  final List<Color> gradient;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x0DFFFFFF) : const Color(0x66FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0x33FFFFFF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Project card ────────────────────────────────────────────────────────────

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.isDark});
  final ProjectOverviewItem project;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final title = (project.displayName?.trim().isNotEmpty ?? false)
        ? project.displayName!.trim()
        : project.name;
    final desc = project.description.trim();
    final showSubtitle = title != project.name;
    final gradient = _projectGradient(project.name);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/projects/${Uri.encodeComponent(project.name)}'),
        child: Ink(
          decoration: BoxDecoration(
            color: isDark ? const Color(0x0DFFFFFF) : const Color(0x66FFFFFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0x1AFFFFFF) : const Color(0x33FFFFFF),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Coloured gradient strip on the left, like the website.
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: gradient),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.account_tree, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (showSubtitle) ...[
                                const SizedBox(height: 2),
                                Text(
                                  project.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.darkSecondaryText
                                        : AppColors.lightSecondaryText,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                desc.isNotEmpty
                                    ? desc
                                    : 'No description yet — add one on the project page.',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.35,
                                  fontStyle: desc.isEmpty ? FontStyle.italic : FontStyle.normal,
                                  color: desc.isEmpty
                                      ? (isDark
                                          ? const Color(0x66FFFFFF)
                                          : const Color(0x66000000))
                                      : (isDark
                                          ? AppColors.darkSecondaryText
                                          : AppColors.lightSecondaryText),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 12,
                                    color: isDark
                                        ? const Color(0x99FFFFFF)
                                        : const Color(0x99000000),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Last active · ${_lastActiveRelative(project.lastActive)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? AppColors.darkSecondaryText
                                            : AppColors.lightSecondaryText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: isDark
                              ? const Color(0x99FFFFFF)
                              : const Color(0x66000000),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.message, required this.isDark});
  final IconData icon;
  final String message;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(icon, size: 40, color: isDark ? const Color(0x66FFFFFF) : const Color(0x66000000)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
