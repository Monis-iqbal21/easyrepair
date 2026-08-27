import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/l10n_test_app.dart';
import 'package:fpdart/fpdart.dart';
import 'package:handygo_app/core/data/cached_result.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/theme/app_semantic_colors.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/chat/domain/entities/chat_entities.dart';
import 'package:handygo_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:handygo_app/features/chat/presentation/pages/chat_list_page.dart';
import 'package:handygo_app/features/chat/presentation/providers/chat_providers.dart';

const supportUserId = 'support-user-id';

/// Only the two methods the conversations list touches are implemented; the
/// rest are forwarded to [noSuchMethod] and would throw if ever called.
class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository(this.conversations, {this.ensureFails = false});

  final List<ConversationEntity> conversations;
  final bool ensureFails;
  int ensureCalls = 0;

  @override
  Future<Either<Failure, void>> ensureSupportConversation() async {
    ensureCalls++;
    if (ensureFails) return Left(ServerFailure('support unavailable'));
    return const Right(null);
  }

  @override
  Future<Either<Failure, CachedResult<List<ConversationEntity>>>>
  getConversations() async {
    return Right(CachedResult(conversations));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

ConversationEntity _conversation({
  required String id,
  required String name,
  bool isSupport = false,
  String? lastMessageAt,
  String? lastMessagePreview,
  int unreadCount = 0,
  String userSlot = 'client',
}) {
  return ConversationEntity(
    id: id,
    // For a CLIENT the user sits in clientUserId; for a WORKER in workerUserId.
    clientUserId: userSlot == 'client' ? 'me' : supportUserId,
    workerUserId: userSlot == 'client' ? supportUserId : 'me',
    createdByUserId: 'me',
    lastMessageAt: lastMessageAt,
    lastMessagePreview: lastMessagePreview,
    createdAt: '2026-07-01T10:00:00.000Z',
    updatedAt: '2026-07-01T10:00:00.000Z',
    otherParticipant: ConversationParticipantEntity(
      userId: isSupport ? supportUserId : '$id-other',
      firstName: name,
      lastName: isSupport ? '' : 'Khan',
    ),
    isSupport: isSupport,
    unreadCount: unreadCount,
  );
}

Future<_FakeChatRepository> _pumpList(
  WidgetTester tester,
  List<ConversationEntity> conversations, {
  bool ensureFails = false,
  ThemeData? theme,
}) async {
  final repository = _FakeChatRepository(
    conversations,
    ensureFails: ensureFails,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [chatRepositoryProvider.overrideWithValue(repository)],
      child: localizedApp(
        Theme(
          data: theme ?? AppTheme.lightTheme,
          child: const ChatListPage(
            detailRoutePrefix: '/client/chat',
            bottomNavigationBar: SizedBox.shrink(),
            homeRoute: '/client/home',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

/// Names in the order they are rendered.
List<String> _renderedNames(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where((s) => s == 'HandyGo Support' || s.endsWith('Khan'))
      .toList();
}

void main() {
  test('canonical order deduplicates ids and Support rows while preserving '
      'ordinary conversation order', () {
    final result = normalizeChatConversations([
      _conversation(id: 'normal-1', name: 'Ali'),
      _conversation(id: 'support-1', name: 'HandyGo Support', isSupport: true),
      _conversation(id: 'normal-1', name: 'Ali duplicate'),
      _conversation(id: 'support-2', name: 'HandyGo Support', isSupport: true),
      _conversation(id: 'normal-2', name: 'Bilal'),
    ]);

    expect(result.map((conversation) => conversation.id), [
      'support-1',
      'normal-1',
      'normal-2',
    ]);
    expect(
      result.where((conversation) => conversation.isSupport),
      hasLength(1),
    );
  });

  testWidgets('HandyGo Support is pinned first for a CLIENT, even when it is '
      'the least recently active conversation', (tester) async {
    await _pumpList(tester, [
      _conversation(
        id: 'c1',
        name: 'Ali',
        lastMessageAt: '2026-07-30T10:00:00.000Z',
      ),
      _conversation(
        id: 'c2',
        name: 'Bilal',
        lastMessageAt: '2026-07-29T10:00:00.000Z',
      ),
      // Never used → would sort last by activity.
      _conversation(id: 'support', name: 'HandyGo Support', isSupport: true),
    ]);

    expect(_renderedNames(tester).first, 'HandyGo Support');
  });

  testWidgets('HandyGo Support is pinned first for a WORKER too', (
    tester,
  ) async {
    await _pumpList(tester, [
      _conversation(
        id: 'c1',
        name: 'Sara',
        lastMessageAt: '2026-07-30T10:00:00.000Z',
        userSlot: 'worker',
      ),
      _conversation(
        id: 'support',
        name: 'HandyGo Support',
        isSupport: true,
        userSlot: 'worker',
      ),
    ]);

    expect(_renderedNames(tester).first, 'HandyGo Support');
  });

  testWidgets('stays pinned after a socket update pushes another conversation '
      'to the top of the notifier list', (tester) async {
    await _pumpList(tester, [
      _conversation(id: 'support', name: 'HandyGo Support', isSupport: true),
      _conversation(id: 'c1', name: 'Ali'),
    ]);
    expect(_renderedNames(tester).first, 'HandyGo Support');

    // upsertConversation inserts at index 0 — exactly what a
    // `conversation_updated` socket event does.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChatListPage)),
    );
    container
        .read(chatConversationsProvider.notifier)
        .upsertConversation(
          _conversation(
            id: 'c1',
            name: 'Ali',
            lastMessageAt: '2026-07-31T09:00:00.000Z',
          ),
        );
    await tester.pumpAndSettle();

    expect(_renderedNames(tester).first, 'HandyGo Support');
  });

  testWidgets('unread activity and a newly-created ordinary conversation '
      'cannot displace Support in provider state or rendered order', (
    tester,
  ) async {
    await _pumpList(tester, [
      _conversation(id: 'support', name: 'HandyGo Support', isSupport: true),
      _conversation(id: 'c1', name: 'Ali'),
    ]);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChatListPage)),
    );
    container
        .read(chatConversationsProvider.notifier)
        .upsertConversation(
          _conversation(
            id: 'brand-new',
            name: 'Sara',
            unreadCount: 8,
            lastMessageAt: '2026-08-26T22:00:00.000Z',
          ),
        );
    await tester.pumpAndSettle();

    final state = container.read(chatConversationsProvider).requireValue;
    expect(state.first.isSupport, isTrue);
    expect(state.where((conversation) => conversation.isSupport), hasLength(1));
    expect(_renderedNames(tester).first, 'HandyGo Support');
  });

  testWidgets('renders exactly one Support row even if the list carries a '
      'duplicate', (tester) async {
    await _pumpList(tester, [
      _conversation(id: 'support', name: 'HandyGo Support', isSupport: true),
      _conversation(
        id: 'support-dupe',
        name: 'HandyGo Support',
        isSupport: true,
      ),
      _conversation(id: 'c1', name: 'Ali'),
    ]);

    expect(find.text('HandyGo Support'), findsOneWidget);
  });

  testWidgets('the ensure endpoint is called once when the tab loads', (
    tester,
  ) async {
    final repository = await _pumpList(tester, [
      _conversation(id: 'support', name: 'HandyGo Support', isSupport: true),
    ]);

    expect(repository.ensureCalls, 1);
  });

  testWidgets('a failing ensure still renders the conversation list', (
    tester,
  ) async {
    await _pumpList(tester, [
      _conversation(id: 'c1', name: 'Ali'),
    ], ensureFails: true);

    // Degrades to "no support row this refresh", never to a broken Chat tab.
    expect(find.text('Ali Khan'), findsOneWidget);
    expect(find.textContaining('support unavailable'), findsNothing);
  });

  group('search', () {
    Future<void> search(WidgetTester tester, String query) async {
      await tester.enterText(find.byType(TextField), query);
      await tester.pumpAndSettle();
    }

    testWidgets('a support typo surfaces Support and hides unrelated chats', (
      tester,
    ) async {
      await _pumpList(tester, [
        _conversation(id: 'support', name: 'HandyGo Support', isSupport: true),
        _conversation(id: 'c1', name: 'Ali'),
      ]);

      await search(tester, 'suport');

      expect(find.text('HandyGo Support'), findsOneWidget);
      expect(find.text('Ali Khan'), findsNothing);
    });

    testWidgets('an unrelated query does NOT surface Support', (tester) async {
      await _pumpList(tester, [
        _conversation(id: 'support', name: 'HandyGo Support', isSupport: true),
        _conversation(id: 'c1', name: 'Ali'),
      ]);

      await search(tester, 'ali');

      expect(find.text('Ali Khan'), findsOneWidget);
      expect(find.text('HandyGo Support'), findsNothing);
    });

    testWidgets('clearing the box pins Support again', (tester) async {
      await _pumpList(tester, [
        _conversation(id: 'support', name: 'HandyGo Support', isSupport: true),
        _conversation(id: 'c1', name: 'Ali'),
      ]);

      await search(tester, 'ali');
      expect(find.text('HandyGo Support'), findsNothing);

      await search(tester, '');
      expect(_renderedNames(tester).first, 'HandyGo Support');
    });

    testWidgets('a query matching nothing shows the no-results view', (
      tester,
    ) async {
      await _pumpList(tester, [_conversation(id: 'c1', name: 'Ali')]);

      await search(tester, 'zzzz');

      expect(find.text('No chats found'), findsOneWidget);
    });
  });

  testWidgets('the shared inbox has no overflow at every supported width', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in <double>[320, 360, 390, 430, 600]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await _pumpList(tester, [
        _conversation(
          id: 'support',
          name: 'HandyGo Support',
          isSupport: true,
          unreadCount: 125,
          lastMessageAt: '2026-08-26T22:00:00.000Z',
          lastMessagePreview:
              'A deliberately long support preview that must stay on one line',
        ),
        _conversation(
          id: 'normal',
          name: 'A very long Ustaad participant name',
          unreadCount: 7,
          lastMessageAt: '2026-08-26T21:00:00.000Z',
          lastMessagePreview:
              'A deliberately long normal preview that must ellipsize cleanly',
        ),
      ]);

      expect(tester.takeException(), isNull, reason: 'overflow at $width px');
      expect(_renderedNames(tester).first, 'HandyGo Support');
    }
  });

  testWidgets('the shared inbox reads the dark semantic palette', (
    tester,
  ) async {
    await _pumpList(tester, [
      _conversation(id: 'support', name: 'HandyGo Support', isSupport: true),
    ], theme: AppTheme.darkTheme);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppSemanticColors.dark.background);
    expect(_renderedNames(tester).first, 'HandyGo Support');
    expect(tester.takeException(), isNull);
  });
}
