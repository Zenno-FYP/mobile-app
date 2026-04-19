import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/tag_badge.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/data/models/dashboard_models.dart';

final _peersSearchProvider = StateNotifierProvider<_PeersSearchNotifier, AsyncValue<List<PeerCard>>>((ref) {
  // Tied to the user session so logout drops the cached peer list.
  ref.watch(userSessionProvider);
  final notifier = _PeersSearchNotifier(DashboardRepository(ref.watch(apiClientProvider)));
  // Mirror the website: load everyone by default so users see developers
  // the moment the page opens, even before they type anything.
  notifier.search('');
  return notifier;
});

class _PeersSearchNotifier extends StateNotifier<AsyncValue<List<PeerCard>>> {
  _PeersSearchNotifier(this._repo) : super(const AsyncValue.loading());
  final DashboardRepository _repo;

  /// Searches the peer directory. An empty query returns the full
  /// developer list (browse mode), matching the website behaviour.
  Future<void> search(String query) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.searchPeers(query.trim());
      state = AsyncValue.data(result.peers);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

class PeersScreen extends ConsumerStatefulWidget {
  const PeersScreen({super.key});

  @override
  ConsumerState<PeersScreen> createState() => _PeersScreenState();
}

class _PeersScreenState extends ConsumerState<PeersScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _lastSearched = '';

  void _onChanged(String value) {
    // Debounce search-as-you-type by 350ms so we don't fire a network
    // request on every keystroke. Submit/Search button still triggers
    // the lookup immediately via _runSearch().
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _runSearch(value);
    });
  }

  void _runSearch(String value) {
    final trimmed = value.trim();
    if (trimmed == _lastSearched) return;
    _lastSearched = trimmed;
    ref.read(_peersSearchProvider.notifier).search(trimmed);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final peersState = ref.watch(_peersSearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Peers'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Search name, skills, projects, apps…',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: peersState.isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryStart,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      onChanged: _onChanged,
                      onSubmitted: _runSearch,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GradientButton(
                    onPressed: () => _runSearch(_controller.text),
                    label: 'Search',
                    width: 90,
                    height: 44,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: peersState.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryStart)),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (peers) {
                final hasQuery = _controller.text.trim().isNotEmpty;
                if (peers.isEmpty) {
                  return RefreshIndicator(
                    color: AppColors.primaryStart,
                    onRefresh: () => ref
                        .read(_peersSearchProvider.notifier)
                        .search(_controller.text),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        EmptyState(
                          icon: Icons.people_outline,
                          title: hasQuery ? 'No matches yet' : 'No developers yet',
                          subtitle: hasQuery
                              ? 'Try another keyword, or invite teammates to Zenno.'
                              : 'Be the first — invite your teammates to Zenno.',
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primaryStart,
                  onRefresh: () => ref
                      .read(_peersSearchProvider.notifier)
                      .search(_controller.text),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: peers.length,
                    itemBuilder: (context, i) => _PeerTile(peer: peers[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Peer card mirroring the website's `PeersPage` layout: avatar + name +
/// bio at the top, then a labeled `Skills` / `Projects` / `Apps`
/// section underneath so users can scan a developer's full surface area
/// before opening the public profile.
class _PeerTile extends StatelessWidget {
  const _PeerTile({required this.peer});
  final PeerCard peer;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary =
        isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;
    final hasBio = peer.bio.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: () => context.push('/peers/${peer.userId}/profile'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppAvatar(
                  imageUrl: peer.profilePhotoUrl,
                  name: peer.name,
                  size: 56,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        peer.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasBio ? peer.bio : 'No bio',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle:
                              hasBio ? FontStyle.normal : FontStyle.italic,
                          color: secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: secondary),
              ],
            ),
            if (peer.topSkills.isNotEmpty) ...[
              const SizedBox(height: 14),
              _PeerSection(
                label: 'Skills',
                isDark: isDark,
                child: Wrap(
                  spacing: 6, runSpacing: 6,
                  children: peer.topSkills
                      .map((s) => TagBadge(label: s, isGradient: true))
                      .toList(),
                ),
              ),
            ],
            if (peer.topProjects.isNotEmpty) ...[
              const SizedBox(height: 10),
              _PeerSection(
                label: 'Projects',
                isDark: isDark,
                child: Wrap(
                  spacing: 6, runSpacing: 6,
                  children: peer.topProjects
                      .map((p) => TagBadge(label: p))
                      .toList(),
                ),
              ),
            ],
            if (peer.topApps.isNotEmpty) ...[
              const SizedBox(height: 10),
              _PeerSection(
                label: 'Apps',
                isDark: isDark,
                child: Wrap(
                  spacing: 6, runSpacing: 6,
                  children: peer.topApps
                      .map((a) => _PeerAppChip(label: a, isDark: isDark))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PeerSection extends StatelessWidget {
  const _PeerSection({
    required this.label,
    required this.child,
    required this.isDark,
  });
  final String label;
  final Widget child;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final muted =
        isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: muted,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _PeerAppChip extends StatelessWidget {
  const _PeerAppChip({required this.label, required this.isDark});
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x1AFFFFFF) : const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0x14000000),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white70 : const Color(0xFF374151),
        ),
      ),
    );
  }
}
