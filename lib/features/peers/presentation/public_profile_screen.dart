import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/format_duration.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/tag_badge.dart';
import '../../../shared/widgets/lang_bar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/data/models/dashboard_models.dart';
import '../../chat/data/chat_repository.dart';

final _publicProfileProvider = FutureProvider.family<PublicProfileResponse, String>((ref, userId) {
  return DashboardRepository(ref.watch(apiClientProvider)).getPublicProfile(userId);
});

class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileAsync = ref.watch(_publicProfileProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryStart)),
        error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(_publicProfileProvider(userId))),
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GlassCard(
              child: Column(
                children: [
                  AppAvatar(imageUrl: data.user.profilePhoto, name: data.user.name, size: 96, borderWidth: 3),
                  const SizedBox(height: 12),
                  Text(data.user.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                  if (data.user.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(data.user.description, textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                  ],
                  if (data.user.createdAt != null) ...[
                    const SizedBox(height: 8),
                    Text('Joined ${_formatDate(data.user.createdAt!)}',
                        style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                  ],
                  const SizedBox(height: 16),
                  GradientButton(
                    onPressed: () => _startChat(context, ref),
                    label: 'Message',
                    icon: Icons.chat_bubble_outline,
                    height: 44,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8, crossAxisSpacing: 8,
                childAspectRatio: 1.5,
                children: [
                  MetricTile(icon: Icons.local_fire_department, label: 'Streak', value: '${data.profile.streakDays}d',
                      gradient: const LinearGradient(colors: [AppColors.yellow, AppColors.yellowDark])),
                  MetricTile(icon: Icons.folder, label: 'Projects', value: '${data.profile.totalProjects}'),
                  MetricTile(icon: Icons.timer, label: 'App Hours', value: formatHours(data.profile.totalAppTimeHours),
                      gradient: const LinearGradient(colors: [AppColors.teal, AppColors.tealDark])),
                  MetricTile(icon: Icons.psychology, label: 'Flow', value: data.profile.globalFlowFocusPercent != null ? '${data.profile.globalFlowFocusPercent!.toStringAsFixed(0)}%' : 'N/A',
                      gradient: const LinearGradient(colors: [AppColors.pink, AppColors.pinkLight])),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (data.profile.topSkills.isNotEmpty)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Top Skills', icon: Icons.emoji_events),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: data.profile.topSkills.map((s) => TagBadge(label: '${s.name} ${s.percent.toStringAsFixed(0)}%', isGradient: true)).toList(),
                    ),
                  ],
                ),
              ),
            if (data.profile.topLanguages.isNotEmpty) ...[
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Languages', icon: Icons.code),
                    const SizedBox(height: 8),
                    LangBar(languages: data.profile.topLanguages.map((l) => LangBarSegment(name: l.name, percent: l.percent / 100)).toList()),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startChat(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ChatRepository(ref.read(apiClientProvider));
      final convId = await repo.createConversation(userId);
      if (context.mounted) context.push('/chats/$convId');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String _formatDate(String iso) {
    try { return DateFormat('MMM yyyy').format(DateTime.parse(iso)); } catch (_) { return iso; }
  }
}
