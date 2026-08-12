import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/network/offline_banner.dart';
import '../../../../core/utils/support_search.dart';
import '../../domain/entities/chat_entities.dart';
import '../providers/chat_providers.dart';

/// Asset used as the HandyGo Support avatar (same logo as splash / auth header).
const String kSupportAvatarAsset = 'assets/images/logo-green.png';

class ChatListPage extends ConsumerStatefulWidget {
  /// Route prefix for detail navigation — '/client/chat' or '/worker/chat'.
  final String detailRoutePrefix;

  /// Bottom nav bar widget to render below the list.
  final Widget bottomNavigationBar;

  /// Route to navigate to when Android back is pressed on this page.
  final String homeRoute;

  const ChatListPage({
    super.key,
    required this.detailRoutePrefix,
    required this.bottomNavigationBar,
    required this.homeRoute,
  });

  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Builds the rendered order: HandyGo Support first, then everything else.
  ///
  /// Pinning happens here rather than in the notifier because
  /// [ChatConversationsNotifier.upsertConversation] inserts at index 0 on every
  /// `conversation_updated` socket event and would otherwise push Support down.
  List<ConversationEntity> _visibleConversations(
    List<ConversationEntity> all,
  ) {
    final query = _query.trim();

    // `firstWhereOrNull` semantics without the extra dependency — taking only
    // the first also guarantees a single Support row even if the list ever
    // carried a duplicate.
    ConversationEntity? support;
    final others = <ConversationEntity>[];
    for (final c in all) {
      if (c.isSupport) {
        support ??= c;
      } else {
        others.add(c);
      }
    }

    final filteredOthers = query.isEmpty
        ? others
        : others.where((c) => _matchesConversation(c, query)).toList();

    // Support is matched only against its own alias list, never against
    // conversation text, so an unrelated search cannot surface it.
    final showSupport = support != null && matchesSupport(query);

    return [
      if (showSupport) support,
      ...filteredOthers,
    ];
  }

  bool _matchesConversation(ConversationEntity c, String query) {
    final needle = query.toLowerCase();
    if (c.otherParticipant.fullName.toLowerCase().contains(needle)) return true;
    final preview = c.lastMessagePreview?.toLowerCase();
    return preview != null && preview.contains(needle);
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(chatConversationsProvider);
    final isShowingCachedData = ref.watch(chatConversationsIsOfflineProvider) &&
        conversationsAsync.hasValue;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(widget.homeRoute);
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                context.l10n.chatListTitle,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: context.l10n.chatSearchHint,
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9CA3AF),
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20,
                    color: Color(0xFF6B7280),
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          color: const Color(0xFF6B7280),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDB6234)),
                  ),
                ),
              ),
            ),
            if (isShowingCachedData) const OfflineDataBanner(),
            Expanded(
              child: conversationsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Color(0xFFDB6234)),
                  ),
                ),
                error: (err, _) => _ErrorView(
                  message: failureMessage(context.l10n, err),
                  onRetry: () => ref
                      .read(chatConversationsProvider.notifier)
                      .refresh(),
                ),
                data: (conversations) {
                  final visible = _visibleConversations(conversations);
                  if (visible.isEmpty) {
                    return _query.trim().isEmpty
                        ? _EmptyView()
                        : const _NoResultsView();
                  }
                  return RefreshIndicator(
                    color: const Color(0xFFDB6234),
                    onRefresh: () =>
                        ref.read(chatConversationsProvider.notifier).refresh(),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 110),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final conversation = visible[index];
                        return _ConversationTile(
                          conversation: conversation,
                          onTap: () async {
                            await context.push(
                              '${widget.detailRoutePrefix}/${conversation.id}',
                            );
                            // Refresh unread counts when returning from chat detail.
                            ref
                                .read(chatConversationsProvider.notifier)
                                .refresh();
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.bottomNavigationBar,
    ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationEntity conversation;
  final Future<void> Function() onTap;

  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final participant = conversation.otherParticipant;
    final preview = conversation.lastMessagePreview;
    final timeStr = _formatTime(context, conversation.lastMessageAt);

    final unread = conversation.unreadCount;

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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Avatar(
              participant: participant,
              isSupport: conversation.isSupport,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    participant.fullName.isNotEmpty
                        ? participant.fullName
                        : context.l10n.commonUser,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: unread > 0
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (preview != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      preview,
                      style: TextStyle(
                        fontSize: 13,
                        color: unread > 0
                            ? const Color(0xFF1A1A1A)
                            : const Color(0xFF6B7280),
                        fontWeight: unread > 0
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right side: time on top, unread badge below
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (timeStr != null)
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: unread > 0
                          ? const Color(0xFFDB6234)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                if (unread > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDB6234),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
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

  String? _formatTime(BuildContext context, String? isoString) {
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
      if (diff == 1) return context.l10n.commonYesterday;
      if (diff < 7) {
        final l10n = context.l10n;
        final days = [
          l10n.weekdayMon,
          l10n.weekdayTue,
          l10n.weekdayWed,
          l10n.weekdayThu,
          l10n.weekdayFri,
          l10n.weekdaySat,
          l10n.weekdaySun,
        ];
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
  final bool isSupport;

  const _Avatar({required this.participant, this.isSupport = false});

  @override
  Widget build(BuildContext context) {
    if (isSupport) {
      // The support account is a system user with no uploaded avatar — always
      // render the official HandyGo logo instead of initials.
      return CircleAvatar(
        radius: 26,
        backgroundColor: Colors.white,
        child: ClipOval(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Image.asset(
              kSupportAvatarAsset,
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }
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
      backgroundColor: const Color(0xFFDB6234),
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
    return Center(
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
            context.l10n.chatEmptyTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          SizedBox(height: 6),
          Text(
            context.l10n.chatEmptySubtitle,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _NoResultsView extends StatelessWidget {
  const _NoResultsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 52, color: Color(0xFF94A3B8)),
          SizedBox(height: 14),
          Text(
            context.l10n.chatNoResultsTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          SizedBox(height: 6),
          Text(
            context.l10n.chatNoResultsSubtitle,
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
              child: Text(
                context.l10n.commonRetry,
                style: TextStyle(color: Color(0xFFDB6234)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
