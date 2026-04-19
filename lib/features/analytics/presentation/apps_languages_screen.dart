import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/error_state.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/lang_bar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/data/models/dashboard_models.dart';

// ─── Period config ────────────────────────────────────────────────────────────

const _kPeriods = [
  ('week',    'This week',     '7d'),
  ('month',   'Last month',    '30d'),
  ('90days',  'Last 90 days',  '90d'),
  ('6months', 'Last 6 months', '6mo'),
];

/// Mirrors the website's collapse threshold so both surfaces feel consistent.
const _kPreviewLimit = 6;

String _priorLabel(String period) {
  switch (period) {
    case 'month':   return 'prior month';
    case '90days':  return 'prior 90d';
    case '6months': return 'prior 6mo';
    default:        return 'prior week';
  }
}

String _chartTitle(String period) {
  switch (period) {
    case '6months': return 'Monthly app hours';
    case 'week':    return 'Daily app hours';
    default:        return 'Weekly app hours';
  }
}

/// Stable colors for category names. Mirrors `AppLanguagesDetailPage.tsx`
/// so the same category renders in the same colour on web and mobile.
const _kCategoryColors = <String, Color>{
  'Development':   Color(0xFF5B6FD8),
  'Browser':       Color(0xFF4285F4),
  'Design':        Color(0xFFF24E1E),
  'Communication': Color(0xFF7C3AED),
  'Productivity':  Color(0xFF9B59B6),
  'Other':         Color(0xFF6B7280),
};

const _kAppColorPalette = <Color>[
  Color(0xFF5B6FD8),
  Color(0xFF4ECDC4),
  Color(0xFFFB542B),
  Color(0xFFFF6B9D),
  Color(0xFFFFD93D),
  Color(0xFF9B59B6),
  Color(0xFF25D366),
  Color(0xFF0078D4),
  Color(0xFF00ED64),
];

int _hashString(String s) {
  var hash = 0;
  for (var i = 0; i < s.length; i++) {
    hash = (hash << 5) - hash + s.codeUnitAt(i);
    hash &= 0xFFFFFFFF;
  }
  return hash.abs();
}

Color _appColor(String name) =>
    _kAppColorPalette[_hashString(name) % _kAppColorPalette.length];

Color _categoryColor(String name) =>
    _kCategoryColors[name] ?? _appColor(name);

