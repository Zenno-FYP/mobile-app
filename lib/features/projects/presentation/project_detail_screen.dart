import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/format_duration.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/error_state.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/lang_bar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/data/models/dashboard_models.dart';

final _projectDetailProvider = FutureProvider.family<ProjectDetailResponse, String>((ref, name) {
  return DashboardRepository(ref.watch(apiClientProvider)).getProjectDetail(name);
});

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _fmtNum(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

// Duration helpers come from `core/utils/format_duration.dart` so the
// mobile app stays in lock-step with the website's output.

/// "Apr 12, 14:32" — same format the website uses for the Last-active card.
String _fmtLastActive(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  DateTime? dt;
  try {
    dt = DateTime.parse(iso).toLocal();
  } catch (_) {
    return iso;
  }
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  String two(int n) => n.toString().padLeft(2, '0');
  return '${months[dt.month - 1]} ${dt.day}, ${two(dt.hour)}:${two(dt.minute)}';
}

String _fmtFirstSeen(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  DateTime? dt;
  try {
    dt = DateTime.parse(iso).toLocal();
  } catch (_) {
    return iso;
  }
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

const _kAppPalette = <Color>[
  Color(0xFF5B6FD8),
  Color(0xFF4ECDC4),
  Color(0xFFFB542B),
  Color(0xFFFF6B9D),
  Color(0xFFFFD93D),
  Color(0xFF9B59B6),
  Color(0xFF25D366),
  Color(0xFF0078D4),
];

int _hashString(String s) {
  var hash = 0;
  for (var i = 0; i < s.length; i++) {
    hash = (hash << 5) - hash + s.codeUnitAt(i);
    hash &= 0xFFFFFFFF;
  }
  return hash.abs();
}

Color _appColor(String name) => _kAppPalette[_hashString(name) % _kAppPalette.length];

IconData _appIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('code') || n.contains('vscode')) return Icons.code;
  if (n.contains('chrome') || n.contains('firefox') || n.contains('edge') || n.contains('brave')) {
    return Icons.public;
  }
  if (n.contains('terminal') || n.contains('cmd') || n.contains('powershell')) return Icons.terminal;
  if (n.contains('slack') || n.contains('discord') || n.contains('whatsapp') || n.contains('message')) {
    return Icons.chat_bubble_outline;
  }
  if (n.contains('figma')) return Icons.brush;
  return Icons.apps;
}

class _ContextRow {
  const _ContextRow(this.label, this.color, this.icon, this.hours);
  final String label;
  final Color color;
  final IconData icon;
  final double hours;
}

const _kPreviewLimit = 5;

// ─── Screen ───────────────────────────────────────────────────────────────────

