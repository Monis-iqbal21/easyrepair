import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/network/offline_banner.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/utils/support_search.dart';
import '../../domain/entities/chat_entities.dart';
import '../providers/chat_providers.dart';

/// Asset used as the HandyGo Support avatar (same logo as splash / auth header).
const String kSupportAvatarAsset = 'assets/images/logo-green.png';

class ChatListPage extends ConsumerStatefulWidget {
  final String detailRoutePrefix;
  final Widget bottomNavigationBar;
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

  List<ConversationEntity> _visibleConversations(
    List<ConversationEntity> conversations,
  ) {
    final canonical = normalizeChatConversations(conversations);
    final query = _query.trim();
    if (query.isEmpty) return canonical;

    ConversationEntity? support;
    final matches = <ConversationEntity>[];
    for (final conversation in canonical) {
      if (conversation.isSupport) {
        support ??= conversation;
      } else if (_matchesConversation(conversation, query)) {
        matches.add(conversation);
      }
    }

    return <ConversationEntity>[
      if (support != null && matchesSupport(query)) support,
      ...matches,
    ];
  }

  bool _matchesConversation(ConversationEntity conversation, String query) {
    final needle = query.toLowerCase();
    if (conversation.otherParticipant.fullName.toLowerCase().contains(needle)) {
      return true;
    }
    return conversation.lastMessagePreview?.toLowerCase().contains(needle) ==
        true;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final conversationsAsync = ref.watch(chatConversationsProvider);
    final isShowingCachedData =
        ref.watch(chatConversationsIsOfflineProvider) &&
        conversationsAsync.hasValue;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(widget.homeRoute);
      },
      child: Scaffold(
        backgroundColor: c.background,
        extendBody: true,
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Text(
                      context.l10n.chatListTitle,
                      style: TextStyle(
                        fontSize: 24,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      textInputAction: TextInputAction.search,
                      style: TextStyle(fontSize: 14, color: c.textPrimary),
                      decoration: InputDecoration(
                        hintText: context.l10n.chatSearchHint,
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: c.textSecondary,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: c.textSecondary,
                        ),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                color: c.textSecondary,
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              ),
                        filled: true,
                        fillColor: c.surface,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: c.controlBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: c.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: c.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  if (isShowingCachedData) const OfflineDataBanner(),
                  Expanded(
                    child: conversationsAsync.when(
                      loading: () => Center(
                        child: CircularProgressIndicator(color: c.primary),
                      ),
                      error: (error, _) => _ErrorView(
                        message: failureMessage(context.l10n, error),
                        onRetry: () => ref
                            .read(chatConversationsProvider.notifier)
                            .refresh(),
                      ),
                      data: (conversations) {
                        final visible = _visibleConversations(conversations);
                        if (visible.isEmpty) {
                          return _query.trim().isEmpty
                              ? const _EmptyView()
                              : const _NoResultsView();
                        }
                        return RefreshIndicator(
                          color: c.primary,
                          onRefresh: () => ref
                              .read(chatConversationsProvider.notifier)
                              .refresh(),
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final conversation = visible[index];
                              return _ConversationTile(
                                key: ValueKey(conversation.id),
                                conversation: conversation,
                                onTap: () async {
                                  await context.push(
                                    '${widget.detailRoutePrefix}/${conversation.id}',
                                  );
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
    super.key,
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final participant = conversation.otherParticipant;
    final preview = conversation.lastMessagePreview;
    final time = _formatTime(context, conversation.lastMessageAt);
    final unread = conversation.unreadCount;
    final support = conversation.isSupport;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: support ? c.softTeal : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: support ? c.primary.withValues(alpha: 0.35) : c.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _Avatar(participant: participant, isSupport: support),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        participant.fullName.isNotEmpty
                            ? participant.fullName
                            : context.l10n.commonUser,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: unread > 0
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                      if (preview != null && preview.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.25,
                            color: unread > 0 ? c.textPrimary : c.textSecondary,
                            fontWeight: unread > 0
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (time != null)
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: unread > 0
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: unread > 0 ? c.primary : c.textSecondary,
                        ),
                      ),
                    if (unread > 0) ...[
                      const SizedBox(height: 5),
                      Container(
                        constraints: const BoxConstraints(minWidth: 20),
                        height: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: c.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _formatTime(BuildContext context, String? isoString) {
    if (isoString == null) return null;
    try {
      final date = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDay = DateTime(date.year, date.month, date.day);
      if (messageDay == today) {
        final hour = date.hour.toString().padLeft(2, '0');
        final minute = date.minute.toString().padLeft(2, '0');
        return '$hour:$minute';
      }
      final difference = today.difference(messageDay).inDays;
      if (difference == 1) return context.l10n.commonYesterday;
      if (difference < 7) {
        final l10n = context.l10n;
        final days = <String>[
          l10n.weekdayMon,
          l10n.weekdayTue,
          l10n.weekdayWed,
          l10n.weekdayThu,
          l10n.weekdayFri,
          l10n.weekdaySat,
          l10n.weekdaySun,
        ];
        return days[date.weekday - 1];
      }
      return '${date.day}/${date.month}/${date.year % 100}';
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
    final c = context.semanticColors;
    if (isSupport) {
      return Container(
        width: 50,
        height: 50,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: c.surface,
          shape: BoxShape.circle,
          border: Border.all(color: c.border),
        ),
        child: ClipOval(
          child: Image.asset(kSupportAvatarAsset, fit: BoxFit.contain),
        ),
      );
    }

    final url = participant.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 25,
        backgroundImage: NetworkImage(url),
        backgroundColor: c.surfaceSubtle,
      );
    }
    return CircleAvatar(
      radius: 25,
      backgroundColor: c.primary,
      child: Text(
        participant.initials.isNotEmpty ? participant.initials : '?',
        style: TextStyle(
          color: c.onPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: c.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              context.l10n.chatEmptyTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.chatEmptySubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsView extends StatelessWidget {
  const _NoResultsView();

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: c.textSecondary),
            const SizedBox(height: 14),
            Text(
              context.l10n.chatNoResultsTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.chatNoResultsSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
          ],
        ),
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
    final c = context.semanticColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: c.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: Text(
                context.l10n.commonRetry,
                style: TextStyle(color: c.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
