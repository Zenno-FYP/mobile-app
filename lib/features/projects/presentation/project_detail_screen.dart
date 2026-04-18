import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/lang_bar.dart';
import '../../../shared/widgets/tag_badge.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/data/models/dashboard_models.dart';

final _projectDetailProvider = FutureProvider.family<ProjectDetailResponse, String>((ref, name) {
  return DashboardRepository(ref.watch(apiClientProvider)).getProjectDetail(name);
});

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectName});
  final String projectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detail = ref.watch(_projectDetailProvider(projectName));

    return Scaffold(
      appBar: AppBar(
        title: Text(Uri.decodeComponent(projectName)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete Project'),
                    content: const Text('This will remove the project from your dashboard. This cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppColors.red))),
                    ],
                  ),
                );
                if (ok == true) {
                  try {
                    await DashboardRepository(ref.read(apiClientProvider)).deleteProject(projectName);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project deleted')));
                      context.pop();
                    }
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.red))),
            ],
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryStart)),
        error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(_projectDetailProvider(projectName))),
        data: (data) => RefreshIndicator(
          color: AppColors.primaryStart,
          onRefresh: () async => ref.invalidate(_projectDetailProvider(projectName)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.displayName ?? data.projectName,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    if (data.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(data.description, style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                    ],
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8, crossAxisSpacing: 8,
                      childAspectRatio: 1.6,
                      children: [
                        MetricTile(icon: Icons.timer, label: 'App Time', value: '${data.appTimeHours.toStringAsFixed(1)}h'),
                        MetricTile(icon: Icons.code, label: 'Lines', value: _fmt(data.totalLines),
                            gradient: const LinearGradient(colors: [AppColors.teal, AppColors.tealDark])),
                        MetricTile(icon: Icons.insert_drive_file, label: 'Files', value: _fmt(data.totalFiles),
                            gradient: const LinearGradient(colors: [AppColors.yellow, AppColors.yellowDark])),
                        MetricTile(icon: Icons.star, label: 'Skills', value: '${data.skills.length}',
                            gradient: const LinearGradient(colors: [AppColors.pink, AppColors.pinkLight])),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Languages
              if (data.languages.isNotEmpty)
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Languages', icon: Icons.code),
                      const SizedBox(height: 12),
                      LangBar(languages: data.languages.map((l) => LangBarSegment(name: l.name, percent: l.percent / 100)).toList()),
                      const SizedBox(height: 12),
                      ...data.languages.map((l) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Container(width: 10, height: 10, decoration: BoxDecoration(color: LangBar.langColor(l.name), borderRadius: BorderRadius.circular(3))),
                                const SizedBox(width: 8),
                                Expanded(child: Text(l.name, style: const TextStyle(fontSize: 14))),
                                Text('${l.percent.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Context Breakdown
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Context Breakdown', icon: Icons.pie_chart),
                    const SizedBox(height: 12),
                    _contextRow('Flow', data.contextBreakdown.flowHours, AppColors.chartFlow, isDark),
                    _contextRow('Debugging', data.contextBreakdown.debuggingHours, AppColors.chartDebugging, isDark),
                    _contextRow('Research', data.contextBreakdown.researchHours, AppColors.chartResearch, isDark),
                    _contextRow('Communication', data.contextBreakdown.communicationHours, AppColors.chartCommunication, isDark),
                    _contextRow('Distracted', data.contextBreakdown.distractedHours, AppColors.chartDistracted, isDark),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Top Apps
              if (data.topApps.isNotEmpty)
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Top Apps', icon: Icons.apps),
                      const SizedBox(height: 12),
                      ...data.topApps.map((a) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(child: Text(a.name, style: const TextStyle(fontSize: 14))),
                                Text('${a.durationHours.toStringAsFixed(1)}h', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Skills
              if (data.skills.isNotEmpty)
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Skills', icon: Icons.emoji_events),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: data.skills.map((s) => TagBadge(label: '${s.name} ${s.durationHours.toStringAsFixed(1)}h', isGradient: true)).toList(),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contextRow(String label, double hours, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text('${hours.toStringAsFixed(1)}h', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