class ProjectDetailScreen extends ConsumerStatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectName});
  final String projectName;

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  bool _isEditing = false;
  bool _saving = false;
  bool _appsExpanded = false;

  late final TextEditingController _displayNameCtrl = TextEditingController();
  late final TextEditingController _descriptionCtrl = TextEditingController();

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _seedEditFields(ProjectDetailResponse data) {
    final dn = data.displayName?.trim();
    _displayNameCtrl.text = (dn != null && dn.isNotEmpty) ? dn : data.projectName;
    _descriptionCtrl.text = data.description;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await DashboardRepository(ref.read(apiClientProvider)).updateProject(
        widget.projectName,
        {
          'display_name': _displayNameCtrl.text.trim(),
          'description': _descriptionCtrl.text,
        },
      );
      ref.invalidate(_projectDetailProvider(widget.projectName));
      if (mounted) {
        setState(() {
          _isEditing = false;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete project?'),
        content: Text(
          'This removes "${Uri.decodeComponent(widget.projectName)}" and all daily activity stored on the server. '
          'Your agent can create the project again the next time it syncs.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await DashboardRepository(ref.read(apiClientProvider)).deleteProject(widget.projectName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project deleted')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detail = ref.watch(_projectDetailProvider(widget.projectName));

    return Scaffold(
      appBar: AppBar(
        title: Text(Uri.decodeComponent(widget.projectName)),
        actions: [
          if (_isEditing) ...[
            IconButton(
              tooltip: 'Cancel',
              icon: const Icon(Icons.close),
              onPressed: _saving
                  ? null
                  : () {
                      detail.whenData(_seedEditFields);
                      setState(() => _isEditing = false);
                    },
            ),
            IconButton(
              tooltip: 'Save',
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              onPressed: _saving ? null : _save,
            ),
          ] else
            detail.maybeWhen(
              data: (data) => Row(
                children: [
                  IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () {
                      _seedEditFields(data);
                      setState(() => _isEditing = true);
                    },
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline, color: AppColors.red),
                    onPressed: _confirmDelete,
                  ),
                ],
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryStart)),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(_projectDetailProvider(widget.projectName)),
        ),
        data: (data) => RefreshIndicator(
          color: AppColors.primaryStart,
          onRefresh: () async => ref.invalidate(_projectDetailProvider(widget.projectName)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MetricStrip(data: data, isDark: isDark),
              const SizedBox(height: 16),

              _DescriptionCard(
                data: data,
                isDark: isDark,
                isEditing: _isEditing,
                displayNameCtrl: _displayNameCtrl,
                descriptionCtrl: _descriptionCtrl,
              ),
              const SizedBox(height: 16),

              _TopAppsCard(
                rows: data.topApps,
                isDark: isDark,
                expanded: _appsExpanded,
                onToggle: () => setState(() => _appsExpanded = !_appsExpanded),
              ),
              const SizedBox(height: 16),

              _ContextCard(breakdown: data.contextBreakdown, isDark: isDark),
              const SizedBox(height: 16),

              _PerformanceCard(behavior: data.behavior, isDark: isDark),
              const SizedBox(height: 16),

              _LanguagesCard(languages: data.languages, isDark: isDark),
              const SizedBox(height: 16),

              _SkillsCard(skills: data.skills, isDark: isDark),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Top metric strip (4 cards) ───────────────────────────────────────────────

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.data, required this.isDark});
  final ProjectDetailResponse data;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // Horizontally scrollable strip — same approach the website uses. This
    // sidesteps the previous overflow caused by a fixed-aspect 2x2 GridView
    // and keeps the long "Last active" timestamp readable.
    final cards = <Widget>[
      _MetricStripCard(
        icon: Icons.access_time,
        label: 'Active hours',
        value: formatHours(data.appTimeHours),
        gradient: const [AppColors.primaryStart, AppColors.primaryEnd],
        isDark: isDark,
      ),
      _MetricStripCard(
        icon: Icons.code,
        label: 'Lines of code',
        value: _fmtNum(data.totalLines),
        gradient: const [Color(0xFF10B981), Color(0xFF0D9488)],
        isDark: isDark,
      ),
      _MetricStripCard(
        icon: Icons.insert_drive_file_outlined,
        label: 'Files',
        value: '${data.totalFiles}',
        gradient: const [Color(0xFFF59E0B), Color(0xFFEA580C)],
        isDark: isDark,
      ),
      _MetricStripCard(
        icon: Icons.event,
        label: 'Last active',
        value: _fmtLastActive(data.lastActive),
        gradient: const [AppColors.pink, AppColors.pinkLight],
        isDark: isDark,
      ),
    ];

    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => cards[i],
      ),
    );
  }
}

