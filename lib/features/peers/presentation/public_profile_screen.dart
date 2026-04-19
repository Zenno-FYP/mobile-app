import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/error_state.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/lang_bar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/data/models/dashboard_models.dart';
import '../../chat/data/chat_repository.dart';
import '../../profile/presentation/widgets/profile_sections.dart';

final _publicProfileProvider =
    FutureProvider.family<PublicProfileResponse, String>((ref, userId) {
  ref.watch(userSessionProvider);
  return DashboardRepository(ref.watch(apiClientProvider))
      .getPublicProfile(userId);
});

/// Mirror the website's `MAX_GLOBAL_VISIBLE` so Top Skills / Top Apps /
/// Languages cap at the same six entries here as on the user's own
/// profile and on the website.
const int _maxGlobalVisible = ProfileSections.maxGlobalVisible;

/// Public read-only view of another developer's profile. Was previously
/// rendering only the hero card, four metric tiles, the Top Skills chip
/// strip, and a stacked language bar — none of the apps, language rows,
/// or rich project cards the website surfaces. This rebuild reuses the
/// same shared section widgets the user's own [ProfileScreen] uses, so
/// peers see exactly what the website shows.
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
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryStart),
        ),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(_publicProfileProvider(userId)),
        ),
        data: (data) => RefreshIndicator(
          color: AppColors.primaryStart,
          onRefresh: () async => ref.invalidate(_publicProfileProvider(userId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeroCard(
                user: data.user,
                isDark: isDark,
                onMessage: () => _startChat(context, ref),
              ),
              const SizedBox(height: 16),
              GlassCard(child: ProfileMetricsGrid(data: data.profile)),
              if (data.profile.topSkills.isNotEmpty) ...[
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Top Skills',
                        icon: Icons.emoji_events,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All projects · up to $_maxGlobalVisible shown',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkSecondaryText
                              : AppColors.lightSecondaryText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...data.profile.topSkills
                          .take(_maxGlobalVisible)
                          .map((s) => ProgressRow(
                                name: s.name,
                                percent: s.percent,
                                isDark: isDark,
                              )),
                    ],
                  ),
                ),
              ],
              if (data.profile.projects.isNotEmpty) ...[
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Projects',
                        icon: Icons.folder_open,
                      ),
                      const SizedBox(height: 12),
                      ...data.profile.projects.map(
                        (p) => ProjectTile(
                          project: p,
                          isDark: isDark,
                          // Peer project tiles aren't navigable on the
                          // website (the title is plain text), so we
                          // disable the tap-to-open-project behaviour
                          // here too — otherwise we'd open the *viewer's*
                          // project of the same name.
                          interactive: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (data.profile.topApps.isNotEmpty) ...[
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Top Apps', icon: Icons.apps),
                      const SizedBox(height: 12),
                      ...data.profile.topApps.take(_maxGlobalVisible).map(
                            (a) => AppRow(
                              name: a.name,
                              hours: a.durationHours,
                              percent: a.percent,
                              isDark: isDark,
                            ),
                          ),
                    ],
                  ),
                ),
              ],
              if (data.profile.topLanguages.isNotEmpty) ...[
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Languages',
                        icon: Icons.code,
                      ),
                      const SizedBox(height: 12),
                      LangBar(
                        languages: data.profile.topLanguages
                            .take(_maxGlobalVisible)
                            .map((l) => LangBarSegment(
                                  name: l.name,
                                  percent: l.percent / 100,
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      ...data.profile.topLanguages
                          .take(_maxGlobalVisible)
                          .map((l) => LanguageRow(
                                name: l.name,
                                percent: l.percent,
                                lines: l.lines,
                                isDark: isDark,
                                color: LangBar.langColor(l.name),
                              )),
                    ],
                  ),
                ),
              ],
            ],
          ),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.user,
    required this.isDark,
    required this.onMessage,
  });
  final PublicProfileUser user;
  final bool isDark;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final secondary =
        isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;
    return GlassCard(
      child: Column(
        children: [
          AppAvatar(
            imageUrl: user.profilePhoto,
            name: user.name,
            size: 96,
            borderWidth: 3,
          ),
          const SizedBox(height: 12),
          Text(
            user.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          if (user.description.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              user.description,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: secondary),
            ),
          ],
          if (user.createdAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Joined ${_formatDate(user.createdAt!)}',
              style: TextStyle(fontSize: 12, color: secondary),
            ),
          ],
          const SizedBox(height: 16),
          GradientButton(
            onPressed: onMessage,
            label: 'Message',
            icon: Icons.chat_bubble_outline,
            height: 44,
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      return DateFormat('MMM yyyy').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }
}
