import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/chat_repository.dart';
import '../data/chat_socket_service.dart';
import '../data/models/chat_models.dart';
import 'conversations_screen.dart';

class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen({
    super.key,
    required this.conversationId,
    this.otherUser,
  });

  final String conversationId;

  /// Optional pre-loaded user info passed via `extra` from the conversations
  /// list to avoid an extra round-trip; if null we fetch the conversation
  /// summary from the inbox.
  final ConversationUser? otherUser;

  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends ConsumerState<ThreadScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  ConversationUser? _otherUser;
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  bool _hasMore = true;
  String? _error;

  StreamSubscription<NewMessageEvent>? _socketSub;

  @override
  void initState() {
    super.initState();
    _otherUser = widget.otherUser;
    _scrollController.addListener(_onScroll);
    _listenSocket();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final repo = ChatRepository(ref.read(apiClientProvider));

    if (_otherUser == null) {
      final conv = await repo.findConversation(widget.conversationId);
      if (mounted) setState(() => _otherUser = conv?.otherUser);
    }

    await _loadMessages();
    unawaited(_markRead());
  }

  void _listenSocket() {
    final socket = ref.read(chatSocketProvider);
    _socketSub = socket.onNewMessage.listen((event) {
      if (event.conversationId != widget.conversationId) return;
      final isDuplicate = _messages.any((m) => m.id == event.message.id);
      if (isDuplicate) return;
      setState(() {
        _messages.removeWhere((m) => m.id.startsWith('temp_'));
        _messages.add(event.message);
      });
      _scrollToBottom();
      unawaited(_markRead());
    });
  }

  Future<void> _markRead() async {
    try {
      await ChatRepository(ref.read(apiClientProvider))
          .markRead(widget.conversationId);
    } catch (_) {
      // Read receipts are non-critical; surface on the next interaction.
    }
  }

  Future<void> _loadMessages() async {
    try {
      final msgs = await ChatRepository(ref.read(apiClientProvider))
          .getMessages(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _loading = false;
        _hasMore = msgs.length >= 30;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingMore || !_hasMore || _messages.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final older = await ChatRepository(ref.read(apiClientProvider))
          .getMessages(widget.conversationId, before: _messages.first.id);
      if (!mounted) return;
      setState(() {
        if (older.isEmpty) {
          _hasMore = false;
        } else {
          _messages.insertAll(0, older);
        }
      });
    } catch (_) {
      // Silent fail - the user can pull to refresh
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 80) _loadOlder();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;

    final recipient = _otherUser?.id;
    if (recipient == null || recipient.isEmpty) {
      _showSnack('Cannot send: recipient unknown.');
      return;
    }

    // Light tactile confirmation as soon as the user commits to sending.
    HapticFeedback.lightImpact();

    final user = ref.read(currentUserProvider);
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = ChatMessage(
      id: tempId,
      senderId: user?.id ?? '',
      body: text,
      createdAt: DateTime.now().toIso8601String(),
    );

    setState(() {
      _messages.add(optimistic);
      _sending = true;
    });
    _textController.clear();
    _scrollToBottom();

    try {
      final socket = ref.read(chatSocketProvider);
      if (!socket.isConnected) await socket.connect();

      final saved = await socket.sendMessage(
        recipientUserId: recipient,
        text: text,
      );
      if (!mounted) return;
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == tempId);
        if (idx != -1) _messages[idx] = saved;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.removeWhere((m) => m.id == tempId));
      _showSnack('Failed to send: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _onReportConversation() async {
    final controller = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Report conversation'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Reason (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            maxLength: 500,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
    final reason = controller.text;
    controller.dispose();
    if (submit != true || !mounted) return;

    try {
      await ChatRepository(ref.read(apiClientProvider)).reportConversation(
        widget.conversationId,
        reason: reason,
      );
      if (!mounted) return;
      _showSnack('Report submitted. Thank you.');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isConflict) {
        _showSnack('You already have an open report for this conversation.');
      } else {
        _showSnack(e.message);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not submit report: $e');
    }
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _textController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _ChatHeader(user: _otherUser),
        actions: [
          IconButton(
            icon: const Icon(Icons.outlined_flag),
            tooltip: 'Report conversation',
            onPressed: () => unawaited(_onReportConversation()),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages(isDark, currentUserId)),
          _Composer(
            controller: _textController,
            sending: _sending,
            onSend: _send,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildMessages(bool isDark, String currentUserId) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryStart));
    }
    if (_error != null && _messages.isEmpty) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load chat',
        subtitle: _error,
      );
    }
    if (_messages.isEmpty) {
      return const EmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'No messages yet',
        subtitle: 'Say hello to start the conversation.',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (_loadingMore && i == 0) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final idx = _loadingMore ? i - 1 : i;
        final msg = _messages[idx];
        final prev = idx > 0 ? _messages[idx - 1] : null;
        final isMine = msg.senderId == currentUserId;
        final showTimestamp = prev == null ||
            _shouldShowTimestamp(prev.createdAt, msg.createdAt);

        return Column(
          children: [
            if (showTimestamp)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _formatDay(msg.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkSecondaryText
                        : AppColors.lightSecondaryText,
                  ),
                ),
              ),
            _Bubble(message: msg, isMine: isMine, isDark: isDark),
          ],
        );
      },
    );
  }

  bool _shouldShowTimestamp(String prevIso, String currentIso) {
    try {
      final prev = DateTime.parse(prevIso);
      final cur = DateTime.parse(currentIso);
      return cur.difference(prev).inMinutes > 30 || prev.day != cur.day;
    } catch (_) {
      return false;
    }
  }

  String _formatDay(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return 'Today, ${DateFormat.Hm().format(dt)}';
      }
      return DateFormat('MMM d, HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.isDark,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
              color: isDark ? const Color(0x1AFFFFFF) : const Color(0x1A000000)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0x1AFFFFFF)
                      : const Color(0xFFF3F3F5),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: sending ? null : onSend,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient:
                      sending ? null : AppColors.primaryGradient,
                  color: sending ? Colors.grey.shade400 : null,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: sending
                    ? const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(
      {required this.message, required this.isMine, required this.isDark});
  final ChatMessage message;
  final bool isMine;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
        decoration: BoxDecoration(
          gradient: isMine ? AppColors.primaryGradient : null,
          color: isMine
              ? null
              : (isDark
                  ? const Color(0x1AFFFFFF)
                  : const Color(0xFFF3F3F5)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.body,
              style: TextStyle(
                fontSize: 14,
                color: isMine
                    ? Colors.white
                    : (isDark ? AppColors.darkText : AppColors.lightText),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatTime(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: isMine
                    ? const Color(0xB3FFFFFF)
                    : (isDark
                        ? AppColors.darkSecondaryText
                        : AppColors.lightSecondaryText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      return DateFormat.Hm().format(DateTime.parse(iso));
    } catch (_) {
      return '';
    }
  }
}

/// AppBar title showing the other participant's avatar and name. Tapping
/// anywhere on the header opens the same public profile that the Peers tab
/// uses, keeping the deep-link contract consistent across surfaces.
class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.user});
  final ConversationUser? user;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final u = user;
    final hasUser = u != null && u.id.isNotEmpty;

    return InkWell(
      onTap: hasUser ? () => context.push('/peers/${u.id}/profile') : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAvatar(
              imageUrl: u?.profilePhoto,
              name: u?.name,
              size: 36,
              borderWidth: 1.5,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u?.name ?? 'Chat',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (hasUser)
                    Text(
                      'View profile',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
}
