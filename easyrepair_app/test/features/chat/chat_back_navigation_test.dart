import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/l10n/l10n_config.dart';
import 'package:handygo_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:handygo_app/features/chat/domain/entities/chat_entities.dart';
import 'package:handygo_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:handygo_app/features/chat/presentation/pages/chat_detail_page.dart';
import 'package:handygo_app/features/chat/presentation/providers/chat_providers.dart';

/// A conversation is reachable from many screens. Android back must return to
/// whichever one opened it — not to the Chats tab, which is what a hard-coded
/// back route used to do from every entry point.
///
/// The routes below mirror the real ones in app_router.dart, including the
/// `fallbackRoute` wiring, so a regression there fails here.

class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository(this.conversations);

  final List<ConversationEntity> conversations;

  @override
  Future<Either<Failure, void>> ensureSupportConversation() async =>
      const Right(null);

  @override
  Future<Either<Failure, List<ConversationEntity>>> getConversations() async =>
      Right(conversations);

  @override
  Future<Either<Failure, List<MessageEntity>>> getMessages(
    String conversationId, {
    int limit = 30,
    String? before,
  }) async =>
      const Right(<MessageEntity>[]);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

final _conversation = ConversationEntity(
  id: 'conv-1',
  clientUserId: 'me',
  workerUserId: 'other',
  createdByUserId: 'me',
  createdAt: '2026-07-01T10:00:00.000Z',
  updatedAt: '2026-07-01T10:00:00.000Z',
  otherParticipant: const ConversationParticipantEntity(
    userId: 'other',
    firstName: 'Ali',
    lastName: 'Khan',
  ),
  isSupport: false,
);

/// A stand-in screen that can push the conversation the same way the real
/// callers do (`context.push`).
class _Origin extends StatelessWidget {
  const _Origin({required this.label, required this.chatRoute});

  final String label;
  final String chatRoute;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            ElevatedButton(
              onPressed: () => context.push(chatRoute),
              child: const Text('OPEN CHAT'),
            ),
            ElevatedButton(
              // Mirrors ChooseUstaadPage / WorkerDiscoveryMapPage, which are
              // pushed imperatively rather than as GoRoutes.
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _Origin(
                    label: 'WORKERS LIST',
                    chatRoute: chatRoute,
                  ),
                ),
              ),
              child: const Text('OPEN WORKERS LIST'),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _stub(String label) => Scaffold(body: Center(child: Text(label)));

GoRouter _buildRouter(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/client/chat',
        builder: (_, _) => _Origin(
          label: 'CLIENT CHAT LIST',
          chatRoute: '/client/chat/conv-1',
        ),
      ),
      GoRoute(
        path: '/client/chat/:id',
        builder: (_, state) => ChatDetailPage(
          conversationId: state.pathParameters['id']!,
          fallbackRoute: '/client/chat',
        ),
      ),
      GoRoute(
        path: '/client/booking/:id',
        builder: (_, _) => _Origin(
          label: 'BOOKING DETAIL',
          chatRoute: '/client/chat/conv-1',
        ),
      ),
      GoRoute(
        path: '/worker/chat',
        builder: (_, _) => _Origin(
          label: 'WORKER CHAT LIST',
          chatRoute: '/worker/chat/conv-1',
        ),
      ),
      GoRoute(
        path: '/worker/chat/:id',
        builder: (_, state) => ChatDetailPage(
          conversationId: state.pathParameters['id']!,
          fallbackRoute: '/worker/chat',
        ),
      ),
      GoRoute(
        path: '/worker/job/:id',
        builder: (_, _) => _Origin(
          label: 'JOB DETAIL',
          chatRoute: '/worker/chat/conv-1',
        ),
      ),
      GoRoute(path: '/deep-link-target', builder: (_, _) => _stub('UNUSED')),
    ],
  );
}

