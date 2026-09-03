import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/services/chat_socket_service.dart';
import '../../../../core/storage/local_cache_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../data/models/chat_models.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/repositories/chat_repository.dart';

// ── Infrastructure ─────────────────────────────────────────────────────────────

final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>((ref) {
  return ChatRemoteDataSourceImpl(
    ref.watch(dioProvider),
    ref.watch(localCacheServiceProvider),
    ref.watch(secureStorageServiceProvider),
  );
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(ref.watch(chatRemoteDataSourceProvider));
});

// ── Conversations list notifier ────────────────────────────────────────────────

/// True while [chatConversationsProvider] is showing the last cached list
/// because the live fetch failed.
final chatConversationsIsOfflineProvider = StateProvider<bool>((ref) => false);

/// Returns the canonical inbox order used by both Client and Ustaad chat.
///
/// The backend remains authoritative for which conversations exist and for
/// the relative order of ordinary conversations. This presentation guard only
/// removes duplicate ids, collapses duplicate Support rows, and permanently
/// places the one real Support conversation at index 0.
List<ConversationEntity> normalizeChatConversations(
  Iterable<ConversationEntity> conversations,
) {
  ConversationEntity? support;
  final normal = <ConversationEntity>[];
  final seenIds = <String>{};

  for (final conversation in conversations) {
    if (!seenIds.add(conversation.id)) continue;
    if (conversation.isSupport) {
      support ??= conversation;
    } else {
      normal.add(conversation);
    }
  }

  return <ConversationEntity>[?support, ...normal];
}

/// This subscription outlives inbox rebuilds. Binding it inside the async
/// notifier's build leaves a gap between invalidate/dispose and the next
/// build, losing messages that arrive while an earlier GET is in flight.
final _chatRealtimeSyncProvider = StreamProvider<int>((ref) {
  final socket = ref.watch(chatSocketServiceProvider);
  final revisions = StreamController<int>();
  var revision = 0;
  void refresh() => revisions.add(++revision);
  final subscriptions = <StreamSubscription<dynamic>>[
    // Personal-room updates arrive on Home too, without an unreadCount.
    socket.onConversationUpdated.listen((_) => refresh()),
    socket.onNewMessage.listen((_) => refresh()),
    // Refresh only after the server has persisted the seen receipt.
    socket.onMessageSeen.listen((_) => refresh()),
    socket.onConnected.listen((_) => refresh()),
  ];
  ref.onDispose(() {
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
    revisions.close();
  });
  return revisions.stream;
});

class ChatConversationsNotifier
    extends AsyncNotifier<List<ConversationEntity>> {
  @override
  Future<List<ConversationEntity>> build() async {
    ref.watch(_chatRealtimeSyncProvider);
    return _fetch();
  }

  Future<List<ConversationEntity>> _fetch() async {
    // Repair path only: the backend already ensures this thread on every login,
    // so this covers users who signed in before support existed. Its failure is
    // deliberately swallowed — losing the support row for one refresh is far
    // better than an unusable Chat tab.
    await ref.read(chatRepositoryProvider).ensureSupportConversation();
    final result = await ref.read(chatRepositoryProvider).getConversations();
    return result.fold((f) => throw f, (cached) {
      ref.read(chatConversationsIsOfflineProvider.notifier).state =
          cached.isStale;
      return normalizeChatConversations(cached.data);
    });
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // The previous inbox remains visible on a background refresh failure.
    }
  }

  /// Inserts or updates a conversation while preserving the canonical order.
  ///
  /// Ordinary updates retain the existing newest-first behavior. Support
  /// updates replace any existing Support row and remain permanently pinned.
  void upsertConversation(ConversationEntity updated) {
    final current = state.valueOrNull ?? [];
    final next = current
        .where(
          (conversation) =>
              conversation.id != updated.id &&
              !(updated.isSupport && conversation.isSupport),
        )
        .toList();
    next.insert(0, updated);
    state = AsyncData(normalizeChatConversations(next));
  }
}

final chatConversationsProvider =
    AsyncNotifierProvider<ChatConversationsNotifier, List<ConversationEntity>>(
      ChatConversationsNotifier.new,
    );

/// Shared by Client and Worker navigation; kept alive across tab changes.
final unreadConversationCountProvider = Provider<int>((ref) {
  final conversations = ref.watch(chatConversationsProvider).valueOrNull;
  return conversations?.where((c) => c.unreadCount > 0).length ?? 0;
});

// ── Messages notifier ──────────────────────────────────────────────────────────

