import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/error_state.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/lang_bar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/data/models/dashboard_models.dart';

final _detailProvider = FutureProvider<ToolUsageDetailResponse>((ref) {
  return DashboardRepository(ref.watch(apiClientProvider)).getToolUsageDetail();
});

class AppsLanguagesScreen extends ConsumerWidget {
  const AppsLanguagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detail = ref.watch(_detailProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Apps & Languages')),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Top Apps', icon: Icons.apps),
                    const SizedBox(height: 12),
                    Text('${data.uniqueAppsCount} apps  ·  ${data.topApps.totalUsageHours.toStringAsFixed(1)}h total',
                        style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                    const SizedBox(height: 12),
                    ...data.topApps.apps.map((app) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(app.name, style: const TextStyle(fontSize: 14))),
                                  Text('${app.durationHours.toStringAsFixed(1)}h',
                                      style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: app.percentOfTotal / 100,
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
              if (data.categoryBreakdown.isNotEmpty)
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Categories', icon: Icons.category),
                      const SizedBox(height: 12),
                      ...data.categoryBreakdown.map((cat) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(child: Text(cat.category, style: const TextStyle(fontSize: 14))),
                                Text('${cat.hours.toStringAsFixed(1)}h  (${cat.percentOfTotal.toStringAsFixed(0)}%)',
                                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
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
                    const SectionHeader(title: 'Languages', icon: Icons.code),
                    const SizedBox(height: 12),
                    LangBar(
                      languages: data.languageDistribution.languages
                          .map((l) => LangBarSegment(name: l.name, percent: l.percent / 100))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    ...data.languageDistribution.languages.map((lang) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 10, height: 10,
                                decoration: BoxDecoration(
                                  color: LangBar.langColor(lang.name),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(lang.name, style: const TextStyle(fontSize: 14))),
                              Text('${lang.percent.toStringAsFixed(1)}%  ${_formatLoc(lang.loc)}',
                                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                            ],
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

  String _formatLoc(int loc) {
    if (loc >= 1000) return '${(loc / 1000).toStringAsFixed(1)}K';
    return '$loc';
  }
}
