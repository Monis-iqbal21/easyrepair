import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/chat_entities.dart';
import '../providers/chat_providers.dart';

class ChatListPage extends ConsumerWidget {
  /// Route prefix for detail navigation — '/client/chat' or '/worker/chat'.
  final String detailRoutePrefix;

  /// Bottom nav bar widget to render below the list.
  final Widget bottomNavigationBar;

  const ChatListPage({
    super.key,
    required this.detailRoutePrefix,
    required this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(chatConversationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Text(
                'Messages',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            Expanded(
              child: conversationsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Color(0xFFDE7356)),
                  ),
                ),
                error: (err, _) => _ErrorView(
                  message: err.toString(),
                  onRetry: () => ref
                      .read(chatConversationsProvider.notifier)
                      .refresh(),
                ),
                data: (conversations) => conversations.isEmpty
                    ? _EmptyView()
                    : RefreshIndicator(
                        color: const Color(0xFFDE7356),
                        onRefresh: () => ref
                            .read(chatConversationsProvider.notifier)
                            .refresh(),
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 110),
                          itemCount: conversations.length,
                          itemBuilder: (context, index) {
                            return _ConversationTile(
                              conversation: conversations[index],
                              onTap: () => context.push(
                                '$detailRoutePrefix/${conversations[index].id}',
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationEntity conversation;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final participant = conversation.otherParticipant;
    final preview = conversation.lastMessagePreview;
    final timeStr = _formatTime(conversation.lastMessageAt);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          children: [
            _Avatar(participant: participant),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          participant.fullName.isNotEmpty
                              ? participant.fullName
                              : 'User',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timeStr != null)
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),
                  if (preview != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      preview,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _formatTime(String? isoString) {
    if (isoString == null) return null;
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final msgDay = DateTime(dt.year, dt.month, dt.day);
      if (msgDay == today) {
        final h = dt.hour.toString().padLeft(2, '0');
        final m = dt.minute.toString().padLeft(2, '0');
        return '$h:$m';
      }
      final diff = today.difference(msgDay).inDays;
      if (diff == 1) return 'Yesterday';
      if (diff < 7) {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days[dt.weekday - 1];
      }
      return '${dt.day}/${dt.month}/${dt.year % 100}';
    } catch (_) {
      return null;
    }
  }
}

class _Avatar extends StatelessWidget {
  final ConversationParticipantEntity participant;

  const _Avatar({required this.participant});

  @override
  Widget build(BuildContext context) {
    final url = participant.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundImage: NetworkImage(url),
        backgroundColor: const Color(0xFFE2E8F0),
      );
    }
    return CircleAvatar(
      radius: 26,
      backgroundColor: const Color(0xFFDE7356),
      child: Text(
        participant.initials.isNotEmpty ? participant.initials : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 52,
            color: Color(0xFF94A3B8),
          ),
          SizedBox(height: 14),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Messages will appear here',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                'Retry',
                style: TextStyle(color: Color(0xFFDE7356)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
