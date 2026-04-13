import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/services/chat_socket_service.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../data/models/chat_models.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/repositories/chat_repository.dart';

// ── Infrastructure ─────────────────────────────────────────────────────────────

final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>((ref) {
  return ChatRemoteDataSourceImpl(ref.watch(dioProvider));
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(ref.watch(chatRemoteDataSourceProvider));
});

// ── Conversations list notifier ────────────────────────────────────────────────

class ChatConversationsNotifier
    extends AsyncNotifier<List<ConversationEntity>> {
  StreamSubscription<Map<String, dynamic>>? _socketSub;

  @override
  Future<List<ConversationEntity>> build() async {
    _socketSub?.cancel();

    // Listen for conversation_updated events (e.g. new message preview).
    _socketSub =
        ChatSocketService.instance.onConversationUpdated.listen((data) {
      final conversationId = data['conversationId'] as String?;
      if (conversationId == null) return;
      final current = state.valueOrNull ?? [];
      final idx = current.indexWhere((c) => c.id == conversationId);
      if (idx == -1) return;
      final c = current[idx];
      final updated = ConversationEntity(
        id: c.id,
        clientUserId: c.clientUserId,
        workerUserId: c.workerUserId,
        createdByUserId: c.createdByUserId,
        lastMessageAt: data['lastMessageAt'] as String?,
        lastMessagePreview: data['lastMessagePreview'] as String?,
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
        otherParticipant: c.otherParticipant,
      );
      upsertConversation(updated);
    });

    ref.onDispose(() => _socketSub?.cancel());

    return _fetch();
  }

  Future<List<ConversationEntity>> _fetch() async {
    final result = await ref.read(chatRepositoryProvider).getConversations();
    return result.fold((f) => throw f, (list) => list);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Insert or update a conversation at the top of the list (most recent first).
  void upsertConversation(ConversationEntity updated) {
    final current = state.valueOrNull ?? [];
    final idx = current.indexWhere((c) => c.id == updated.id);
    final next = List<ConversationEntity>.from(current);
    if (idx == -1) {
      next.insert(0, updated);
    } else {
      next.removeAt(idx);
      next.insert(0, updated);
    }
    state = AsyncData(next);
  }
}

final chatConversationsProvider =
    AsyncNotifierProvider<ChatConversationsNotifier, List<ConversationEntity>>(
  ChatConversationsNotifier.new,
);

// ── Messages notifier ──────────────────────────────────────────────────────────

class ChatMessagesNotifier
    extends FamilyAsyncNotifier<List<MessageEntity>, String> {
  StreamSubscription<Map<String, dynamic>>? _newMsgSub;
  StreamSubscription<Map<String, dynamic>>? _seenSub;
  StreamSubscription<Map<String, dynamic>>? _editedSub;
  StreamSubscription<Map<String, dynamic>>? _deletedSub;

  @override
  Future<List<MessageEntity>> build(String arg) async {
    _newMsgSub?.cancel();
    _seenSub?.cancel();
    _editedSub?.cancel();
    _deletedSub?.cancel();

    // ── new_message ──────────────────────────────────────────────────────────
    _newMsgSub = ChatSocketService.instance.onNewMessage.listen((data) {
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
    _seenSub = ChatSocketService.instance.onMessageSeen.listen((data) {
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
    _editedSub = ChatSocketService.instance.onMessageEdited.listen((data) {
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
    _deletedSub = ChatSocketService.instance.onMessageDeleted.listen((data) {
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

    return _fetch(arg);
  }

  Future<List<MessageEntity>> _fetch(String conversationId) async {
    final result = await ref
        .read(chatRepositoryProvider)
        .getMessages(conversationId);
    return result.fold((f) => throw f, (list) {
      // Backend returns newest-first; reverse for display (oldest first).
      return list.reversed.toList();
    });
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(arg));
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
    AsyncNotifierProvider.family<ChatMessagesNotifier, List<MessageEntity>,
        String>(
  ChatMessagesNotifier.new,
);

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

final sendMessageProvider =
    AsyncNotifierProvider<SendMessageNotifier, void>(SendMessageNotifier.new);

// ── Get or create conversation notifier ───────────────────────────────────────

class GetOrCreateConversationNotifier
    extends AsyncNotifier<ConversationEntity?> {
  @override
  Future<ConversationEntity?> build() async => null;

  Future<ConversationEntity> getOrCreate(String workerProfileId) async {
    state = const AsyncLoading();
    final result = await ref
        .read(chatRepositoryProvider)
        .getOrCreateConversation(workerProfileId);
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
