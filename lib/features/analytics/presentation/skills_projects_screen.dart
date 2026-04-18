import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/tag_badge.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/data/models/dashboard_models.dart';

final _detailProvider = FutureProvider<SkillsProjectsDetailResponse>((ref) {
  return DashboardRepository(ref.watch(apiClientProvider)).getSkillsProjectsDetail();
});

class SkillsProjectsScreen extends ConsumerWidget {
  const SkillsProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detail = ref.watch(_detailProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Skills & Projects')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryStart)),
        error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(_detailProvider)),
        data: (data) => RefreshIndicator(
          color: AppColors.primaryStart,
          onRefresh: () async => ref.invalidate(_detailProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassCard(
                child: Column(
                  children: [
                    const SectionHeader(title: 'Summary', icon: Icons.summarize),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.5,
                      children: [
                        MetricTile(icon: Icons.folder, label: 'Projects', value: '${data.summary.totalProjects}'),
                        MetricTile(icon: Icons.timer, label: 'App Hours', value: data.summary.totalAppTimeHours.toStringAsFixed(1),
                            gradient: const LinearGradient(colors: [AppColors.teal, AppColors.tealDark])),
                        MetricTile(icon: Icons.star, label: 'Skills', value: '${data.summary.uniqueSkillsCount}',
                            gradient: const LinearGradient(colors: [AppColors.yellow, AppColors.yellowDark])),
                        MetricTile(icon: Icons.code, label: 'Lines', value: _formatNum(data.summary.totalLinesOfCode),
                            gradient: const LinearGradient(colors: [AppColors.pink, AppColors.pinkLight])),
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
                    const SectionHeader(title: 'Skills', icon: Icons.emoji_events),
                    const SizedBox(height: 12),
                    ...data.skills.map((skill) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(skill.name, style: const TextStyle(fontSize: 14))),
                                  Text('${skill.durationHours.toStringAsFixed(1)}h  (${skill.percentOfTotal.toStringAsFixed(0)}%)',
                                      style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: skill.percentOfTotal / 100,
                                  minHeight: 6,
                                  backgroundColor: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB),
                                  valueColor: const AlwaysStoppedAnimation(AppColors.primaryStart),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Projects', icon: Icons.folder_open),
                    const SizedBox(height: 12),
                    ...data.projects.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: () => context.push('/projects/${Uri.encodeComponent(p.name)}'),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0x0DFFFFFF) : const Color(0x66FFFFFF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isDark ? const Color(0x1AFFFFFF) : const Color(0x33FFFFFF)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.displayName ?? p.name,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                  if (p.description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                                  ],
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6, runSpacing: 4,
                                    children: [
                                      TagBadge(label: '${p.appTimeHours.toStringAsFixed(1)}h'),
                                      TagBadge(label: '${_formatNum(p.totalLines)} lines'),
                                      ...p.skills.take(3).map((s) => TagBadge(label: s.name, isGradient: true)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
