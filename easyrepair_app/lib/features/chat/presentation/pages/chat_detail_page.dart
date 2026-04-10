import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/chat_socket_service.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/chat_entities.dart';
import '../providers/chat_providers.dart';

class ChatDetailPage extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatDetailPage({super.key, required this.conversationId});

  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends ConsumerState<ChatDetailPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Join the socket room so we receive new_message / message_seen events.
    ChatSocketService.instance.joinConversation(widget.conversationId);
    // Mark unread messages as seen once messages are rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) => _markLastSeen());
  }

  @override
  void dispose() {
    ChatSocketService.instance.leaveConversation(widget.conversationId);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Emit mark_seen for the most-recent message from the other participant
  /// that has not yet been seen.  The server is idempotent so calling this
  /// multiple times is safe.
  void _markLastSeen() {
    if (!mounted) return;
    final messages =
        ref.read(chatMessagesProvider(widget.conversationId)).valueOrNull;
    if (messages == null || messages.isEmpty) return;
    final currentUserId =
        ref.read(authStateProvider).valueOrNull?.id ?? '';
    for (int i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      if (msg.senderUserId != currentUserId && msg.seenAt == null) {
        ChatSocketService.instance.markSeen(widget.conversationId, msg.id);
        break;
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    _controller.clear();
    setState(() => _isSending = true);

    try {
      await ref
          .read(sendMessageProvider.notifier)
          .send(widget.conversationId, text);
      // Scroll to bottom after message is appended.
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.conversationId));
    final authAsync = ref.watch(authStateProvider);
    final currentUserId = authAsync.valueOrNull?.id ?? '';

    // When new messages arrive, mark the latest received one as seen.
    ref.listen(chatMessagesProvider(widget.conversationId), (_, next) {
      if (next.hasValue) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _markLastSeen());
      }
    });

    // Determine conversation from the cached list.
    final conversations = ref.watch(chatConversationsProvider).valueOrNull;
    final conversation = conversations?.firstWhere(
      (c) => c.id == widget.conversationId,
      orElse: () => _emptyConversation(),
    );
    final participant = conversation?.otherParticipant;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1A1A1A), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: participant != null && participant.userId.isNotEmpty
              ? () => _showParticipantTray(context, participant)
              : null,
          child: Row(
            children: [
              _AppBarAvatar(
                avatarUrl: participant?.avatarUrl,
                initials: participant?.initials ?? '?',
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  participant?.fullName.isNotEmpty == true
                      ? participant!.fullName
                      : 'Chat',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFFFF5F15)),
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Color(0xFFEF4444)),
                      const SizedBox(height: 12),
                      Text(err.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF6B7280))),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => ref
                            .read(chatMessagesProvider(widget.conversationId)
                                .notifier)
                            .refresh(),
                        child: const Text('Retry',
                            style: TextStyle(color: Color(0xFFFF5F15))),
                      ),
                    ],
                  ),
                ),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Say hello!',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    ),
                  );
                }

                // Index of the last message I sent that the other side has seen.
                // Only this bubble shows the "Seen" label so it stays clean.
                int lastSeenSentIndex = -1;
                for (int i = messages.length - 1; i >= 0; i--) {
                  if (messages[i].senderUserId == currentUserId &&
                      messages[i].seenAt != null) {
                    lastSeenSentIndex = i;
                    break;
                  }
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderUserId == currentUserId;

                    // Show date separator when the calendar day changes.
                    final showSeparator = index == 0 ||
                        _differentDay(
                          messages[index - 1].createdAt,
                          message.createdAt,
                        );

                    return Column(
                      children: [
                        if (showSeparator)
                          _DateSeparator(isoString: message.createdAt),
                        message.type == ChatMessageType.system
                            ? _SystemMessageBubble(message: message)
                            : _MessageBubble(
                                message: message,
                                isMe: isMe,
                                showSeen: isMe &&
                                    index == lastSeenSentIndex,
                              ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _InputBar(
            controller: _controller,
            isSending: _isSending,
            onSend: _send,
          ),
        ],
      ),
    );
  }

  void _showParticipantTray(
    BuildContext context,
    ConversationParticipantEntity participant,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ParticipantTray(participant: participant),
    );
  }

  bool _differentDay(String a, String b) {
    try {
      final da = DateTime.parse(a).toLocal();
      final db = DateTime.parse(b).toLocal();
      return da.year != db.year || da.month != db.month || da.day != db.day;
    } catch (_) {
      return false;
    }
  }

  ConversationEntity _emptyConversation() {
    return ConversationEntity(
      id: widget.conversationId,
      clientUserId: '',
      workerUserId: '',
      createdByUserId: '',
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
      otherParticipant: const ConversationParticipantEntity(
        userId: '',
        firstName: '',
        lastName: '',
      ),
    );
  }
}

