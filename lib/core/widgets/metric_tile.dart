import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.changePercent,
    this.gradient,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final double? changePercent;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0x0DFFFFFF) : const Color(0x99FFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0x1AFFFFFF) : const Color(0x33FFFFFF),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: gradient ?? AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const Spacer(),
                if (changePercent != null) _TrendChip(changePercent!),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: AppTextStyles.metricValue),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip(this.percent);
  final double percent;

  @override
  Widget build(BuildContext context) {
    final isUp = percent >= 0;
    final color = percent == 0
        ? Colors.grey
        : isUp
            ? const Color(0xFF22C55E)
            : AppColors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${isUp ? '+' : ''}${percent.toStringAsFixed(0)}%',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
