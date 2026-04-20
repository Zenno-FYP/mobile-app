import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/format_duration.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../../core/widgets/error_state.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/tag_badge.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../notifications/presentation/notification_bell_action.dart';
import '../../settings/presentation/settings_bottom_sheet.dart';
import '../data/dashboard_repository.dart';
import '../data/models/dashboard_models.dart';
import 'widgets/developer_trends_chart.dart';

// Family provider — keyed by period string so toggling triggers a fresh fetch.
final _metricsProvider =
    FutureProvider.family<PerformanceMetricsResponse, String>((ref, period) {
  ref.watch(userSessionProvider);
  return ref.watch(_dashboardRepoProvider).getPerformanceMetrics(period: period);
});

final _dashboardRepoProvider =
    Provider((ref) => DashboardRepository(ref.watch(apiClientProvider)));

final _toolUsageProvider = FutureProvider<ToolUsageResponse>((ref) {
  ref.watch(userSessionProvider);
  return ref.watch(_dashboardRepoProvider).getToolUsage();
});

final _allTimeAppsProvider = FutureProvider<List<ProfileGlobalRow>>((ref) async {
  ref.watch(userSessionProvider);
  final page = await ref.watch(_dashboardRepoProvider).getProfilePage();
  return page.topApps;
});

final _insightsProvider = FutureProvider<ProjectInsightsResponse>((ref) {
  ref.watch(userSessionProvider);
  return ref.watch(_dashboardRepoProvider).getProjectInsights();
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _period = 'current_week';

  void _togglePeriod(String p) {
    if (_period == p) return;
    setState(() => _period = p);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final metrics = ref.watch(_metricsProvider(_period));
    final toolUsage = ref.watch(_toolUsageProvider);
    final allTimeApps = ref.watch(_allTimeAppsProvider);
    final insights = ref.watch(_insightsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          const NotificationBellAction(),
          IconButton(
            icon: Icon(Icons.settings_outlined,
                color: isDark ? AppColors.darkText : AppColors.lightText),
            onPressed: () => showSettingsSheet(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primaryStart,
        onRefresh: () async {
          ref.invalidate(_metricsProvider(_period));
          ref.invalidate(_toolUsageProvider);
          ref.invalidate(_allTimeAppsProvider);
          ref.invalidate(_insightsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // Welcome banner
            GlassCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back${user != null ? ', ${user.name.split(' ').first}' : ''}!',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Here's your developer overview",
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? AppColors.darkSecondaryText
                                : AppColors.lightSecondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Performance Metrics
            metrics.when(
              data: (data) => _buildMetrics(context, data, isDark),
              loading: () => const _MetricsShimmer(),
              error: (e, _) => ErrorState(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(_metricsProvider(_period))),
            ),

            const SizedBox(height: 16),

            // Developer Trends
            metrics.when(
              data: (data) => GlassCard(
                onTap: () => context.push('/analytics/metrics'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Developer Trends',
                      icon: Icons.show_chart,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _WeekChip(
                            label: '← Prev',
                            selected: _period == 'previous_week',
                            isDark: isDark,
                            onTap: () => _togglePeriod('previous_week'),
                          ),
                          const SizedBox(width: 6),
                          _WeekChip(
                            label: 'This week',
                            selected: _period == 'current_week',
                            isDark: isDark,
                            onTap: () => _togglePeriod('current_week'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: DeveloperTrendsChart(data: data.usageTrendGraph),
                    ),
                  ],
                ),
              ),
              loading: () => const ShimmerCard(height: 260),
              error: (_, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            // Top Apps & Languages
            _buildToolUsage(context, allTimeApps, toolUsage, isDark),

            const SizedBox(height: 16),

            // Strongest Skills
            insights.when(
              data: (data) => GlassCard(
                onTap: () => context.push('/analytics/skills-projects'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Strongest Skills',
                      icon: Icons.emoji_events,
                      trailing: Icon(Icons.chevron_right,
                          color: isDark
                              ? AppColors.darkSecondaryText
                              : AppColors.lightSecondaryText),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: data.strongestSkills
                          .take(5)
                          .map((s) => TagBadge(
                              label:
                                  '${s.name} ${s.percent.toStringAsFixed(0)}%',
                              isGradient: true))
                          .toList(),
                    ),
                  ],
                ),
              ),
              loading: () => const ShimmerCard(height: 100),
              error: (_, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            // Recent Projects
            insights.when(
              data: (data) => GlassCard(
                onTap: () => context.push('/analytics/skills-projects'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Recent Projects',
                      icon: Icons.folder_open,
                      trailing: Icon(Icons.chevron_right,
                          color: isDark
                              ? AppColors.darkSecondaryText
                              : AppColors.lightSecondaryText),
                    ),
                    const SizedBox(height: 12),
                    ...data.currentProjects.take(5).map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () => context
                                .push('/projects/${Uri.encodeComponent(p.name)}'),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    p.displayName ?? p.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? AppColors.darkText
                                          : AppColors.lightText,
                                    ),
                                  ),
                                ),
                                Icon(Icons.chevron_right,
                                    size: 18,
                                    color: isDark
                                        ? AppColors.darkSecondaryText
                                        : AppColors.lightSecondaryText),
                              ],
                            ),
                          ),
                        )),
                  ],
                ),
              ),
              loading: () => const ShimmerCard(height: 160),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetrics(BuildContext context, PerformanceMetricsResponse data, bool isDark) {
    final s = data.performanceSummary;
    return GlassCard(
      onTap: () => context.push('/analytics/metrics'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Performance Metrics',
            icon: Icons.speed,
            trailing: Icon(Icons.chevron_right,
                color: isDark
                    ? AppColors.darkSecondaryText
                    : AppColors.lightSecondaryText),
          ),
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
                gradient: const LinearGradient(
                    colors: [AppColors.primaryStart, AppColors.primaryEnd]),
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
                value: '${s.avgCorrections.value.toStringAsFixed(1)}%',
                changePercent: s.avgCorrections.changePercent,
                gradient: const LinearGradient(
                    colors: [AppColors.pink, AppColors.pinkLight]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolUsage(
    BuildContext context,
    AsyncValue<List<ProfileGlobalRow>> appsAsync,
    AsyncValue<ToolUsageResponse> toolUsageAsync,
    bool isDark,
  ) {
    final secondaryColor =
        isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;
    final chevron = Icon(Icons.chevron_right, color: secondaryColor);

    return GlassCard(
      onTap: () => context.push('/analytics/apps-languages'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Top Apps & Languages',
            icon: Icons.apps,
            trailing: chevron,
          ),
          const SizedBox(height: 12),

          // ── All-time apps ────────────────────────────────────────────
          appsAsync.when(
            loading: () => const _MiniShimmer(),
            error: (_, _) => const SizedBox.shrink(),
            data: (apps) {
              if (apps.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All time · Top 5',
                    style: TextStyle(fontSize: 11, color: secondaryColor),
                  ),
                  const SizedBox(height: 8),
                  ...apps.take(5).map((app) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(app.name,
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Text(
                              formatHours(app.durationHours),
                              style: TextStyle(fontSize: 13, color: secondaryColor),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 60,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: app.percent / 100,
                                  minHeight: 6,
                                  backgroundColor: isDark
                                      ? const Color(0x1AFFFFFF)
                                      : const Color(0xFFE5E7EB),
                                  valueColor: const AlwaysStoppedAnimation(
                                      AppColors.primaryStart),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              );
            },
          ),

          // ── Languages (LoC-based, already all-time) ──────────────────
          toolUsageAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (usage) {
              final langs = usage.languageDistribution.languages;
              if (langs.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: langs
                        .take(5)
                        .map((l) => TagBadge(
                            label: '${l.name} ${l.percent.toStringAsFixed(0)}%'))
                        .toList(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Compact week-selector chip used in section headers.
class _WeekChip extends StatelessWidget {
  const _WeekChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? AppColors.primaryStart.withValues(alpha: 0.15)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? AppColors.primaryStart.withValues(alpha: 0.6)
                : (isDark
                    ? const Color(0x33FFFFFF)
                    : const Color(0x33000000)),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? AppColors.primaryStart
                : (isDark
                    ? AppColors.darkSecondaryText
                    : AppColors.lightSecondaryText),
          ),
        ),
      ),
    );
  }
}

class _MiniShimmer extends StatelessWidget {
  const _MiniShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: ShimmerLoader(height: 14, width: double.infinity),
        ),
      ),
    );
  }
}

class _MetricsShimmer extends StatelessWidget {
  const _MetricsShimmer();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          const ShimmerLoader(height: 20, width: 120),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.3,
            children: List.generate(4, (_) => const ShimmerCard(height: 80)),
          ),
        ],
      ),
    );
  }
}