String _formatLoc(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final _detailProvider = FutureProvider.family<ToolUsageDetailResponse, String>((ref, period) {
  return DashboardRepository(ref.watch(apiClientProvider)).getToolUsageDetail(period: period);
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class AppsLanguagesScreen extends ConsumerStatefulWidget {
  const AppsLanguagesScreen({super.key});

  @override
  ConsumerState<AppsLanguagesScreen> createState() => _AppsLanguagesScreenState();
}

class _AppsLanguagesScreenState extends ConsumerState<AppsLanguagesScreen> {
  String _period = 'week';
  bool _appsExpanded = false;
  bool _languagesExpanded = false;

  void _setPeriod(String p) {
    setState(() {
      _period = p;
      // Resetting expansion when the dataset changes avoids leaving the user
      // staring at an "expanded" state that doesn't match the new top-N.
      _appsExpanded = false;
      _languagesExpanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detail = ref.watch(_detailProvider(_period));

    final periodLabel = _kPeriods.firstWhere((p) => p.$1 == _period).$2;
    final periodShort = _kPeriods.firstWhere((p) => p.$1 == _period).$3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apps & Languages'),
        actions: [
          _PeriodDropdown(period: _period, isDark: isDark, onChanged: _setPeriod),
          const SizedBox(width: 8),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryStart)),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(_detailProvider(_period)),
        ),
        data: (data) => RefreshIndicator(
          color: AppColors.primaryStart,
          onRefresh: () async => ref.invalidate(_detailProvider(_period)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '$periodLabel · app activity  ·  languages are all-time',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                  ),
                ),
              ),

              _buildSummaryGrid(data, isDark, periodShort),
              const SizedBox(height: 16),

              // Bar chart (only when there's at least one non-zero day)
              if (data.dailyAppUsage.any((d) => d.totalHours > 0)) ...[
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(title: _chartTitle(_period), icon: Icons.bar_chart),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 160,
                        child: _AppUsageChart(daily: data.dailyAppUsage, isDark: isDark),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Categories pie chart
              if (data.categoryBreakdown.any((c) => c.hours > 0)) ...[
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Usage by category', icon: Icons.pie_chart),
                      const SizedBox(height: 8),
                      Text(
                        '$periodLabel · grouped by inferred category',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _CategoryPie(
                        categories: data.categoryBreakdown.where((c) => c.hours > 0).toList(),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Top Apps with show more
              _AppsList(
                apps: data.topApps.apps,
                period: _period,
                periodShort: periodShort,
                isDark: isDark,
                expanded: _appsExpanded,
                onToggle: () => setState(() => _appsExpanded = !_appsExpanded),
              ),
              const SizedBox(height: 16),

              // Languages with show more
              _LanguagesList(
                languages: data.languageDistribution.languages,
                totalFiles: data.languageDistribution.summary.totalFiles,
                isDark: isDark,
                expanded: _languagesExpanded,
                onToggle: () => setState(() => _languagesExpanded = !_languagesExpanded),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryGrid(ToolUsageDetailResponse data, bool isDark, String shortLabel) {
    final pct = data.vsPriorPeriodPercent;
    final pctColor = pct >= 0
        ? (isDark ? AppColors.teal : const Color(0xFF16A34A))
        : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626));
    final summary = data.languageDistribution.summary;

    // Two rows of two cards. We hand-build the rows (instead of GridView)
    // because nesting GridView inside a ListView requires shrinkWrap +
    // NeverScrollable and fights the parent scroll on Android.
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.access_time,
                label: 'Active time ($shortLabel)',
                value: '${data.topApps.totalUsageHours.toStringAsFixed(1)}h',
                sub: '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(0)}% vs ${_priorLabel(_period)}',
                subColor: pctColor,
                gradient: const [AppColors.primaryStart, AppColors.primaryEnd],
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.apps,
                label: 'Apps used',
                value: '${data.uniqueAppsCount}',
                gradient: const [AppColors.teal, AppColors.tealDark],
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.timeline,
                label: 'Lines of code',
                value: _formatLoc(summary.totalLinesOfCode),
                gradient: const [AppColors.yellow, AppColors.yellowDark],
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.code,
                label: 'Languages',
                value: '${summary.totalLanguagesUsed}',
                gradient: const [AppColors.pink, AppColors.pinkLight],
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Period dropdown ──────────────────────────────────────────────────────────

class _PeriodDropdown extends StatelessWidget {
  const _PeriodDropdown({required this.period, required this.isDark, required this.onChanged});
  final String period;
  final bool isDark;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = _kPeriods.firstWhere((p) => p.$1 == period).$2;
    return PopupMenuButton<String>(
      initialValue: period,
      onSelected: onChanged,
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark ? const Color(0xFF1F2937) : Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          color: isDark ? Colors.white.withAlpha(13) : Colors.black.withAlpha(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 16, color: isDark ? Colors.white70 : Colors.black54),
          ],
        ),
      ),
      itemBuilder: (_) => _kPeriods
          .map((p) => PopupMenuItem<String>(
                value: p.$1,
                child: Text(
                  p.$2,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: p.$1 == period ? FontWeight.bold : FontWeight.normal,
                    color: p.$1 == period
                        ? AppColors.primaryStart
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

// ─── App usage bar chart ──────────────────────────────────────────────────────

class _AppUsageChart extends StatelessWidget {
  const _AppUsageChart({required this.daily, required this.isDark});
  final List<DailyAppUsage> daily;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final maxH = daily.map((d) => d.totalHours).fold(0.0, (a, b) => a > b ? a : b);
    final labelColor = isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: daily.map((d) {
        final ratio = maxH > 0 ? d.totalHours / maxH : 0.0;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (d.totalHours > 0)
                  Text(d.totalHours.toStringAsFixed(1),
                      style: TextStyle(fontSize: 8, color: labelColor)),
                const SizedBox(height: 2),
                Expanded(
                  child: FractionallySizedBox(
                    alignment: Alignment.bottomCenter,
                    heightFactor: ratio.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryStart, AppColors.primaryEnd],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(d.dayName, style: TextStyle(fontSize: 9, color: labelColor)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Category pie chart ──────────────────────────────────────────────────────

class _CategoryPie extends StatefulWidget {
  const _CategoryPie({required this.categories, required this.isDark});
  final List<AppCategoryUsage> categories;
  final bool isDark;

  @override
  State<_CategoryPie> createState() => _CategoryPieState();
}

class _CategoryPieState extends State<_CategoryPie> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response == null ||
                        response.touchedSection == null) {
                      _touchedIndex = null;
                      return;
                    }
                    _touchedIndex = response.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: List.generate(widget.categories.length, (i) {
                final cat = widget.categories[i];
                final isTouched = i == _touchedIndex;
                final radius = isTouched ? 76.0 : 64.0;
                return PieChartSectionData(
                  value: cat.hours,
                  color: _categoryColor(cat.category),
                  title: '${cat.percentOfTotal.toStringAsFixed(0)}%',
                  radius: radius,
                  titleStyle: TextStyle(
                    fontSize: isTouched ? 13 : 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    shadows: const [Shadow(color: Color(0x66000000), blurRadius: 2)],
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: widget.categories.map((cat) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _categoryColor(cat.category),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${cat.category} · ${cat.hours.toStringAsFixed(1)}h',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isDark
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
}

// ─── Top apps list ───────────────────────────────────────────────────────────

class _AppsList extends StatelessWidget {
  const _AppsList({
    required this.apps,
    required this.period,
    required this.periodShort,
    required this.isDark,
    required this.expanded,
    required this.onToggle,
  });
  final List<AppUsageItem> apps;
  final String period;
  final String periodShort;
  final bool isDark;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final visible = expanded ? apps : apps.take(_kPreviewLimit).toList();
    final hasMore = apps.length > _kPreviewLimit;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Top Apps',
            icon: Icons.apps,
            trailing: Text(
              periodShort,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (apps.isEmpty)
            _EmptySection(
              icon: Icons.apps_outage,
              message: 'No app activity recorded for this period.',
              isDark: isDark,
            )
          else ...[
            ...visible.map((app) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _AppRow(
                    app: app,
                    period: period,
                    periodShort: periodShort,
                    isDark: isDark,
                  ),
                )),
            if (hasMore)
              Center(
                child: TextButton.icon(
                  onPressed: onToggle,
                  icon: Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                  label: Text(
                    expanded
                        ? 'Show less'
                        : 'View more (${apps.length - _kPreviewLimit} more)',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.app,
    required this.period,
    required this.periodShort,
    required this.isDark,
  });
  final AppUsageItem app;
  final String period;
  final String periodShort;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = _appColor(app.name);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? color.withAlpha(40) : color.withAlpha(28),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      app.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${app.durationHours.toStringAsFixed(1)}h',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _ChangeBadge(
                    value: app.changePercent,
                    priorLabel: _priorLabel(period),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${app.percentOfTotal.toStringAsFixed(1)}% of $periodShort',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkSecondaryText
                            : AppColors.lightSecondaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (app.percentOfTotal / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor:
                      isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Languages list ──────────────────────────────────────────────────────────

class _LanguagesList extends StatelessWidget {
  const _LanguagesList({
    required this.languages,
    required this.totalFiles,
    required this.isDark,
    required this.expanded,
    required this.onToggle,
  });
  final List<LanguageItem> languages;
  final int totalFiles;
  final bool isDark;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final visible = expanded ? languages : languages.take(_kPreviewLimit).toList();
    final hasMore = languages.length > _kPreviewLimit;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Languages',
            icon: Icons.code,
            trailing: Text(
              'All time',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$totalFiles files · top languages by lines of code',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
            ),
          ),
          const SizedBox(height: 12),
          if (languages.isEmpty)
            _EmptySection(
              icon: Icons.code_off,
              message: 'No language data yet. Start coding and sync your projects.',
              isDark: isDark,
            )
          else ...[
            LangBar(
              languages: languages
                  .map((l) => LangBarSegment(name: l.name, percent: l.percent / 100))
                  .toList(),
            ),
            const SizedBox(height: 14),
            ...visible.map((lang) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LanguageRow(lang: lang, isDark: isDark),
                )),
            if (hasMore)
              Center(
                child: TextButton.icon(
                  onPressed: onToggle,
                  icon: Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                  label: Text(
                    expanded
                        ? 'Show less'
                        : 'View more (${languages.length - _kPreviewLimit} more)',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.lang, required this.isDark});
  final LanguageItem lang;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final c = LangBar.langColor(lang.name);
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDark ? c.withAlpha(40) : c.withAlpha(28),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.code, size: 18, color: c),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      lang.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${lang.percent.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkSecondaryText
                          : AppColors.lightSecondaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (lang.percent / 100).clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor:
                      isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation(c),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${_formatLoc(lang.loc)} lines · ${lang.files} files',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? AppColors.darkSecondaryText
                      : AppColors.lightSecondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    required this.gradient,
    this.sub,
    this.subColor,
  });
  final IconData icon;
  final String label, value;
  final bool isDark;
  final List<Color> gradient;
  final String? sub;
  final Color? subColor;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkSecondaryText
                        : AppColors.lightSecondaryText,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(
              sub!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: subColor ??
                    (isDark
                        ? AppColors.darkSecondaryText
                        : AppColors.lightSecondaryText),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.icon, required this.message, required this.isDark});
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

class _ChangeBadge extends StatelessWidget {
  const _ChangeBadge({required this.value, required this.priorLabel, required this.isDark});
  final double value;
  final String priorLabel;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final up = value >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: up
            ? (isDark ? AppColors.teal.withAlpha(40) : const Color(0xFFDCFCE7))
            : (isDark ? const Color(0x28F87171) : const Color(0xFFFEE2E2)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${up ? '+' : ''}${value.toStringAsFixed(0)}% vs $priorLabel',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: up
              ? (isDark ? AppColors.teal : const Color(0xFF16A34A))
              : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
        ),
      ),
    );
  }
}
