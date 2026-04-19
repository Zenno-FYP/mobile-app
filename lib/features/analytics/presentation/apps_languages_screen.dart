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
          _PeriodDropdown(
            period: _period,
            isDark: isDark,
            onChanged: (p) {
              setState(() => _period = p);
            },
          ),
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
              // ── Subtitle ──────────────────────────────────────────────────
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

              // ── Summary cards ─────────────────────────────────────────────
              _buildSummaryRow(data, isDark, periodShort),
              const SizedBox(height: 16),

              // ── Daily/Weekly/Monthly chart ─────────────────────────────────
              if (data.dailyAppUsage.isNotEmpty)
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: _chartTitle(_period),
                        icon: Icons.bar_chart,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 160,
                        child: _AppUsageChart(
                          daily: data.dailyAppUsage,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // ── Top Apps ──────────────────────────────────────────────────
              GlassCard(
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
                    Text(
                      '${data.uniqueAppsCount} apps  ·  ${data.topApps.totalUsageHours.toStringAsFixed(1)}h total',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...data.topApps.apps.map((app) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(app.name, style: const TextStyle(fontSize: 14))),
                                  const SizedBox(width: 8),
                                  _ChangeBadge(value: app.changePercent, priorLabel: _priorLabel(_period), isDark: isDark),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${app.durationHours.toStringAsFixed(1)}h',
                                    style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: app.percentOfTotal / 100,
                                  minHeight: 6,
                                  backgroundColor: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB),
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

              // ── Categories ────────────────────────────────────────────────
              if (data.categoryBreakdown.isNotEmpty)
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Categories', icon: Icons.category),
                      const SizedBox(height: 12),
                      ...data.categoryBreakdown.map((cat) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(child: Text(cat.category, style: const TextStyle(fontSize: 14))),
                                Text(
                                  '${cat.hours.toStringAsFixed(1)}h  (${cat.percentOfTotal.toStringAsFixed(0)}%)',
                                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // ── Languages (all-time) ───────────────────────────────────────
              GlassCard(
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
                    const SizedBox(height: 12),
                    LangBar(
                      languages: data.languageDistribution.languages
                          .map((l) => LangBarSegment(name: l.name, percent: l.percent / 100))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    ...data.languageDistribution.languages.map((lang) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: LangBar.langColor(lang.name),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(lang.name, style: const TextStyle(fontSize: 14))),
                              Text(
                                '${lang.percent.toStringAsFixed(1)}%  ${_formatLoc(lang.loc)}',
                                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                              ),
                            ],
                          ),
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

  Widget _buildSummaryRow(ToolUsageDetailResponse data, bool isDark, String shortLabel) {
    final pct = data.vsPriorPeriodPercent;
    final pctColor = pct >= 0
        ? (isDark ? AppColors.teal : const Color(0xFF16A34A))
        : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626));

    return Row(
      children: [
        _StatCard(
          icon: Icons.access_time,
          label: 'Active ($shortLabel)',
          value: '${data.topApps.totalUsageHours.toStringAsFixed(1)}h',
          sub: '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(0)}% vs ${_priorLabel(_period)}',
          subColor: pctColor,
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        _StatCard(
          icon: Icons.apps,
          label: 'Apps used',
          value: '${data.uniqueAppsCount}',
          isDark: isDark,
        ),
      ],
    );
  }

  String _formatLoc(int loc) {
    if (loc >= 1000) return '${(loc / 1000).toStringAsFixed(1)}K';
    return '$loc';
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
                  Text(
                    d.totalHours.toStringAsFixed(1),
                    style: TextStyle(fontSize: 8, color: labelColor),
                  ),
                const SizedBox(height: 2),
                FractionallySizedBox(
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

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.sub,
    this.subColor,
  });
  final IconData icon;
  final String label, value;
  final bool isDark;
  final String? sub;
  final Color? subColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primaryStart, AppColors.primaryEnd]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                  if (sub != null)
                    Text(sub!, style: TextStyle(fontSize: 10, color: subColor ?? (isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText))),
                ],
              ),
            ),
          ],
        ),
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
          color: up
              ? (isDark ? AppColors.teal : const Color(0xFF16A34A))
              : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
        ),
      ),
    );
  }
}
