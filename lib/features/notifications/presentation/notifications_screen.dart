import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../data/fcm_service.dart';
import '../data/notification_models.dart';

/// Single-page convenience: returns the first page.
///
/// We keep this around so that the bell badge / shell can keep using a simple
/// `FutureProvider` for the `unreadCount` field. The full paginated list is
/// owned by [NotificationsScreen] state directly so we can append pages
/// without invalidating + refetching from page 1.
final notificationsProvider = FutureProvider<
    ({List<NotificationItem> items, int unreadCount, bool hasMore})>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.fetchNotifications();
});

final unreadCountProvider = FutureProvider<int>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getUnreadCount();
});

/// Filter chip for the notifications list.
enum _NotifFilter { all, chat, project, digest }

extension on _NotifFilter {
  String get label {
    switch (this) {
      case _NotifFilter.all:
        return 'All';
      case _NotifFilter.chat:
        return 'Chats';
      case _NotifFilter.project:
        return 'Projects';
      case _NotifFilter.digest:
        return 'Digests';
    }
  }

  bool matches(NotificationItem n) {
    switch (this) {
      case _NotifFilter.all:
        return true;
      case _NotifFilter.chat:
        return n.type == 'chat_message';
      case _NotifFilter.project:
        return n.type == 'new_project';
      case _NotifFilter.digest:
        return n.type == 'daily_digest';
    }
  }
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<NotificationItem> _items = [];