Future<GoRouter> _pump(WidgetTester tester, String initialLocation) async {
  final router = _buildRouter(initialLocation);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chatRepositoryProvider
            .overrideWithValue(_FakeChatRepository([_conversation])),
        authStateProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// Exactly what the Android system back button delivers — the `popRoute`
/// platform message — rather than tapping the in-app arrow.
Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

Future<void> _openChat(WidgetTester tester) async {
  await tester.tap(find.text('OPEN CHAT'));
  await tester.pumpAndSettle();
  expect(find.text('Ali Khan'), findsOneWidget, reason: 'chat did not open');
}

void main() {
  group('Android back returns to the screen that opened the conversation', () {
    for (final (role, origin, label) in [
      ('client', '/client/booking/b1', 'BOOKING DETAIL'),
      ('worker', '/worker/job/j1', 'JOB DETAIL'),
    ]) {
      testWidgets('$role: $label → conversation → back → $label', (
        tester,
      ) async {
        await _pump(tester, origin);
        expect(find.text(label), findsOneWidget);

        await _openChat(tester);
        await _systemBack(tester);

        expect(find.text(label), findsOneWidget);
        expect(find.text('CLIENT CHAT LIST'), findsNothing);
        expect(find.text('WORKER CHAT LIST'), findsNothing);
      });
    }

    testWidgets(
      'an imperatively pushed workers list is returned to as well',
      (tester) async {
        // ChooseUstaadPage and WorkerDiscoveryMapPage are pushed with
        // MaterialPageRoute, so they are invisible to GoRouter's own match
        // list. Back must still land on them.
        await _pump(tester, '/client/booking/b1');
        await tester.tap(find.text('OPEN WORKERS LIST'));
        await tester.pumpAndSettle();
        expect(find.text('WORKERS LIST'), findsOneWidget);

        await _openChat(tester);
        await _systemBack(tester);

        expect(find.text('WORKERS LIST'), findsOneWidget);
        expect(find.text('CLIENT CHAT LIST'), findsNothing);
      },
    );
  });

  group('the Chats tab is still where back leads when it is the origin', () {
    for (final (role, list) in [
      ('client', 'CLIENT CHAT LIST'),
      ('worker', 'WORKER CHAT LIST'),
    ]) {
      testWidgets('$role: chat list → conversation → back → chat list', (
        tester,
      ) async {
        await _pump(tester, role == 'client' ? '/client/chat' : '/worker/chat');

        await _openChat(tester);
        await _systemBack(tester);

        expect(find.text(list), findsOneWidget);
      });
    }
  });

  group('a conversation opened with no history falls back to the chat list', () {
    for (final (role, deepLink, list) in [
      ('client', '/client/chat/conv-1', 'CLIENT CHAT LIST'),
      ('worker', '/worker/chat/conv-1', 'WORKER CHAT LIST'),
    ]) {
      testWidgets('$role: notification cold start → back → $list', (
        tester,
      ) async {
        // A notification tap can start the app straight in a conversation.
        // There is nothing to pop, so back must not close the app.
        await _pump(tester, deepLink);
        expect(find.text('Ali Khan'), findsOneWidget);

        await _systemBack(tester);

        expect(find.text(list), findsOneWidget);
      });
    }
  });

  testWidgets('back is not intercepted when there is real history', (
    tester,
  ) async {
    // PopScope must let the framework do the popping, so the gesture, the
    // button and browser history all behave identically. If the page were
    // still blocking every pop, canPop would read false here.
    await _pump(tester, '/client/booking/b1');
    await _openChat(tester);

    final popScopes = tester
        .widgetList(find.byWidgetPredicate((w) => w is PopScope))
        .cast<PopScope>()
        .toList();

    expect(popScopes, isNotEmpty, reason: 'the page no longer uses PopScope');
    expect(
      popScopes.every((p) => p.canPop),
      isTrue,
      reason: 'back is being intercepted even though there is history to pop',
    );
  });
}