/// True while [chatMessagesProvider] for a given conversation is showing the
/// last cached messages because the live fetch failed.
final chatMessagesIsOfflineProvider = StateProvider.family<bool, String>(
  (ref, conversationId) => false,
);

class ChatMessagesNotifier
    extends FamilyAsyncNotifier<List<MessageEntity>, String> {
  static const _pageSize = 50;

  StreamSubscription<Map<String, dynamic>>? _newMsgSub;
  StreamSubscription<Map<String, dynamic>>? _seenSub;
  StreamSubscription<Map<String, dynamic>>? _editedSub;
  StreamSubscription<Map<String, dynamic>>? _deletedSub;
  bool _isLoadingOlder = false;
  bool _hasOlderMessages = true;

  bool get isLoadingOlder => _isLoadingOlder;
  bool get hasOlderMessages => _hasOlderMessages;

  @override
  Future<List<MessageEntity>> build(String arg) async {
    _newMsgSub?.cancel();
    _seenSub?.cancel();
    _editedSub?.cancel();
    _deletedSub?.cancel();

    final connectedSub = ref
        .read(chatSocketServiceProvider)
        .onConnected
        .listen((_) => ref.invalidateSelf());
    ref.onDispose(connectedSub.cancel);

    // ── new_message ──────────────────────────────────────────────────────────
    _newMsgSub = ref.read(chatSocketServiceProvider).onNewMessage.listen((
      data,
    ) {
      // Ignore messages for other conversations.
      if ((data['conversationId'] as String?) != arg) return;
      try {
        final entity = MessageModel.fromJson(data).toEntity();
        final current = state.valueOrNull ?? [];
        // Dedup: the sender already appended via HTTP response.
        if (current.any((m) => m.id == entity.id)) return;
        state = AsyncData([...current, entity]);
      } catch (_) {}
    });

    // ── message_seen ─────────────────────────────────────────────────────────
    _seenSub = ref.read(chatSocketServiceProvider).onMessageSeen.listen((data) {
      final messageId = data['messageId'] as String?;
      final seenAt = data['seenAt'] as String?;
      if (messageId == null || seenAt == null) return;
      final current = state.valueOrNull ?? [];
      final idx = current.indexWhere((m) => m.id == messageId);
      if (idx == -1) return;
      final next = List<MessageEntity>.from(current);
      next[idx] = current[idx].withSeenAt(seenAt);
      state = AsyncData(next);
    });

    // ── message_edited ───────────────────────────────────────────────────────
    _editedSub = ref.read(chatSocketServiceProvider).onMessageEdited.listen((
      data,
    ) {
      if ((data['conversationId'] as String?) != arg) return;
      try {
        final updated = MessageModel.fromJson(data).toEntity();
        final current = state.valueOrNull ?? [];
        final idx = current.indexWhere((m) => m.id == updated.id);
        if (idx == -1) return;
        final next = List<MessageEntity>.from(current);
        next[idx] = updated;
        state = AsyncData(next);
      } catch (_) {}
    });

    // ── message_deleted ──────────────────────────────────────────────────────
    _deletedSub = ref.read(chatSocketServiceProvider).onMessageDeleted.listen((
      data,
    ) {
      final messageId = data['messageId'] as String?;
      final deletedAt = data['deletedAt'] as String?;
      if (messageId == null || deletedAt == null) return;
      final current = state.valueOrNull ?? [];
      final idx = current.indexWhere((m) => m.id == messageId);
      if (idx == -1) return;
      final next = List<MessageEntity>.from(current);
      next[idx] = current[idx].withDeleted(deletedAt);
      state = AsyncData(next);
    });

    ref.onDispose(() {
      _newMsgSub?.cancel();
      _seenSub?.cancel();
      _editedSub?.cancel();
      _deletedSub?.cancel();
    });

    final messages = await _fetch(arg);
    _hasOlderMessages = messages.length >= _pageSize;
    return messages;
  }

  Future<List<MessageEntity>> _fetch(String conversationId) async {
    final result = await ref
        .read(chatRepositoryProvider)
        .getMessages(conversationId);
    return result.fold((f) => throw f, (cached) {
      ref.read(chatMessagesIsOfflineProvider(conversationId).notifier).state =
          cached.isStale;
      // Backend returns newest-first; reverse for display (oldest first).
      return cached.data.reversed.toList();
    });
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final messages = await _fetch(arg);
      _hasOlderMessages = messages.length >= _pageSize;
      return messages;
    });
  }

  /// Loads the page immediately older than the first rendered message.
  ///
  /// The backend returns newest-first, so the page is reversed and prepended
  /// to the display list. The page owns the scroll-extent compensation that
  /// keeps the reader's viewport anchored while these rows are inserted.
  Future<int> loadOlder() async {
    final current = state.valueOrNull ?? const <MessageEntity>[];
    if (_isLoadingOlder || !_hasOlderMessages || current.isEmpty) return 0;

    _isLoadingOlder = true;
    try {
      final result = await ref
          .read(chatRepositoryProvider)
          .getMessages(arg, limit: _pageSize, before: current.first.createdAt);
      return result.fold((failure) => throw failure, (page) {
        final older = page.data.reversed
            .where((candidate) => !current.any((m) => m.id == candidate.id))
            .toList();
        _hasOlderMessages = page.data.length >= _pageSize;
        if (older.isNotEmpty) state = AsyncData([...older, ...current]);
        return older.length;
      });
    } finally {
      _isLoadingOlder = false;
    }
  }

  /// Append a freshly sent/received message to the end of the list.
  /// Silently drops duplicates (dedup by id).
  void append(MessageEntity message) {
    final current = state.valueOrNull ?? [];
    if (current.any((m) => m.id == message.id)) return;
    state = AsyncData([...current, message]);
  }

  /// Replace an existing message by id (used after edit).
  void updateMessage(MessageEntity updated) {
    final current = state.valueOrNull ?? [];
    final idx = current.indexWhere((m) => m.id == updated.id);
    if (idx == -1) return;
    final next = List<MessageEntity>.from(current);
    next[idx] = updated;
    state = AsyncData(next);
  }

  /// Soft-delete a message in the local list (used after delete).
  void markDeleted(String messageId, String deletedAt) {
    final current = state.valueOrNull ?? [];
    final idx = current.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    final next = List<MessageEntity>.from(current);
    next[idx] = current[idx].withDeleted(deletedAt);
    state = AsyncData(next);
  }
}

