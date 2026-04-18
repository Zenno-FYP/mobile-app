import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/gradient_button.dart';
import 'onboarding_page.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    OnboardingPageData(
      icon: Icons.smart_toy,
      title: 'Meet your Zenno Agent',
      subtitle: 'Your personal AI that tracks your coding habits and nudges you to stay in flow.',
      gradientColors: [AppColors.primaryEnd, AppColors.primaryStart],
    ),
    OnboardingPageData(
      icon: Icons.insights,
      title: 'Understand your work patterns',
      subtitle: 'See how you spend your dev time across projects, languages, and focus states.',
      gradientColors: [AppColors.teal, AppColors.tealDark],
    ),
    OnboardingPageData(
      icon: Icons.people,
      title: 'Connect with your peers',
      subtitle: 'Find fellow developers, compare journeys, and message them directly.',
      gradientColors: [AppColors.pink, AppColors.pinkLight],
    ),
  ];

  Future<void> _finish() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('onboarding_seen', true);
    if (mounted) context.go('/auth');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLast = _currentPage == _pages.length - 1;

    return AppBackground(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

              // Pages
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (context, index) => OnboardingPage(data: _pages[index]),
                ),
              ),

              // Indicators
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _currentPage ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: i == _currentPage ? AppColors.primaryGradient : null,
                        color: i == _currentPage
                            ? null
                            : isDark
                                ? const Color(0x33FFFFFF)
                                : const Color(0x26000000),
                      ),
                    ),
                  ),
                ),
              ),

              // Next / Get Started button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: GradientButton(
                  onPressed: () {
                    if (isLast) {
                      _finish();
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  label: isLast ? 'Get Started' : 'Next',
                  icon: isLast ? Icons.arrow_forward : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