// ── Participant tray ───────────────────────────────────────────────────────────

class _ParticipantTray extends StatelessWidget {
  final ConversationParticipantEntity participant;

  const _ParticipantTray({required this.participant});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomPadding),
            child: Column(
              children: [
                // Large avatar
                _TrayAvatar(participant: participant),
                const SizedBox(height: 14),
                // Name
                Text(
                  participant.fullName.isNotEmpty
                      ? participant.fullName
                      : 'User',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                  textAlign: TextAlign.center,
                ),
                // Rating row — only for workers
                if (participant.rating != null) ...[
                  const SizedBox(height: 10),
                  _RatingRow(rating: participant.rating!),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrayAvatar extends StatelessWidget {
  final ConversationParticipantEntity participant;

  const _TrayAvatar({required this.participant});

  @override
  Widget build(BuildContext context) {
    final url = participant.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 42,
        backgroundImage: NetworkImage(url),
        backgroundColor: const Color(0xFFE2E8F0),
      );
    }
    return CircleAvatar(
      radius: 42,
      backgroundColor: const Color(0xFFFF5F15),
      child: Text(
        participant.initials.isNotEmpty ? participant.initials : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 28,
        ),
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  final double rating;

  const _RatingRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    // Fill whole / half / empty stars out of 5.
    final filled = rating.floor();
    final hasHalf = (rating - filled) >= 0.25;
    final empty = 5 - filled - (hasHalf ? 1 : 0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < filled; i++)
          const Icon(Icons.star_rounded, size: 20, color: Color(0xFFF59E0B)),
        if (hasHalf)
          const Icon(Icons.star_half_rounded,
              size: 20, color: Color(0xFFF59E0B)),
        for (int i = 0; i < empty; i++)
          const Icon(Icons.star_outline_rounded,
              size: 20, color: Color(0xFFD1D5DB)),
        const SizedBox(width: 6),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const Text(
          ' / 5',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────────

class _AppBarAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String initials;

  const _AppBarAvatar({this.avatarUrl, required this.initials});

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: NetworkImage(avatarUrl!),
        backgroundColor: const Color(0xFFE2E8F0),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFFFF5F15),
      child: Text(
        initials.isNotEmpty ? initials : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageEntity message;
  final bool isMe;
  /// Show "Seen" label below this bubble (only on last seen sent message).
  final bool showSeen;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.showSeen = false,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(message.createdAt);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(
              top: 4,
              bottom: showSeen ? 2 : 4,
              left: isMe ? 64 : 0,
              right: isMe ? 0 : 64,
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFFFF5F15) : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.isDeleted
                      ? 'This message was deleted'
                      : (message.text ?? ''),
                  style: TextStyle(
                    fontSize: 14,
                    color: isMe ? Colors.white : const Color(0xFF1A1A1A),
                    fontStyle: message.isDeleted
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.75)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          // "Seen" label — shown only below the last sent message that was seen.
          if (showSeen)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, right: 4),
              child: Text(
                'Seen',
                style: TextStyle(
                  fontSize: 11,
                  color: const Color(0xFF94A3B8).withValues(alpha: 0.85),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }
}

class _SystemMessageBubble extends StatelessWidget {
  final MessageEntity message;

  const _SystemMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.text ?? '',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final String isoString;

  const _DateSeparator({required this.isoString});

  @override
  Widget build(BuildContext context) {
    final label = _formatDate(isoString);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
        ],
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final msgDay = DateTime(dt.year, dt.month, dt.day);
      if (msgDay == today) return 'Today';
      if (today.difference(msgDay).inDays == 1) return 'Yesterday';
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomPadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                maxLines: 5,
                minLines: 1,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1A1A1A),
                ),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: isSending ? null : onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSending
                    ? const Color(0xFFFF5F15).withValues(alpha: 0.5)
                    : const Color(0xFFFF5F15),
                shape: BoxShape.circle,
              ),
              child: isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
