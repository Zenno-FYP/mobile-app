import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/models/dashboard_models.dart';

class DeveloperTrendsChart extends StatelessWidget {
  const DeveloperTrendsChart({super.key, required this.data});

  final List<UsageTrendBar> data;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (data.isEmpty) {
      return Center(
        child: Text(
          'No trend data available',
          style: TextStyle(
            color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
          ),
        ),
      );
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark ? const Color(0xFF374151) : const Color(0xFFE8EAFF),
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    data[idx].dayName,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          _line(data.map((e) => e.flowHours).toList(), AppColors.chartFlow),
          _line(data.map((e) => e.debuggingHours).toList(), AppColors.chartDebugging),
          _line(data.map((e) => e.researchHours).toList(), AppColors.chartResearch),
          _line(data.map((e) => e.communicationHours).toList(), AppColors.chartCommunication),
          _line(data.map((e) => e.distractedHours).toList(), AppColors.chartDistracted),
        ],
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }

  LineChartBarData _line(List<double> values, Color color) {
    return LineChartBarData(
      spots: List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i])),
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
