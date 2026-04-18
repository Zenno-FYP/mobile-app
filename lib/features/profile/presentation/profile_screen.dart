import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/tag_badge.dart';
import '../../../shared/widgets/lang_bar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/data/models/dashboard_models.dart';

final _profileDataProvider = FutureProvider<ProfilePageResponse>((ref) {
  return DashboardRepository(ref.watch(apiClientProvider)).getProfilePage();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final profileData = ref.watch(_profileDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/profile/edit'),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
          ),
        ],
      ),
      body: profileData.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryStart)),
        error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(_profileDataProvider)),
        data: (data) => RefreshIndicator(
          color: AppColors.primaryStart,
          onRefresh: () async => ref.invalidate(_profileDataProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Hero card
              GlassCard(
                child: Column(
                  children: [
                    AppAvatar(
                      imageUrl: user?.profilePhoto,
                      name: user?.name,
                      size: 96,
                      borderWidth: 3,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.name ?? '',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
                    ),
                    if (user?.description != null && user!.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        user.description!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                        ),
                      ),
                    ],
                    if (user?.createdAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Joined ${_formatDate(user!.createdAt!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Social links
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (user?.githubUrl?.isNotEmpty ?? false)
                          _SocialIcon(icon: Icons.code, tooltip: 'GitHub', url: user!.githubUrl!),
                        if (user?.linkedinUrl?.isNotEmpty ?? false)
                          _SocialIcon(icon: Icons.business, tooltip: 'LinkedIn', url: user!.linkedinUrl!),
                        if (user?.twitterUrl?.isNotEmpty ?? false)
                          _SocialIcon(icon: Icons.alternate_email, tooltip: 'Twitter', url: user!.twitterUrl!),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Stats row
              GlassCard(
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.5,
                  children: [
                    MetricTile(icon: Icons.local_fire_department, label: 'Streak', value: '${data.streakDays}d',
                        gradient: const LinearGradient(colors: [AppColors.yellow, AppColors.yellowDark])),
                    MetricTile(icon: Icons.folder, label: 'Projects', value: '${data.totalProjects}'),
                    MetricTile(icon: Icons.timer, label: 'App Hours', value: data.totalAppTimeHours.toStringAsFixed(1),
                        gradient: const LinearGradient(colors: [AppColors.teal, AppColors.tealDark])),
                    MetricTile(icon: Icons.psychology, label: 'Flow Focus',
                        value: data.globalFlowFocusPercent != null ? '${data.globalFlowFocusPercent!.toStringAsFixed(0)}%' : 'N/A',
                        gradient: const LinearGradient(colors: [AppColors.pink, AppColors.pinkLight])),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Top Skills
              if (data.topSkills.isNotEmpty)
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Top Skills', icon: Icons.emoji_events),
                      const SizedBox(height: 12),
                      ...data.topSkills.map((s) => _ProgressRow(name: s.name, percent: s.percent, isDark: isDark)),
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
                      ...data.topApps.map((a) => _ProgressRow(name: a.name, percent: a.percent, isDark: isDark)),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Languages
              if (data.topLanguages.isNotEmpty)
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Languages', icon: Icons.code),
                      const SizedBox(height: 12),
                      LangBar(
                        languages: data.topLanguages.map((l) => LangBarSegment(name: l.name, percent: l.percent / 100)).toList(),
                      ),
                      const SizedBox(height: 12),
                      ...data.topLanguages.map((l) => _ProgressRow(
                            name: l.name,
                            percent: l.percent,
                            isDark: isDark,
                            color: LangBar.langColor(l.name),
                          )),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Projects
              if (data.projects.isNotEmpty)
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Projects', icon: Icons.folder_open),
                      const SizedBox(height: 12),
                      ...data.projects.map((p) => _ProjectTile(project: p, isDark: isDark)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final date = DateTime.parse(iso);
      return DateFormat('MMM yyyy').format(date);
    } catch (_) {
      return iso;
    }
  }
}

class _SocialIcon extends StatelessWidget {
  const _SocialIcon({required this.icon, required this.tooltip, required this.url});
  final IconData icon;
  final String tooltip;
  final String url;

  Future<void> _launch(BuildContext context) async {
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $tooltip link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: () => _launch(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0x33FFFFFF) : const Color(0x33000000),
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.name, required this.percent, required this.isDark, this.color});
  final String name;
  final double percent;
  final bool isDark;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: const TextStyle(fontSize: 14))),
              Text('${percent.toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 5,
              backgroundColor: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation(color ?? AppColors.primaryStart),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({required this.project, required this.isDark});
  final ProfileProjectCard project;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/projects/${Uri.encodeComponent(project.projectName)}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0x0DFFFFFF) : const Color(0x66FFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? const Color(0x1AFFFFFF) : const Color(0x33FFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(project.displayName ?? project.projectName,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            if (project.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(project.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
            ],
            const SizedBox(height: 8),
            if (project.languages.isNotEmpty)
              LangBar(languages: project.languages.map((l) => LangBarSegment(name: l.name, percent: l.percent / 100)).toList()),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 4,
              children: [
                TagBadge(label: '${project.appTimeHours.toStringAsFixed(1)}h'),
                ...project.topSkills.take(3).map((s) => TagBadge(label: s.name, isGradient: true)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
