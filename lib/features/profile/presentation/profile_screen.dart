import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/error_state.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/lang_bar.dart';
import '../../../shared/models/user_model.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/data/models/dashboard_models.dart';
import 'widgets/profile_sections.dart';

final _profileDataProvider = FutureProvider<ProfilePageResponse>((ref) {
  // Tied to the user session — bumping `userSessionProvider` on logout
  // invalidates this provider so the next signed-in user never sees the
  // previous user's profile cached on screen.
  ref.watch(userSessionProvider);
  return DashboardRepository(ref.watch(apiClientProvider)).getProfilePage();
});

/// Mirror the website's `MAX_GLOBAL_VISIBLE` so the Top Skills, Top Apps,
/// and Languages sections cap at the same six entries everywhere.
const int _maxGlobalVisible = ProfileSections.maxGlobalVisible;

/// Owner's profile screen. In addition to the rich Top Skills / Apps /
/// Languages / Projects sections, the screen now supports an inline
/// "edit display" mode (matching the website's edit profile flow) that
/// lets the user reorder projects and hide individual projects, skills,
/// apps, or languages from their public profile.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _editMode = false;
  bool _saving = false;

  // Draft prefs while in edit mode. Initialized from the saved
  // `profile_preferences` whenever edit mode is entered, so we can
  // round-trip Cancel without touching the server.
  List<String> _draftOrder = const [];
  Set<String> _draftHiddenProjects = <String>{};
  Set<String> _draftHiddenSkills = <String>{};
  Set<String> _draftHiddenApps = <String>{};
  Set<String> _draftHiddenLangs = <String>{};

  void _enterEditMode(ProfilePageResponse data, UserModel? user) {
    final prefs = user?.profilePreferences;
    setState(() {
      _editMode = true;
      _draftOrder = _mergeOrder(
        prefs?.projectOrder ?? const [],
        data.projects.map((p) => p.projectName).toList(),
      );
      _draftHiddenProjects = {...?prefs?.hiddenProjectNames};
      _draftHiddenSkills = {...?prefs?.hiddenSkillNames};
      _draftHiddenApps = {...?prefs?.hiddenAppNames};
      _draftHiddenLangs = {...?prefs?.hiddenLanguageNames};
    });
  }

  void _cancelEdit() {
    setState(() => _editMode = false);
  }

  Future<void> _saveEdit() async {
    setState(() => _saving = true);
    try {
      final ds = ref.read(userRemoteDataSourceProvider);
      await ds.patchProfile({
        'profile_preferences': {
          'hidden_project_names': _draftHiddenProjects.toList(),
          'project_order': _draftOrder,
          'hidden_skill_names': _draftHiddenSkills.toList(),
          'hidden_app_names': _draftHiddenApps.toList(),
          'hidden_language_names': _draftHiddenLangs.toList(),
        },
      });
      await ref.read(authControllerProvider.notifier).fetchCurrentUser();
      if (!mounted) return;
      setState(() {
        _editMode = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile display updated')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    }
  }

  /// Merge the saved project order with the live project list: kept
  /// names stay where the user put them, new projects appear at the
  /// bottom, and stale names are dropped. Mirrors the website's
  /// `mergeProjectOrder` helper so the two surfaces agree.
  List<String> _mergeOrder(List<String> savedOrder, List<String> live) {
    final liveSet = live.toSet();
    final out = <String>[];
    for (final n in savedOrder) {
      if (liveSet.contains(n) && !out.contains(n)) out.add(n);
    }
    for (final n in live) {
      if (!out.contains(n)) out.add(n);
    }
    return out;
  }

  void _moveProject(int index, int dir) {
    final j = index + dir;
    if (j < 0 || j >= _draftOrder.length) return;
    setState(() {
      final next = [..._draftOrder];
      final tmp = next[index];
      next[index] = next[j];
      next[j] = tmp;
      _draftOrder = next;
    });
  }

  void _toggle(Set<String> set, String name) {
    setState(() {
      if (set.contains(name)) {
        set.remove(name);
      } else {
        set.add(name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final profileData = ref.watch(_profileDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: _buildAppBarActions(profileData, user),
      ),
      body: profileData.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryStart),
        ),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(_profileDataProvider),
        ),
        data: (data) => RefreshIndicator(
          color: AppColors.primaryStart,
          onRefresh: () async => ref.invalidate(_profileDataProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: _buildBody(data, user, isDark),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAppBarActions(
    AsyncValue<ProfilePageResponse> profileData,
    UserModel? user,
  ) {
    if (_editMode) {
      return [
        TextButton(
          onPressed: _saving ? null : _cancelEdit,
          child: const Text('Cancel'),
        ),
        TextButton.icon(
          onPressed: _saving ? null : _saveEdit,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check, size: 18),
          label: const Text('Save'),
        ),
      ];
    }
    return [
      // "Customize display" puts the user into the visibility/order
      // edit mode without leaving the screen — matching the website's
      // single Edit profile button which flips the page into edit mode.
      IconButton(
        tooltip: 'Customize display',
        icon: const Icon(Icons.tune, size: 20),
        onPressed: profileData.maybeWhen(
          data: (data) => () => _enterEditMode(data, user),
          orElse: () => null,
        ),
      ),
      TextButton.icon(
        onPressed: () => context.push('/profile/edit'),
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: const Text('Edit'),
      ),
    ];
  }

  List<Widget> _buildBody(
    ProfilePageResponse data,
    UserModel? user,
    bool isDark,
  ) {
    final prefs = user?.profilePreferences;
    final hiddenProjects = _editMode
        ? _draftHiddenProjects
        : <String>{...?prefs?.hiddenProjectNames};
    final hiddenSkills = _editMode
        ? _draftHiddenSkills
        : <String>{...?prefs?.hiddenSkillNames};
    final hiddenApps = _editMode
        ? _draftHiddenApps
        : <String>{...?prefs?.hiddenAppNames};
    final hiddenLangs = _editMode
        ? _draftHiddenLangs
        : <String>{...?prefs?.hiddenLanguageNames};
    final order = _editMode
        ? _draftOrder
        : _mergeOrder(
            prefs?.projectOrder ?? const [],
            data.projects.map((p) => p.projectName).toList(),
          );
    final projectByName = {for (final p in data.projects) p.projectName: p};

    final visibleSkills = _editMode
        ? data.topSkills
        : data.topSkills
            .where((s) => !hiddenSkills.contains(s.name))
            .take(_maxGlobalVisible)
            .toList();
    final visibleApps = _editMode
        ? data.topApps
        : data.topApps
            .where((a) => !hiddenApps.contains(a.name))
            .take(_maxGlobalVisible)
            .toList();
    final visibleLangs = _editMode
        ? data.topLanguages
        : data.topLanguages
            .where((l) => !hiddenLangs.contains(l.name))
            .take(_maxGlobalVisible)
            .toList();

    return [
      if (_editMode) _editBanner(isDark),
      _heroCard(user, isDark),
      const SizedBox(height: 16),
      GlassCard(child: ProfileMetricsGrid(data: data)),
      if (visibleSkills.isNotEmpty || _editMode) ...[
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
                _editMode
                    ? 'Tap the eye icon to hide a skill from your profile.'
                    : 'All projects · up to $_maxGlobalVisible shown',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.darkSecondaryText
                      : AppColors.lightSecondaryText,
                ),
              ),
              const SizedBox(height: 12),
              ...visibleSkills.map(
                (s) => ProgressRow(
                  name: s.name,
                  percent: s.percent,
                  isDark: isDark,
                  hidden: _editMode ? hiddenSkills.contains(s.name) : null,
                  onToggleHide: _editMode
                      ? () => _toggle(_draftHiddenSkills, s.name)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
      if (data.projects.isNotEmpty) ...[
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Projects',
                icon: Icons.folder_open,
              ),
              if (_editMode) ...[
                const SizedBox(height: 4),
                Text(
                  'Use the arrows to reorder · tap the eye to hide.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkSecondaryText
                        : AppColors.lightSecondaryText,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ..._buildProjectCards(
                data: data,
                order: order,
                projectByName: projectByName,
                hidden: hiddenProjects,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
      if (visibleApps.isNotEmpty || _editMode) ...[
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Top Apps', icon: Icons.apps),
              const SizedBox(height: 12),
              ...visibleApps.map(
                (a) => AppRow(
                  name: a.name,
                  hours: a.durationHours,
                  percent: a.percent,
                  isDark: isDark,
                  hidden: _editMode ? hiddenApps.contains(a.name) : null,
                  onToggleHide: _editMode
                      ? () => _toggle(_draftHiddenApps, a.name)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
      if (visibleLangs.isNotEmpty || _editMode) ...[
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Languages', icon: Icons.code),
              const SizedBox(height: 12),
              if (!_editMode)
                LangBar(
                  languages: visibleLangs
                      .map((l) => LangBarSegment(
                            name: l.name,
                            percent: l.percent / 100,
                          ))
                      .toList(),
                ),
              if (!_editMode) const SizedBox(height: 12),
              ...visibleLangs.map(
                (l) => LanguageRow(
                  name: l.name,
                  percent: l.percent,
                  lines: l.lines,
                  isDark: isDark,
                  color: LangBar.langColor(l.name),
                  hidden: _editMode ? hiddenLangs.contains(l.name) : null,
                  onToggleHide: _editMode
                      ? () => _toggle(_draftHiddenLangs, l.name)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  Widget _editBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primaryStart.withValues(alpha: 0.18)
            : AppColors.primaryStart.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryStart.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune, size: 18, color: AppColors.primaryStart),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Customize what other developers see on your public profile. '
              'Reorder projects and toggle visibility, then tap Save.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCard(UserModel? user, bool isDark) {
    return GlassCard(
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
                color: isDark
                    ? AppColors.darkSecondaryText
                    : AppColors.lightSecondaryText,
              ),
            ),
          ],
          if (user?.createdAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Joined ${_formatDate(user!.createdAt!)}',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkSecondaryText
                    : AppColors.lightSecondaryText,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (user?.githubUrl?.isNotEmpty ?? false)
                _SocialIcon(
                    icon: Icons.code, tooltip: 'GitHub', url: user!.githubUrl!),
              if (user?.linkedinUrl?.isNotEmpty ?? false)
                _SocialIcon(
                    icon: Icons.business,
                    tooltip: 'LinkedIn',
                    url: user!.linkedinUrl!),
              if (user?.twitterUrl?.isNotEmpty ?? false)
                _SocialIcon(
                    icon: Icons.alternate_email,
                    tooltip: 'Twitter',
                    url: user!.twitterUrl!),
            ],
          ),
        ],
      ),
    );
  }

  /// Build the list of project tiles. In edit mode we render every
  /// project in the user-controlled order with eye + reorder buttons.
  /// In view mode we filter out hidden projects but still respect the
  /// saved order so re-arranging takes effect immediately.
  List<Widget> _buildProjectCards({
    required ProfilePageResponse data,
    required List<String> order,
    required Map<String, ProfileProjectCard> projectByName,
    required Set<String> hidden,
    required bool isDark,
  }) {
    final tiles = <Widget>[];
    for (var i = 0; i < order.length; i++) {
      final name = order[i];
      final card = projectByName[name];
      if (card == null) continue;
      if (!_editMode && hidden.contains(name)) continue;
      tiles.add(
        ProjectTile(
          project: card,
          isDark: isDark,
          hidden: _editMode ? hidden.contains(name) : null,
          onToggleHide:
              _editMode ? () => _toggle(_draftHiddenProjects, name) : null,
          onMoveUp: _editMode ? () => _moveProject(i, -1) : null,
          onMoveDown: _editMode ? () => _moveProject(i, 1) : null,
          canMoveUp: _editMode && i > 0,
          canMoveDown: _editMode && i < order.length - 1,
        ),
      );
    }
    if (tiles.isEmpty) {
      tiles.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'No projects to show. Use Customize display to unhide cards.',
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.darkSecondaryText
                  : AppColors.lightSecondaryText,
            ),
          ),
        ),
      );
    }
    return tiles;
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
