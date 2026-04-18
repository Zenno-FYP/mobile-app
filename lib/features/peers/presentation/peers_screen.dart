import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/tag_badge.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/data/models/dashboard_models.dart';

final _peersSearchProvider = StateNotifierProvider<_PeersSearchNotifier, AsyncValue<List<PeerCard>>>((ref) {
  return _PeersSearchNotifier(DashboardRepository(ref.watch(apiClientProvider)));
});

class _PeersSearchNotifier extends StateNotifier<AsyncValue<List<PeerCard>>> {
  _PeersSearchNotifier(this._repo) : super(const AsyncValue.data([]));
  final DashboardRepository _repo;

  Future<void> search(String query) async {
    if (query.trim().isEmpty) { state = const AsyncValue.data([]); return; }
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final peersState = ref.watch(_peersSearchProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Find Peers')),
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
                      decoration: const InputDecoration(
                        hintText: 'Search by name, skills, projects...',
                        prefixIcon: Icon(Icons.search, size: 20),
                      ),
                      onSubmitted: (v) => ref.read(_peersSearchProvider.notifier).search(v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GradientButton(
                    onPressed: () => ref.read(_peersSearchProvider.notifier).search(_controller.text),
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
                if (peers.isEmpty && _controller.text.isNotEmpty) {
                  return const EmptyState(icon: Icons.people_outline, title: 'No peers found', subtitle: 'Try a different search term');
                }
                if (peers.isEmpty) {
                  return const EmptyState(icon: Icons.search, title: 'Search for peers', subtitle: 'Find developers by name, skills, projects, or apps');
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: peers.length,
                  itemBuilder: (context, i) => _PeerTile(peer: peers[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PeerTile extends StatelessWidget {
  const _PeerTile({required this.peer});
  final PeerCard peer;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: () => context.push('/peers/${peer.userId}/profile'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAvatar(imageUrl: peer.profilePhotoUrl, name: peer.name, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(peer.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  if (peer.bio.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(peer.bio, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                  ],
                  const SizedBox(height: 8),
                  if (peer.topSkills.isNotEmpty)
                    Wrap(
                      spacing: 4, runSpacing: 4,
                      children: peer.topSkills.take(4).map((s) => TagBadge(label: s, isGradient: true)).toList(),
                    ),
                  if (peer.topProjects.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4, runSpacing: 4,
                      children: peer.topProjects.take(3).map((p) => TagBadge(label: p)).toList(),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
          ],
        ),
      ),
    );
  }
}
