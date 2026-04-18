import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

class TagBadge extends StatelessWidget {
  const TagBadge({
    super.key,
    required this.label,
    this.isGradient = false,
    this.color,
  });

  final String label;
  final bool isGradient;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isGradient) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? AppColors.primaryStart).withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: (color ?? AppColors.primaryStart).withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color ?? (isDark ? AppColors.darkText : AppColors.lightText),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
