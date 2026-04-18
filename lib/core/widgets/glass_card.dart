import 'dart:ui';
import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.padding,
    this.margin,
    this.blur = 20,
    this.onTap,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.glassDarkFill : AppColors.glassLightFill,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isDark ? AppColors.glassDarkBorder : AppColors.glassLightBorder,
            ),
          ),
          child: child,
        ),
      ),
    );

    Widget result = card;
    if (margin != null) {
      result = Padding(padding: margin!, child: card);
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: result);
    }

    return result;
  }
}
