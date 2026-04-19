import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/format_duration.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../core/widgets/error_state.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/data/models/dashboard_models.dart';
import '../../dashboard/presentation/widgets/developer_trends_chart.dart';

// ─── Period config ──────────────────────────────────────────────────────────

typedef _PeriodEntry = ({String value, String label, String compare});
const List<_PeriodEntry> _kPeriods = [
  (value: 'week',    label: 'This week',     compare: 'vs prior week'),
  (value: 'month',   label: 'Last month',    compare: 'vs prior month'),
  (value: '90days',  label: 'Last 90 days',  compare: 'vs prior 90 days'),
  (value: '6months', label: 'Last 6 months', compare: 'vs prior 6 months'),
];

// ─── Trend filter config ─────────────────────────────────────────────────────

typedef _FilterEntry = ({String value, String label, Color color});
const List<_FilterEntry> _kFilters = [
  (value: 'all',           label: 'All',           color: AppColors.primaryStart),
  (value: 'flow',          label: 'Flow',          color: AppColors.chartFlow),
  (value: 'debugging',     label: 'Debugging',     color: AppColors.chartDebugging),
  (value: 'research',      label: 'Research',      color: AppColors.chartResearch),
  (value: 'communication', label: 'Communication', color: AppColors.chartCommunication),
  (value: 'distracted',    label: 'Distracted',    color: AppColors.chartDistracted),
];

// ─── Breakdown grouping ──────────────────────────────────────────────────────

/// Duration-weighted mean of a numeric field over a set of days.
///
/// KPM/CPM/correction% are rates, so a plain arithmetic mean would weight a
/// 30-minute coding day equally with an 8-hour day. We weight by
/// `activeHours` to match the backend's window aggregation.
double _weightedAvgByActiveHours(
  List<DailyBehaviorMetrics> days,
  double Function(DailyBehaviorMetrics d) pick,
) {
  double weight = 0;
  double weighted = 0;
  for (final d in days) {
    final w = d.activeHours;
    if (w <= 0) continue;
    weight += w;
    weighted += pick(d) * w;
  }
  return weight > 0 ? weighted / weight : 0;
}

class _BreakdownRow {
  _BreakdownRow({
    required this.label,
    required this.sublabel,
    required this.kpm,
    required this.cpm,
    required this.correction,
    required this.activeHours,
    required this.idleHours,
  });
  final String label, sublabel;
  final double kpm, cpm, correction, activeHours, idleHours;
}

List<_BreakdownRow> _buildBreakdownRows(
  List<DailyBehaviorMetrics> daily,
  String period,
) {
  if (period == 'week') {
    return daily
        .map((d) => _BreakdownRow(
              label: d.dayName,
              sublabel: d.date,
              kpm: d.typingIntensityKpm,
              cpm: d.mouseClickRateCpm,
              correction: d.correctionRatePercent,
              activeHours: d.activeHours,
              idleHours: d.idleHours,
            ))
        .toList();
  }

  if (period == 'month' || period == '90days') {
    final rows = <_BreakdownRow>[];
    for (int i = 0; i < daily.length; i += 7) {
      final chunk = daily.sublist(i, min(i + 7, daily.length));
      // Rates are duration-weighted; hours are absolute totals.
      rows.add(_BreakdownRow(
        label: 'Wk ${i ~/ 7 + 1}',
        sublabel: '${chunk.first.date} – ${chunk.last.date}',
        kpm: _weightedAvgByActiveHours(chunk, (d) => d.typingIntensityKpm),
        cpm: _weightedAvgByActiveHours(chunk, (d) => d.mouseClickRateCpm),
        correction:
            _weightedAvgByActiveHours(chunk, (d) => d.correctionRatePercent),
        activeHours: chunk.map((d) => d.activeHours).reduce((a, b) => a + b),
        idleHours: chunk.map((d) => d.idleHours).reduce((a, b) => a + b),
      ));
    }
    return rows;
  }

  // 6months → group by calendar month
  final monthMap = <String, List<DailyBehaviorMetrics>>{};
  for (final d in daily) {
    monthMap.putIfAbsent(d.date.substring(0, 7), () => []).add(d);
  }
  const monthNames = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];
  return monthMap.entries.map((e) {
    final parts = e.key.split('-');
    final days = e.value;
    return _BreakdownRow(
      label: '${monthNames[int.parse(parts[1]) - 1]} ${parts[0]}',
      sublabel: '${days.length} days',
      kpm: _weightedAvgByActiveHours(days, (d) => d.typingIntensityKpm),
      cpm: _weightedAvgByActiveHours(days, (d) => d.mouseClickRateCpm),
      correction:
          _weightedAvgByActiveHours(days, (d) => d.correctionRatePercent),
      activeHours: days.map((d) => d.activeHours).reduce((a, b) => a + b),
      idleHours: days.map((d) => d.idleHours).reduce((a, b) => a + b),
    );
  }).toList();
}