class _MetricStripCard extends StatelessWidget {
  const _MetricStripCard({
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
      width: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x0DFFFFFF) : const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0x33FFFFFF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
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

// ─── Description card (editable) ─────────────────────────────────────────────

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({
    required this.data,
    required this.isDark,
    required this.isEditing,
    required this.displayNameCtrl,
    required this.descriptionCtrl,
  });
  final ProjectDetailResponse data;
  final bool isDark, isEditing;
  final TextEditingController displayNameCtrl, descriptionCtrl;

  @override
  Widget build(BuildContext context) {
    final desc = data.description.trim();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Description', icon: Icons.description_outlined),
          const SizedBox(height: 4),
          Text(
            'Notes for this project (saved on the server).',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
            ),
          ),
          const SizedBox(height: 12),
          if (isEditing) ...[
            TextField(
              controller: displayNameCtrl,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: 'Display name',
                helperText: 'Sync name (unchanged): ${data.projectName}',
                helperMaxLines: 2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionCtrl,
              maxLength: 2000,
              maxLines: 4,
              minLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Short summary of what this project is…',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                alignLabelWithHint: true,
              ),
            ),
          ] else
            Text(
              desc.isNotEmpty ? desc : 'No description yet. Tap edit to add one.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                fontStyle: desc.isEmpty ? FontStyle.italic : FontStyle.normal,
                color: desc.isEmpty
                    ? (isDark ? const Color(0x88FFFFFF) : const Color(0x88000000))
                    : (isDark ? AppColors.darkText : AppColors.lightText),
              ),
            ),
          if (data.firstSeen != null && data.firstSeen!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'First seen ${_fmtFirstSeen(data.firstSeen)}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Top apps ────────────────────────────────────────────────────────────────

class _TopAppsCard extends StatelessWidget {
  const _TopAppsCard({
    required this.rows,
    required this.isDark,
    required this.expanded,
    required this.onToggle,
  });
  final List<ProjectNamedHoursRow> rows;
  final bool isDark;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final hasMore = rows.length > _kPreviewLimit;
    final visible = expanded || !hasMore ? rows : rows.take(_kPreviewLimit).toList();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Top apps', icon: Icons.apps),
          const SizedBox(height: 4),
          Text(
            'Time in each app while this project was active.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
            ),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            _Empty(
              icon: Icons.apps_outage,
              message: 'No app time recorded yet.',
              isDark: isDark,
            )
          else ...[
            ...visible.map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _StyledRow(
                    name: row.name,
                    percent: row.percent,
                    color: _appColor(row.name),
                    icon: _appIcon(row.name),
                    primary: formatHours(row.durationHours),
                    secondary: '${row.percent.toStringAsFixed(1)}% of app time',
                    isDark: isDark,
                  ),
                )),
            if (hasMore)
              Center(
                child: TextButton.icon(
                  onPressed: onToggle,
                  icon: Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18),
                  label: Text(
                    expanded
                        ? 'Show less'
                        : 'Show more (${rows.length - _kPreviewLimit} more)',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─── Context ─────────────────────────────────────────────────────────────────

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.breakdown, required this.isDark});
  final ProjectContextBreakdown breakdown;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final rows = <_ContextRow>[
      _ContextRow('Flow',          AppColors.chartFlow,          Icons.flash_on,         breakdown.flowHours),
      _ContextRow('Debugging',     AppColors.chartDebugging,     Icons.bug_report,       breakdown.debuggingHours),
      _ContextRow('Research',      AppColors.chartResearch,      Icons.menu_book,        breakdown.researchHours),
      _ContextRow('Communication', AppColors.chartCommunication, Icons.chat_bubble,      breakdown.communicationHours),
      _ContextRow('Distracted',    AppColors.chartDistracted,    Icons.do_not_disturb,   breakdown.distractedHours),
      _ContextRow('Other context', const Color(0xFF94A3B8),      Icons.more_horiz,       breakdown.otherHours),
    ];
    final total = rows.fold<double>(0, (a, r) => a + r.hours);
    final present = rows.where((r) => r.hours > 0).toList();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Context', icon: Icons.pie_chart_outline),
          const SizedBox(height: 4),
          Text(
            'Focus mix from synced context (seconds → m / s / h).',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
            ),
          ),
          const SizedBox(height: 12),
          if (total <= 0 || present.isEmpty)
            _Empty(
              icon: Icons.pie_chart_outline,
              message: 'No context breakdown for this project yet.',
              isDark: isDark,
            )
          else
            ...present.map((r) {
              final pct = total > 0 ? (r.hours / total) * 100 : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _StyledRow(
                  name: r.label,
                  percent: pct,
                  color: r.color,
                  icon: r.icon,
                  primary: formatHours(r.hours),
                  secondary: '${pct.toStringAsFixed(1)}% of context',
                  isDark: isDark,
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ─── Performance ─────────────────────────────────────────────────────────────

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({required this.behavior, required this.isDark});
  final ProjectBehaviorSummary behavior;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    String fmtRate(double v) => v > 0 ? v.toStringAsFixed(0) : '—';
    final tiles = <Widget>[
      _PerfTile(
        icon: Icons.keyboard_alt_outlined,
        label: 'KPM typing',
        value: fmtRate(behavior.avgTypingKpm),
        gradient: const [AppColors.primaryStart, AppColors.primaryEnd],
        isDark: isDark,
      ),
      _PerfTile(
        icon: Icons.mouse_outlined,
        label: 'CPM mouse',
        value: fmtRate(behavior.avgMouseCpm),
        gradient: const [AppColors.teal, AppColors.tealDark],
        isDark: isDark,
      ),
      _PerfTile(
        icon: Icons.access_time,
        label: 'Idle total',
        value: behavior.totalIdleHours > 0
            ? formatHours(behavior.totalIdleHours)
            : '—',
        gradient: const [AppColors.yellow, AppColors.yellowDark],
        isDark: isDark,
      ),
    ];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Performance', icon: Icons.speed),
          const SizedBox(height: 4),
          Text(
            'Typing & mouse rates weighted by context time; idle summed across days.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
            ),
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[0]),
                const SizedBox(width: 8),
                Expanded(child: tiles[1]),
                const SizedBox(width: 8),
                Expanded(child: tiles[2]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PerfTile extends StatelessWidget {
  const _PerfTile({
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x0DFFFFFF) : const Color(0x99FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0x33FFFFFF),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Languages (lines only — active-time variant skipped per design) ─────────

class _LanguagesCard extends StatelessWidget {
  const _LanguagesCard({required this.languages, required this.isDark});
  final List<ProjectLanguageShare> languages;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Languages', icon: Icons.code),
          const SizedBox(height: 4),
          Text(
            'Latest snapshot from project sync — lines per language.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
            ),
          ),
          const SizedBox(height: 12),
          if (languages.isEmpty)
            _Empty(
              icon: Icons.code_off,
              message: 'No language snapshot yet.',
              isDark: isDark,
            )
          else ...[
            LangBar(
              languages: languages
                  .map((l) => LangBarSegment(name: l.name, percent: l.percent / 100))
                  .toList(),
            ),
            const SizedBox(height: 14),
            ...languages.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _StyledRow(
                    name: l.name,
                    percent: l.percent,
                    color: LangBar.langColor(l.name),
                    icon: Icons.code,
                    primary: '${_fmtNum(l.lines)} lines',
                    secondary: '${l.percent.toStringAsFixed(1)}% of LOC',
                    isDark: isDark,
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

// ─── Skills ──────────────────────────────────────────────────────────────────

class _SkillsCard extends StatelessWidget {
  const _SkillsCard({required this.skills, required this.isDark});
  final List<ProjectSkillRow> skills;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final maxSec = skills.fold<double>(1, (a, s) => s.durationSec > a ? s.durationSec : a);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Skills in this project', icon: Icons.emoji_events),
          const SizedBox(height: 4),
          Text(
            'Merged by name — short sessions show as seconds or minutes.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
            ),
          ),
          const SizedBox(height: 12),
          if (skills.isEmpty)
            _Empty(
              icon: Icons.workspace_premium,
              message: 'No skill time recorded for this project yet.',
              isDark: isDark,
            )
          else
            ...skills.map((skill) {
              final pct = maxSec > 0 ? (skill.durationSec / maxSec) * 100 : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _StyledRow(
                  name: skill.name,
                  percent: pct,
                  color: _appColor(skill.name),
                  icon: Icons.code,
                  primary: formatSeconds(skill.durationSec),
                  secondary: 'vs longest skill in project',
                  isDark: isDark,
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ─── Reusable styled row (square + name + bar + right value) ─────────────────

class _StyledRow extends StatelessWidget {
  const _StyledRow({
    required this.name,
    required this.percent,
    required this.color,
    required this.icon,
    required this.primary,
    required this.secondary,
    required this.isDark,
  });
  final String name, primary, secondary;
  final double percent;
  final Color color;
  final IconData icon;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x08FFFFFF) : const Color(0x66FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x14FFFFFF) : const Color(0x33FFFFFF),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.78)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          primary,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          secondary,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? AppColors.darkSecondaryText
                                : AppColors.lightSecondaryText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (percent / 100).clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor:
                        isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(icon, size: 36, color: isDark ? const Color(0x66FFFFFF) : const Color(0x66000000)),
          const SizedBox(height: 10),
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
