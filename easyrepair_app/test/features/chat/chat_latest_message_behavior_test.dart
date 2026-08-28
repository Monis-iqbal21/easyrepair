import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:handygo_app/core/data/cached_result.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';
import 'package:handygo_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:handygo_app/features/chat/domain/entities/chat_entities.dart';
import 'package:handygo_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:handygo_app/features/chat/presentation/pages/chat_detail_page.dart';
import 'package:handygo_app/features/chat/presentation/providers/chat_providers.dart';

import '../../support/l10n_test_app.dart';

const _conversationId = 'conversation-1';

class _ClientAuthNotifier extends AuthStateNotifier {
  @override
  Future<UserEntity?> build() async => const UserEntity(
    id: 'me',
    phone: '+923000000000',
    role: 'CLIENT',
    firstName: 'Sara',
    lastName: 'Khan',
  );
}

MessageEntity _message(int index, {String sender = 'other'}) {
  final createdAt = DateTime.utc(
    2026,
    8,
    20,
    10,
  ).add(Duration(minutes: index)).toIso8601String();
  return MessageEntity(
    id: 'message-$index',
    conversationId: _conversationId,
    senderUserId: sender,
    senderRole: sender == 'me' ? 'CLIENT' : 'WORKER',
    type: ChatMessageType.text,
    text: 'Message $index with enough content to occupy a visible chat row.',
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

final _conversation = ConversationEntity(
  id: _conversationId,
  clientUserId: 'me',
  workerUserId: 'other',
  createdByUserId: 'me',
  createdAt: '2026-08-20T10:00:00.000Z',
  updatedAt: '2026-08-20T12:00:00.000Z',
  otherParticipant: const ConversationParticipantEntity(
    userId: 'other',
    firstName: 'Ali',
    lastName: 'Khan',
  ),
);

class _PagedChatRepository implements ChatRepository {
  _PagedChatRepository(this.allMessages);

  final List<MessageEntity> allMessages;
  int olderPageRequests = 0;

  @override
  Future<Either<Failure, CachedResult<List<ConversationEntity>>>>
  getConversations() async => Right(CachedResult([_conversation]));

  @override
  Future<Either<Failure, CachedResult<List<MessageEntity>>>> getMessages(
    String conversationId, {
    int limit = 50,
    String? before,
  }) async {
    var eligible = allMessages;
    if (before != null) {
      olderPageRequests++;
      final cursor = DateTime.parse(before);
      eligible = allMessages
          .where(
            (message) => DateTime.parse(message.createdAt).isBefore(cursor),
          )
          .toList();
    }
    final start = eligible.length > limit ? eligible.length - limit : 0;
    return Right(CachedResult(eligible.sublist(start).reversed.toList()));
  }

  @override
  Future<Either<Failure, void>> ensureSupportConversation() async =>
      const Right(null);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used');
}

Future<(ProviderContainer, _PagedChatRepository)> _pumpConversation(
  WidgetTester tester,
) async {
  await tester.binding.setSurfaceSize(const Size(390, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repository = _PagedChatRepository([
    for (var index = 0; index < 80; index++) _message(index),
  ]);
  final container = ProviderContainer(
    overrides: [
      chatRepositoryProvider.overrideWithValue(repository),
      authStateProvider.overrideWith(_ClientAuthNotifier.new),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: localizedApp(
        const ChatDetailPage(conversationId: _conversationId),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container, repository);
}

ScrollController _messageScrollController(WidgetTester tester) =>
    tester.widget<ListView>(find.byType(ListView)).controller!;

void main() {
  testWidgets('newly opened scrollable conversation starts at latest message', (
    tester,
  ) async {
    await _pumpConversation(tester);
    final controller = _messageScrollController(tester);

    expect(controller.position.maxScrollExtent, greaterThan(0));
    expect(controller.offset, controller.position.maxScrollExtent);
    expect(find.textContaining('Message 79'), findsOneWidget);
  });

  testWidgets('incoming messages preserve an older viewport and count unseen', (
    tester,
  ) async {
    final (container, _) = await _pumpConversation(tester);
    final controller = _messageScrollController(tester);
    controller.jumpTo(controller.position.maxScrollExtent - 320);
    await tester.pump();
    final anchoredOffset = controller.offset;

    container
        .read(chatMessagesProvider(_conversationId).notifier)
        .append(_message(80));
    await tester.pump();
    await tester.pump();

    expect(controller.offset, anchoredOffset);
    expect(find.byKey(const Key('new-message-indicator')), findsOneWidget);
    expect(find.text('1 new message'), findsOneWidget);

    container
        .read(chatMessagesProvider(_conversationId).notifier)
        .append(_message(81));
    container
        .read(chatMessagesProvider(_conversationId).notifier)
        .append(_message(82));
    await tester.pump();
    await tester.pump();

    expect(controller.offset, anchoredOffset);
    expect(find.text('3 new messages'), findsOneWidget);

    await tester.tap(find.byKey(const Key('new-message-indicator')));
    await tester.pumpAndSettle();

    expect(controller.offset, controller.position.maxScrollExtent);
    expect(find.byKey(const Key('new-message-indicator')), findsNothing);
  });

  testWidgets('incoming message keeps a near-bottom reader at latest', (
    tester,
  ) async {
    final (container, _) = await _pumpConversation(tester);
    final controller = _messageScrollController(tester);
    controller.jumpTo(controller.position.maxScrollExtent - 40);
    await tester.pump();

    container
        .read(chatMessagesProvider(_conversationId).notifier)
        .append(_message(80));
    await tester.pumpAndSettle();

    expect(controller.offset, controller.position.maxScrollExtent);
    expect(find.byKey(const Key('new-message-indicator')), findsNothing);
  });

  testWidgets('loading older history preserves the visible anchor', (
    tester,
  ) async {
    final (container, repository) = await _pumpConversation(tester);
    final controller = _messageScrollController(tester);
    controller.jumpTo(0);
    await tester.pumpAndSettle();

    expect(repository.olderPageRequests, 1);
    expect(
      container.read(chatMessagesProvider(_conversationId)).valueOrNull,
      hasLength(80),
    );
    expect(controller.offset, greaterThan(0));
  });
}