String _breakdownTitle(String period) {
  if (period == 'week')    return 'Daily Details';
  if (period == '6months') return 'Monthly Details';
  return 'Weekly Details';
}

// ─── Provider ────────────────────────────────────────────────────────────────

final _detailProvider =
    FutureProvider.family<PerformanceMetricsDetailResponse, String>((ref, period) {
  return DashboardRepository(ref.watch(apiClientProvider))
      .getPerformanceMetricsDetail(period: period);
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class MetricsDetailScreen extends ConsumerStatefulWidget {
  const MetricsDetailScreen({super.key});

  @override
  ConsumerState<MetricsDetailScreen> createState() => _MetricsDetailScreenState();
}

class _MetricsDetailScreenState extends ConsumerState<MetricsDetailScreen> {
  String _period = 'week';
  String _trendFilter = 'all';

  void _setPeriod(String v) => setState(() { _period = v; _trendFilter = 'all'; });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detail = ref.watch(_detailProvider(_period));
    final periodEntry = _kPeriods.firstWhere((p) => p.value == _period);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Metrics'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _PeriodDropdown(
              period: _period,
              isDark: isDark,
              onChanged: _setPeriod,
            ),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryStart)),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(_detailProvider(_period)),
        ),
        data: (data) {
          final s = data.performanceSummary;
          final breakdownRows = _buildBreakdownRows(data.dailySeries, _period);

          return RefreshIndicator(
            color: AppColors.primaryStart,
            onRefresh: () async => ref.invalidate(_detailProvider(_period)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Period subtitle
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${periodEntry.label} overview — ${periodEntry.compare}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkSecondaryText
                          : AppColors.lightSecondaryText,
                    ),
                  ),
                ),

                // Summary metrics grid
                GlassCard(
                  child: Column(
                    children: [
                      const SectionHeader(title: 'Summary', icon: Icons.speed),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.3,
                        children: [
                          MetricTile(
                            icon: Icons.keyboard,
                            label: 'Typing (KPM)',
                            value: s.avgTypingIntensity.value.toStringAsFixed(1),
                            changePercent: s.avgTypingIntensity.changePercent,
                          ),
                          MetricTile(
                            icon: Icons.access_time,
                            label: 'Active hrs/day',
                            value: s.dailyActiveAverage.value.toStringAsFixed(1),
                            changePercent: s.dailyActiveAverage.changePercent,
                            gradient: const LinearGradient(
                                colors: [AppColors.teal, AppColors.tealDark]),
                          ),
                          MetricTile(
                            icon: Icons.mouse,
                            label: 'Mouse (CPM)',
                            value: s.avgMouseClickRate.value.toStringAsFixed(1),
                            changePercent: s.avgMouseClickRate.changePercent,
                            gradient: const LinearGradient(
                                colors: [AppColors.yellow, AppColors.yellowDark]),
                          ),
                          MetricTile(
                            icon: Icons.backspace_outlined,
                            label: 'Corrections',
                            value:
                                '${s.avgCorrections.value.toStringAsFixed(1)}%',
                            changePercent: s.avgCorrections.changePercent,
                            gradient: const LinearGradient(
                                colors: [AppColors.pink, AppColors.pinkLight]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Developer Trends with filter chips
                if (data.usageTrendGraph.isNotEmpty) ...[
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                          title: 'Developer Trends',
                          icon: Icons.show_chart,
                        ),
                        const SizedBox(height: 10),
                        // Filter chips — scrollable row
                        SizedBox(
                          height: 32,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: _kFilters.map((f) {
                              final selected = _trendFilter == f.value;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _trendFilter = f.value),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      color: selected
                                          ? f.color.withValues(alpha: 0.15)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: selected
                                            ? f.color.withValues(alpha: 0.7)
                                            : (isDark
                                                ? const Color(0x33FFFFFF)
                                                : const Color(0x33000000)),
                                        width: selected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Text(
                                      '● ${f.label}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: selected
                                            ? f.color
                                            : (isDark
                                                ? AppColors.darkSecondaryText
                                                : AppColors.lightSecondaryText),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 200,
                          child: DeveloperTrendsChart(
                            data: data.usageTrendGraph,
                            filter: _trendFilter,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Typing & click intensity bar chart (grouped by period)
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: 'Typing & click intensity',
                        icon: Icons.bar_chart,
                        trailing: Text(
                          _period == 'week'
                              ? 'Daily · KPM & CPM'
                              : _period == '6months'
                                  ? 'Monthly · KPM & CPM'
                                  : 'Weekly · KPM & CPM',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkSecondaryText
                                : AppColors.lightSecondaryText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: _DailyChart(
                          points: _groupChartData(data.dailySeries, _period),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Grouped breakdown list
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: _breakdownTitle(_period),
                        icon: Icons.list_alt,
                        trailing: Text(
                          '${breakdownRows.length} ${_period == '6months' ? 'months' : _period == 'week' ? 'days' : 'weeks'}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkSecondaryText
                                : AppColors.lightSecondaryText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...breakdownRows.map((row) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 52,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(row.label,
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? AppColors.darkText
                                                  : AppColors.lightText)),
                                      Text(
                                        row.sublabel.length > 8
                                            ? row.sublabel
                                                .split(' ')
                                                .first
                                            : row.sublabel,
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: isDark
                                                ? AppColors.darkSecondaryText
                                                : AppColors.lightSecondaryText),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Active: ${formatHours(row.activeHours)}  Idle: ${formatHours(row.idleHours)}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'KPM: ${row.kpm.toStringAsFixed(0)}  CPM: ${row.cpm.toStringAsFixed(0)}  Corr: ${row.correction.toStringAsFixed(1)}%',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? AppColors.darkSecondaryText
                                                : AppColors.lightSecondaryText),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

}

// ─── Period dropdown ──────────────────────────────────────────────────────────

class _PeriodDropdown extends StatelessWidget {
  const _PeriodDropdown({
    required this.period,
    required this.isDark,
    required this.onChanged,
  });

  final String period;
  final bool isDark;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0x33FFFFFF) : const Color(0x33000000),
        ),
        color: isDark ? const Color(0x0DFFFFFF) : const Color(0x0D000000),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: period,
          isDense: true,
          icon: const Icon(Icons.expand_more, size: 16),
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white : Colors.black87,
          ),
          dropdownColor: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: _kPeriods
              .map((p) => DropdownMenuItem(value: p.value, child: Text(p.label)))
              .toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}

// ─── Chart grouping ───────────────────────────────────────────────────────────

class _ChartPoint {
  _ChartPoint({required this.label, required this.kpm, required this.cpm});
  final String label;
  final double kpm, cpm;
}

List<_ChartPoint> _groupChartData(List<DailyBehaviorMetrics> daily, String period) {
  if (period == 'week') {
    return daily
        .map((d) => _ChartPoint(
              label: d.dayName,
              kpm: d.typingIntensityKpm,
              cpm: d.mouseClickRateCpm,
            ))
        .toList();
  }

  if (period == 'month' || period == '90days') {
    final result = <_ChartPoint>[];
    for (int i = 0; i < daily.length; i += 7) {
      final chunk = daily.sublist(i, min(i + 7, daily.length));
      result.add(_ChartPoint(
        label: 'Wk ${i ~/ 7 + 1}',
        kpm: _weightedAvgByActiveHours(chunk, (d) => d.typingIntensityKpm),
        cpm: _weightedAvgByActiveHours(chunk, (d) => d.mouseClickRateCpm),
      ));
    }
    return result;
  }

  // 6months → group by calendar month
  final monthMap = <String, List<DailyBehaviorMetrics>>{};
  for (final d in daily) {
    monthMap.putIfAbsent(d.date.substring(0, 7), () => []).add(d);
  }
  const monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return monthMap.entries.map((e) {
    final parts = e.key.split('-');
    final days = e.value;
    return _ChartPoint(
      label: monthNames[int.parse(parts[1]) - 1],
      kpm: _weightedAvgByActiveHours(days, (d) => d.typingIntensityKpm),
      cpm: _weightedAvgByActiveHours(days, (d) => d.mouseClickRateCpm),
    );
  }).toList();
}

// ─── KPM / CPM grouped bar chart ─────────────────────────────────────────────

class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.points, required this.isDark});
  final List<_ChartPoint> points;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const Center(child: Text('No data'));

    // Narrow bars for many groups (90-day weekly = ~13 groups)
    final bw = points.length > 12 ? 5.0 : points.length > 7 ? 7.0 : 10.0;

    return BarChart(
      BarChartData(
        groupsSpace: 4,
        barGroups: List.generate(points.length, (i) {
          final p = points[i];
          return BarChartGroupData(
            x: i,
            barsSpace: 2,
            barRods: [
              BarChartRodData(
                toY: p.kpm,
                width: bw,
                color: AppColors.primaryStart,
                borderRadius: BorderRadius.circular(3),
              ),
              BarChartRodData(
                toY: p.cpm,
                width: bw,
                color: AppColors.teal,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
          );
        }),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    points[idx].label,
                    style: TextStyle(
                      fontSize: 9,
                      color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, rodIndex) {
              final p = points[group.x];
              final label = rodIndex == 0 ? 'KPM: ${p.kpm.toStringAsFixed(1)}' : 'CPM: ${p.cpm.toStringAsFixed(1)}';
              return BarTooltipItem(label, const TextStyle(fontSize: 11, color: Colors.white));
            },
          ),
        ),
      ),
    );
  }
}
