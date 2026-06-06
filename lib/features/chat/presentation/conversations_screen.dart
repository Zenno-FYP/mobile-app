import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/chat_repository.dart';
import '../data/models/chat_models.dart';
import '../data/chat_socket_service.dart';

final chatSocketProvider = Provider<ChatSocketService>((ref) {
  // Tear the socket down on logout: bumping `userSessionProvider`
  // invalidates this provider, fires the `onDispose` below, and the next
  // read creates a fresh service so the next signed-in user gets their
  // own connection (with their own auth token).
  ref.watch(userSessionProvider);
  final service = ChatSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

final _conversationsProvider = FutureProvider<List<Conversation>>((ref) {
  ref.watch(userSessionProvider);
  return ChatRepository(ref.watch(apiClientProvider)).getConversations();
});

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final socket = ref.read(chatSocketProvider);
      if (!socket.isConnected) socket.connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    final convs = ref.watch(_conversationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/peers'),
        backgroundColor: AppColors.primaryStart,
        foregroundColor: Colors.white,
        tooltip: 'Find peers',
        child: const Icon(Icons.person_add_alt_1),
      ),
      body: convs.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryStart)),
        error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(_conversationsProvider)),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'No conversations yet',
              subtitle: 'Find a peer and start chatting!',
            );
          }
          return RefreshIndicator(
            color: AppColors.primaryStart,
            onRefresh: () async => ref.invalidate(_conversationsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final conv = list[i];
                return _ConversationTile(conv: conv);
              },
            ),
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conv});
  final Conversation conv;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderRadius: 16,
        onTap: () => context.push('/chats/${conv.id}', extra: conv.otherUser),
        child: Row(
          children: [
            AppAvatar(imageUrl: conv.otherUser.profilePhoto, name: conv.otherUser.name, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(conv.otherUser.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  if (conv.lastMessageText != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      conv.lastMessageText!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (conv.lastMessageAt != null)
                  Text(
                    _formatTime(conv.lastMessageAt!),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                    ),
                  ),
                if (conv.unreadCount > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.unreadBadge,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${conv.unreadCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return DateFormat.Hm().format(dt);
      }
      return DateFormat.MMMd().format(dt);
    } catch (_) {
      return '';
    }
  }
}