final chatMessagesProvider =
    AsyncNotifierProvider.family<
      ChatMessagesNotifier,
      List<MessageEntity>,
      String
    >(ChatMessagesNotifier.new);

// ── Send text message notifier ─────────────────────────────────────────────────

class SendMessageNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> send(String conversationId, String text) async {
    state = const AsyncLoading();
    final result = await ref
        .read(chatRepositoryProvider)
        .sendMessage(conversationId, text);
    result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        throw failure;
      },
      (message) {
        state = const AsyncData(null);
        // Append to the messages list immediately (HTTP response path).
        // Socket new_message will be deduped.
        ref.read(chatMessagesProvider(conversationId).notifier).append(message);
      },
    );
  }
}

final sendMessageProvider = AsyncNotifierProvider<SendMessageNotifier, void>(
  SendMessageNotifier.new,
);

// ── Get or create conversation notifier ───────────────────────────────────────

class GetOrCreateConversationNotifier
    extends AsyncNotifier<ConversationEntity?> {
  @override
  Future<ConversationEntity?> build() async => null;

  Future<ConversationEntity> getOrCreate(
    String bookingId,
    String workerProfileId,
  ) async {
    state = const AsyncLoading();
    final result = await ref
        .read(chatRepositoryProvider)
        .getOrCreateConversation(bookingId, workerProfileId);
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        throw failure;
      },
      (conversation) {
        state = AsyncData(conversation);
        // Ensure it appears in the conversations list.
        ref
            .read(chatConversationsProvider.notifier)
            .upsertConversation(conversation);
        return conversation;
      },
    );
  }
}

final getOrCreateConversationProvider =
    AsyncNotifierProvider<GetOrCreateConversationNotifier, ConversationEntity?>(
      GetOrCreateConversationNotifier.new,
    );

// ── Get or create conversation for a booking (worker pre-bid chat) ────────────

class GetOrCreateConversationForBookingNotifier
    extends AsyncNotifier<ConversationEntity?> {
  @override
  Future<ConversationEntity?> build() async => null;

  Future<ConversationEntity> getOrCreate(String bookingId) async {
    state = const AsyncLoading();
    final result = await ref
        .read(chatRepositoryProvider)
        .getOrCreateConversationForBooking(bookingId);
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        throw failure;
      },
      (conversation) {
        state = AsyncData(conversation);
        // Ensure it appears in the worker's conversations list.
        ref
            .read(chatConversationsProvider.notifier)
            .upsertConversation(conversation);
        return conversation;
      },
    );
  }
}

final getOrCreateConversationForBookingProvider =
    AsyncNotifierProvider<
      GetOrCreateConversationForBookingNotifier,
      ConversationEntity?
    >(GetOrCreateConversationForBookingNotifier.new);