  _NotifFilter _filter = _NotifFilter.all;
  int _page = 1;
  bool _hasMore = true;
  bool _loadingFirst = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Trigger pagination when within 300px of the bottom.
    if (!_hasMore || _loadingMore || _loadingFirst) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadNextPage();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loadingFirst = true;
      _error = null;
    });
    try {
      final repo = ref.read(notificationRepositoryProvider);
      final res = await repo.fetchNotifications(page: 1);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(res.items);
        _hasMore = res.hasMore;
        _page = 1;
        _loadingFirst = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loadingFirst = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    setState(() => _loadingMore = true);
    try {
      final repo = ref.read(notificationRepositoryProvider);
      final res = await repo.fetchNotifications(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(res.items);
        _page += 1;
        _hasMore = res.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Keep _hasMore true so the user can scroll & retry.
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(unreadCountProvider);
    ref.invalidate(notificationsProvider);
    await _loadFirstPage();
  }

  Future<void> _markAllRead() async {
    HapticFeedback.selectionClick();
    final repo = ref.read(notificationRepositoryProvider);
    try {
      await repo.markAllRead();
    } catch (_) {/* best effort */}
    if (!mounted) return;
    setState(() {
      // Mutate locally so the screen reflects the change instantly even before
      // the next refresh.
      for (var i = 0; i < _items.length; i++) {
        if (_items[i].isUnread) {
          _items[i] = _items[i].copyWith(
            readAt: DateTime.now().toIso8601String(),
          );
        }
      }
    });
    ref.invalidate(unreadCountProvider);
    ref.invalidate(notificationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _items.where(_filter.matches).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _items.any((n) => n.isUnread) ? _markAllRead : null,
            child: Text(
              'Mark all read',
              style: TextStyle(
                color: isDark ? AppColors.primaryStart : AppColors.primaryEnd,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterChips(
            current: _filter,
            onChanged: (f) => setState(() => _filter = f),
            isDark: isDark,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _buildBody(isDark, filtered),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark, List<NotificationItem> filtered) {
    if (_loadingFirst) {
      // Shimmer placeholders that roughly mirror a notification row so the
      // page does not collapse to a tiny spinner on first load.
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const ShimmerLoader(width: 40, height: 40, borderRadius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerLoader(height: 14),
                  SizedBox(height: 8),
                  ShimmerLoader(height: 12, width: 220),
                  SizedBox(height: 6),
                  ShimmerLoader(height: 10, width: 60),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (_error != null && _items.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Icon(Icons.error_outline,
              size: 56,
              color: isDark
                  ? AppColors.darkSecondaryText
                  : AppColors.lightSecondaryText),
          const SizedBox(height: 12),
          Text(
            'Could not load notifications',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.darkSecondaryText
                  : AppColors.lightSecondaryText,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _loadFirstPage,
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }
    if (filtered.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Icon(Icons.notifications_none,
              size: 64,
              color: isDark
                  ? AppColors.darkSecondaryText
                  : AppColors.lightSecondaryText),
          const SizedBox(height: 12),
          Text(
            _filter == _NotifFilter.all
                ? 'No notifications yet'
                : 'No ${_filter.label.toLowerCase()} notifications',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.darkSecondaryText
                  : AppColors.lightSecondaryText,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index >= filtered.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final n = filtered[index];
        return _NotificationTile(
          item: n,
          isDark: isDark,
          onTap: () => _handleTap(n),
        );
      },
    );
  }

  Future<void> _handleTap(NotificationItem n) async {
    if (n.isUnread) {
      HapticFeedback.selectionClick();
      try {
        await ref.read(notificationRepositoryProvider).markRead(n.id);
      } catch (_) {/* best effort */}
      if (!mounted) return;
      setState(() {
        final idx = _items.indexWhere((it) => it.id == n.id);
        if (idx != -1) {
          _items[idx] = _items[idx].copyWith(
            readAt: DateTime.now().toIso8601String(),
          );
        }
      });
      ref.invalidate(unreadCountProvider);
    }
    if (!mounted) return;
    switch (n.type) {
      case 'chat_message':
        final convId = n.data['conversationId'];
        if (convId != null && convId.isNotEmpty) {
          context.push('/chats/$convId');
        } else {
          context.go('/chats');
        }
        break;
      case 'new_project':
        final projectName = n.data['projectName'];
        if (projectName != null && projectName.isNotEmpty) {
          context.push('/projects/$projectName');
        } else {
          context.go('/dashboard');
        }
        break;
      case 'daily_digest':
        context.go('/dashboard');
        break;
      default:
        // Unknown notification type — stay on this screen rather than throwing
        // the user to an unrelated route. Surfacing a snackbar keeps things
        // honest if a new backend type slips through.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(n.title.isNotEmpty ? n.title : 'Notification opened'),
          ),
        );
    }
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.current,
    required this.onChanged,
    required this.isDark,
  });

  final _NotifFilter current;
  final ValueChanged<_NotifFilter> onChanged;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _NotifFilter.values.map((f) {
            final selected = current == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f.label),
                selected: selected,
                onSelected: (_) => onChanged(f),
                selectedColor:
                    AppColors.primaryStart.withValues(alpha: 0.18),
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? AppColors.primaryStart
                      : (isDark
                          ? AppColors.darkSecondaryText
                          : AppColors.lightSecondaryText),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.isDark,
    required this.onTap,
  });

  final NotificationItem item;
  final bool isDark;
  final VoidCallback onTap;

  IconData get _icon {
    switch (item.type) {
      case 'chat_message':
        return Icons.chat_bubble;
      case 'new_project':
        return Icons.create_new_folder;
      case 'daily_digest':
        return Icons.bar_chart;
      default:
        return Icons.notifications;
    }
  }

  List<Color> get _gradient {
    switch (item.type) {
      case 'chat_message':
        return [AppColors.pink, AppColors.pinkLight];
      case 'new_project':
        return [AppColors.teal, AppColors.tealDark];
      case 'daily_digest':
        return [AppColors.primaryStart, AppColors.primaryEnd];
      default:
        return [AppColors.primaryStart, AppColors.primaryEnd];
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _gradient),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: item.isUnread
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (item.isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryStart,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkSecondaryText
                          : AppColors.lightSecondaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _timeAgo(item.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkSecondaryText
                          : AppColors.lightSecondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }
}
