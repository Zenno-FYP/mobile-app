import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../../core/widgets/error_state.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/tag_badge.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../settings/presentation/settings_bottom_sheet.dart';
import '../data/dashboard_repository.dart';
import '../data/models/dashboard_models.dart';
import 'widgets/developer_trends_chart.dart';

final _dashboardRepoProvider = Provider((ref) {
  return DashboardRepository(ref.watch(apiClientProvider));
});

final _metricsProvider = FutureProvider<PerformanceMetricsResponse>((ref) {
  return ref.watch(_dashboardRepoProvider).getPerformanceMetrics();
});

final _toolUsageProvider = FutureProvider<ToolUsageResponse>((ref) {
  return ref.watch(_dashboardRepoProvider).getToolUsage();
});

final _insightsProvider = FutureProvider<ProjectInsightsResponse>((ref) {
  return ref.watch(_dashboardRepoProvider).getProjectInsights();
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final metrics = ref.watch(_metricsProvider);
    final toolUsage = ref.watch(_toolUsageProvider);
    final insights = ref.watch(_insightsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                Icon(Icons.notifications_outlined,
                    color: isDark ? AppColors.darkText : AppColors.lightText),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () => context.push('/notifications'),
          ),
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
          ref.invalidate(_metricsProvider);
          ref.invalidate(_toolUsageProvider);
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
                          'Here\'s your developer overview',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.bolt, color: Colors.white, size: 24),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Key Metrics
            metrics.when(
              data: (data) => _buildMetrics(context, data, ref),
              loading: () => const _MetricsShimmer(),
              error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(_metricsProvider)),
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
                      trailing: Icon(Icons.chevron_right,
                          color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
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
            toolUsage.when(
              data: (data) => _buildToolUsage(context, data, isDark),
              loading: () => const ShimmerCard(height: 200),
              error: (_, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            // Zenno Agent Card
            GlassCard(
              onTap: () => context.go('/agent'),
              padding: EdgeInsets.zero,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.agentCardGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.smart_toy, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Zenno Agent',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                          SizedBox(height: 4),
                          Text('Manage preferences & view stats',
                              style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 13)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white70),
                  ],
                ),
              ),
            ),

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
                          color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: data.strongestSkills
                          .take(5)
                          .map((s) => TagBadge(label: '${s.name} ${s.percent.toStringAsFixed(0)}%', isGradient: true))
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
                          color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                    ),
                    const SizedBox(height: 12),
                    ...data.currentProjects.take(5).map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () => context.push('/projects/${Uri.encodeComponent(p.name)}'),
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
                                      color: isDark ? AppColors.darkText : AppColors.lightText,
                                    ),
                                  ),
                                ),
                                Icon(Icons.chevron_right, size: 18,
                                    color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
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

  Widget _buildMetrics(BuildContext context, PerformanceMetricsResponse data, WidgetRef ref) {
    final s = data.performanceSummary;
    return GlassCard(
      onTap: () => context.push('/analytics/metrics'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Key Metrics', icon: Icons.speed),
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
                gradient: const LinearGradient(colors: [AppColors.primaryStart, AppColors.primaryEnd]),
              ),
              MetricTile(
                icon: Icons.access_time,
                label: 'Active hrs/day',
                value: s.dailyActiveAverage.value.toStringAsFixed(1),
                changePercent: s.dailyActiveAverage.changePercent,
                gradient: const LinearGradient(colors: [AppColors.teal, AppColors.tealDark]),
              ),
              MetricTile(
                icon: Icons.mouse,
                label: 'Mouse (CPM)',
                value: s.avgMouseClickRate.value.toStringAsFixed(1),
                changePercent: s.avgMouseClickRate.changePercent,
                gradient: const LinearGradient(colors: [AppColors.yellow, AppColors.yellowDark]),
              ),
              MetricTile(
                icon: Icons.backspace_outlined,
                label: 'Corrections',
                value: '${s.avgCorrections.value.toStringAsFixed(1)}%',
                changePercent: s.avgCorrections.changePercent,
                gradient: const LinearGradient(colors: [AppColors.pink, AppColors.pinkLight]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolUsage(BuildContext context, ToolUsageResponse data, bool isDark) {
    return GlassCard(
      onTap: () => context.push('/analytics/apps-languages'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Top Apps & Languages',
            icon: Icons.apps,
            trailing: Icon(Icons.chevron_right,
                color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
          ),
          const SizedBox(height: 12),
          ...data.topApps.apps.take(3).map((app) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(app.name, style: const TextStyle(fontSize: 14)),
                    ),
                    Text(
                      '${app.durationHours.toStringAsFixed(1)}h',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: app.percentOfTotal / 100,
                          minHeight: 6,
                          backgroundColor: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB),
                          valueColor: const AlwaysStoppedAnimation(AppColors.primaryStart),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          if (data.languageDistribution.languages.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: data.languageDistribution.languages.take(5).map((l) =>
                TagBadge(label: '${l.name} ${l.percent.toStringAsFixed(0)}%'),
              ).toList(),
            ),
          ],
        ],
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

