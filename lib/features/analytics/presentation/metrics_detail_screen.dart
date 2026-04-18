import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../core/widgets/error_state.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/data/models/dashboard_models.dart';

final _detailProvider = FutureProvider<PerformanceMetricsDetailResponse>((ref) {
  return DashboardRepository(ref.watch(apiClientProvider)).getPerformanceMetricsDetail();
});

class MetricsDetailScreen extends ConsumerWidget {
  const MetricsDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detail = ref.watch(_detailProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Performance Metrics')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryStart)),
        error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(_detailProvider)),
        data: (data) {
          final s = data.performanceSummary;
          return RefreshIndicator(
            color: AppColors.primaryStart,
            onRefresh: () async => ref.invalidate(_detailProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
                            icon: Icons.keyboard, label: 'Typing (KPM)',
                            value: s.avgTypingIntensity.value.toStringAsFixed(1),
                            changePercent: s.avgTypingIntensity.changePercent,
                          ),
                          MetricTile(
                            icon: Icons.access_time, label: 'Active hrs/day',
                            value: s.dailyActiveAverage.value.toStringAsFixed(1),
                            changePercent: s.dailyActiveAverage.changePercent,
                            gradient: const LinearGradient(colors: [AppColors.teal, AppColors.tealDark]),
                          ),
                          MetricTile(
                            icon: Icons.mouse, label: 'Mouse (CPM)',
                            value: s.avgMouseClickRate.value.toStringAsFixed(1),
                            changePercent: s.avgMouseClickRate.changePercent,
                            gradient: const LinearGradient(colors: [AppColors.yellow, AppColors.yellowDark]),
                          ),
                          MetricTile(
                            icon: Icons.backspace_outlined, label: 'Corrections',
                            value: '${s.avgCorrections.value.toStringAsFixed(1)}%',
                            changePercent: s.avgCorrections.changePercent,
                            gradient: const LinearGradient(colors: [AppColors.pink, AppColors.pinkLight]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Daily Breakdown', icon: Icons.bar_chart),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: _DailyChart(series: data.dailySeries, isDark: isDark),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Daily Details', icon: Icons.list_alt),
                      const SizedBox(height: 12),
                      ...data.dailySeries.map((d) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 36,
                                  child: Text(d.dayName, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Active: ${d.activeHours.toStringAsFixed(1)}h  Idle: ${d.idleHours.toStringAsFixed(1)}h',
                                          style: const TextStyle(fontSize: 13)),
                                      const SizedBox(height: 2),
                                      Text('KPM: ${d.typingIntensityKpm.toStringAsFixed(0)}  CPM: ${d.mouseClickRateCpm.toStringAsFixed(0)}  Corrections: ${d.correctionRatePercent.toStringAsFixed(1)}%',
                                          style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
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

class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.series, required this.isDark});
  final List<DailyBehaviorMetrics> series;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return const Center(child: Text('No data'));

    return BarChart(
      BarChartData(
        barGroups: List.generate(series.length, (i) {
          final d = series[i];
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: d.activeHours,
              width: 16,
              borderRadius: BorderRadius.circular(4),
              gradient: AppColors.primaryGradient,
            ),
          ]);
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
                if (idx < 0 || idx >= series.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(series[idx].dayName, style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barTouchData: BarTouchData(enabled: false),
      ),
    );
  }
}
