import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';

class OnboardingPageData {
  const OnboardingPageData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
}

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, required this.data});

  final OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration container
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  data.gradientColors[0].withValues(alpha: 0.3),
                  data.gradientColors[1].withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: data.gradientColors),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: data.gradientColors[0].withValues(alpha: 0.4),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  data.icon,
                  size: 56,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 48),

          // Title
          Text(
            data.title,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.lightText,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Subtitle
          Text(
            data.subtitle,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
