import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/format_duration.dart';
import '../../data/models/dashboard_models.dart';

class DeveloperTrendsChart extends StatelessWidget {
  const DeveloperTrendsChart({
    super.key,
    required this.data,
    this.filter = 'all',
  });

  final List<UsageTrendBar> data;

  /// One of: 'all', 'flow', 'debugging', 'research', 'communication', 'distracted'
  final String filter;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (data.isEmpty) {
      return Center(
        child: Text(
          'No trend data available',
          style: TextStyle(
            color: isDark
                ? AppColors.darkSecondaryText
                : AppColors.lightSecondaryText,
          ),
        ),
      );
    }

    final visibleSeries = _visibleSeries();
    final maxValue = visibleSeries
        .expand((s) => s.values)
        .fold<double>(0, (maxSoFar, value) => math.max(maxSoFar, value));
    final maxY = math.max(1.0, maxValue * 1.18);
    final interval = _axisInterval(maxY);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark ? const Color(0xFF374151) : const Color(0xFFE8EAFF),
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value <= 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    formatHours(value),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.darkSecondaryText
                          : AppColors.lightSecondaryText,
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    data[idx].dayName,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.darkSecondaryText
                          : AppColors.lightSecondaryText,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: visibleSeries
            .map((s) => _line(s.values, s.color))
            .toList(),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) => spots.map((spot) {
              final series = visibleSeries[spot.barIndex];
              return LineTooltipItem(
                '${series.label}: ${formatHours(spot.y)}',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  List<_TrendSeries> _visibleSeries() {
    final series = <_TrendSeries>[
      _TrendSeries(
        key: 'flow',
        label: 'Flow',
        color: AppColors.chartFlow,
        values: data.map((e) => e.flowHours).toList(),
      ),
      _TrendSeries(
        key: 'debugging',
        label: 'Debugging',
        color: AppColors.chartDebugging,
        values: data.map((e) => e.debuggingHours).toList(),
      ),
      _TrendSeries(
        key: 'research',
        label: 'Research',
        color: AppColors.chartResearch,
        values: data.map((e) => e.researchHours).toList(),
      ),
      _TrendSeries(
        key: 'communication',
        label: 'Communication',
        color: AppColors.chartCommunication,
        values: data.map((e) => e.communicationHours).toList(),
      ),
      _TrendSeries(
        key: 'distracted',
        label: 'Distracted',
        color: AppColors.chartDistracted,
        values: data.map((e) => e.distractedHours).toList(),
      ),
    ];
    return filter == 'all'
        ? series
        : series.where((s) => s.key == filter).toList();
  }

  double _axisInterval(double maxY) {
    if (maxY <= 1) return 0.25;
    if (maxY <= 2) return 0.5;
    if (maxY <= 6) return 1;
    if (maxY <= 12) return 2;
    return 4;
  }

  LineChartBarData _line(List<double> values, Color color) {
    return LineChartBarData(
      spots: List.generate(
        values.length,
        (i) => FlSpot(i.toDouble(), values[i]),
      ),
      isCurved: true,
      color: color,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.08),
      ),
    );
  }
}

class _TrendSeries {
  const _TrendSeries({
    required this.key,
    required this.label,
    required this.color,
    required this.values,
  });

  final String key;
  final String label;
  final Color color;
  final List<double> values;
}
