import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/data/cached_result.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/services/chat_socket_service.dart';
import 'package:handygo_app/core/theme/app_semantic_colors.dart';
import 'package:handygo_app/core/widgets/navigation_count_badge.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';
import 'package:handygo_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/chat/domain/entities/chat_entities.dart';
import 'package:handygo_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:handygo_app/features/chat/presentation/pages/chat_detail_page.dart';
import 'package:handygo_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:handygo_app/features/client/presentation/widgets/client_bottom_nav_bar.dart';
import 'package:handygo_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:handygo_app/features/notifications/presentation/utils/notification_event_refresh.dart';
import 'package:handygo_app/features/worker/data/repositories/worker_repository_impl.dart';
import 'package:handygo_app/features/worker/domain/entities/new_job_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_profile_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_stats_entity.dart';
import 'package:handygo_app/features/worker/domain/repositories/worker_repository.dart';
import 'package:handygo_app/features/worker/presentation/pages/worker_home_page.dart';
import 'package:handygo_app/features/worker/presentation/pages/worker_new_jobs_page.dart';
import 'package:handygo_app/features/worker/presentation/providers/worker_job_providers.dart';
import 'package:handygo_app/features/worker/presentation/providers/worker_nav_indicator_providers.dart';
import 'package:handygo_app/features/worker/presentation/providers/worker_providers.dart';
import 'package:handygo_app/features/worker/presentation/widgets/worker_bottom_nav_bar.dart';
import 'package:handygo_app/l10n/app_localizations.dart';

import '../support/l10n_test_app.dart';

class _Socket implements ChatSocketService {
  final updates = StreamController<Map<String, dynamic>>.broadcast();
  final messages = StreamController<Map<String, dynamic>>.broadcast();
  final seen = StreamController<Map<String, dynamic>>.broadcast();
  final connected = StreamController<void>.broadcast();
  void Function(String, String)? saveSeen;

  @override
  Stream<Map<String, dynamic>> get onConversationUpdated => updates.stream;
  @override
  Stream<Map<String, dynamic>> get onNewMessage => messages.stream;
  @override
  Stream<Map<String, dynamic>> get onMessageSeen => seen.stream;
  @override
  Stream<void> get onConnected => connected.stream;
  @override
  Stream<Map<String, dynamic>> get onMessageEdited => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get onMessageDeleted => const Stream.empty();
  @override
  void joinConversation(String id) {}
  @override
  void leaveConversation(String id) {}
  @override
  void markSeen(String conversationId, String messageId) =>
      saveSeen?.call(conversationId, messageId);

  Future<void> close() async {
    await updates.close();
    await messages.close();
    await seen.close();
    await connected.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ConversationEntity _conversation(String id, int unread) => ConversationEntity(
  id: id,
  clientUserId: 'me',
  workerUserId: 'other',
  createdByUserId: 'me',
  createdAt: '2026-09-01T10:00:00Z',
  updatedAt: '2026-09-01T10:00:00Z',
  otherParticipant: ConversationParticipantEntity(
    userId: 'other',
    firstName: id,
    lastName: 'Khan',
  ),
  unreadCount: unread,
);

class _Chats implements ChatRepository {
  final counts = <String, int>{'Ali': 0};
  int fetches = 0;
  Completer<Either<Failure, CachedResult<List<ConversationEntity>>>>? pending;

  @override
  Future<Either<Failure, void>> ensureSupportConversation() async =>
      const Right(null);
  @override
  Future<Either<Failure, CachedResult<List<ConversationEntity>>>>
  getConversations() async {
    fetches++;
    final request = pending;
    pending = null;
    if (request != null) return request.future;
    return Right(
      CachedResult([
        for (final entry in counts.entries)
          _conversation(entry.key, entry.value),
      ]),
    );
  }

  @override
  Future<Either<Failure, CachedResult<List<MessageEntity>>>> getMessages(
    String conversationId, {
    int limit = 50,
    String? before,
  }) async => Right(
    CachedResult([
      for (var i = 0; i < (counts[conversationId] ?? 0); i++)
        MessageEntity(
          id: 'message-$conversationId-$i',
          conversationId: conversationId,
          senderUserId: 'other',
          senderRole: 'WORKER',
          type: ChatMessageType.text,
          text: 'Hello $i',
          createdAt: '2026-09-01T10:00:00Z',
          updatedAt: '2026-09-01T10:00:00Z',
        ),
    ]),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends AuthStateNotifier {
  _Auth(this.role);
  final String role;
  @override
  Future<UserEntity?> build() async => UserEntity(
    id: 'me',
    phone: '+923000000000',
    role: role,
    firstName: 'Test',
    lastName: 'User',
  );
}

WorkerProfileEntity _profile([DateTime? seenAt]) => WorkerProfileEntity(
  id: 'worker',
  userId: 'me',
  firstName: 'Test',
  lastName: 'User',
  status: 'ACTIVE',
  verificationStatus: 'APPROVED',
  availabilityStatus: AvailabilityStatus.online,
  rating: 4.5,
  totalRatings: 10,
  skills: const [],
  stats: const WorkerStatsEntity(completedJobs: 3, activeJobs: 0),
  onboardingStatus: 'APPROVED',
  newJobsSeenAt: seenAt,
);

NewJobEntity _job(String id, DateTime createdAt) => NewJobEntity(
  id: id,
  status: BookingStatus.pending,
  urgency: BookingUrgency.normal,
  city: 'Lahore',
  latitude: 31.5,
  longitude: 74.3,
  createdAt: createdAt,
  category: const NewJobCategoryEntity(id: 'category', name: 'Electrician'),
  client: const NewJobClientEntity(
    id: 'client',
    firstName: 'Ali',
    lastName: 'Khan',
  ),
  bidCount: 0,
);

class _Worker extends WorkerRepository {
  List<NewJobEntity> jobs = [];
  DateTime? seenAt;
  int reads = 0;
  int stamps = 0;
  Completer<Either<Failure, DateTime>>? pendingStamp;
  @override
  Future<Either<Failure, CachedResult<WorkerProfileEntity>>>
  getProfile() async => Right(CachedResult(_profile(seenAt)));
  @override
  Future<Either<Failure, CachedResult<List<NewJobEntity>>>> getNewJobs() async {
    reads++;
    return Right(CachedResult(jobs));
  }

  @override
  Future<Either<Failure, DateTime>> markNewJobsSeen() async {
    stamps++;
    if (pendingStamp != null) return pendingStamp!.future;
    seenAt = DateTime.now().toUtc();
    return Right(seenAt!);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<int> _badges(WidgetTester tester) => tester
    .widgetList<NavigationCountBadge>(find.byType(NavigationCountBadge))
    .map((badge) => badge.count)
    .toList();

void main() {
  for (final role in ['CLIENT', 'WORKER']) {
    testWidgets(
      '$role Home receives conversation updates and persisted reads immediately',
      (tester) async {
        final socket = _Socket();
        final chats = _Chats();
        final worker = _Worker();
        final container = ProviderContainer(
          overrides: [
            chatSocketServiceProvider.overrideWithValue(socket),
            chatRepositoryProvider.overrideWithValue(chats),
            workerRepositoryProvider.overrideWithValue(worker),
            authStateProvider.overrideWith(() => _Auth(role)),
            unreadNotificationCountProvider.overrideWith((ref) async => 0),
          ],
        );
        final router = GoRouter(
          initialLocation: '/home',
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => Scaffold(
                body: const Text('Home remains visible'),
                bottomNavigationBar: role == 'CLIENT'
                    ? const ClientBottomNavBar(currentIndex: 0)
                    : const WorkerBottomNavBar(currentIndex: 0),
              ),
            ),
            GoRoute(
              path: '/chat/:id',
              builder: (_, state) =>
                  ChatDetailPage(conversationId: state.pathParameters['id']!),
            ),
          ],
        );
        addTearDown(() async {
          router.dispose();
          container.dispose();
          await socket.close();
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: localizedRouterApp(router),
          ),
        );
        await tester.pumpAndSettle();
        expect(_badges(tester), isEmpty);

        Future<void> incoming(String id, int messages) async {
          chats.counts[id] = messages;
          // Exact personal-room payload: no unreadCount or sender field.
          socket.updates.add({
            'conversationId': id,
            'lastMessagePreview': 'Hello',
            'lastMessageAt': '2026-09-03T10:00:00Z',
          });
          await tester.pumpAndSettle();
          expect(find.text('Home remains visible'), findsOneWidget);
        }

        await incoming('Ali', 1);
        expect(_badges(tester), [1]);
        await incoming('Ali', 10);
        expect(_badges(tester), [1]);
        await incoming('Hamza', 2); // A previously unknown conversation.
        expect(_badges(tester), [2]);

        // A delayed old GET must not overwrite a newer socket-triggered result.
        final stale =
            Completer<
              Either<Failure, CachedResult<List<ConversationEntity>>>
            >();
        chats.pending = stale;
        socket.updates.add({'conversationId': 'Ali'});
        await tester.pumpAndSettle();
        expect(chats.pending, isNull);
        expect(_badges(tester), [2]);
        await incoming('Third', 1);
        expect(_badges(tester), [3]);
        stale.complete(Right(CachedResult([_conversation('Ali', 0)])));
        await tester.pumpAndSettle();
        expect(_badges(tester), [3]);

        final savedReceipts = <String>{};
        socket.saveSeen = (id, messageId) {
          if (!savedReceipts.add(messageId)) return;
          chats.counts[id] =
              0; // Server persists first, then emits the receipt.
          socket.seen.add({
            'messageId': messageId,
            'seenAt': '2026-09-03T10:01:00Z',
          });
        };
        // The full message stream and repeated delivery use the same counters.
        socket.messages.add({'conversationId': 'Third', 'id': 'incoming-3'});
        await tester.pumpAndSettle();
        expect(_badges(tester), [3]);
        router.push('/chat/Ali');
        await tester.pumpAndSettle();
        expect(container.read(unreadConversationCountProvider), 2);
        router.pop();
        await tester.pumpAndSettle();
        expect(_badges(tester), [2]);

        // Cross-connection recovery, including resume's same invalidation path.
        chats.counts.updateAll((_, _) => 0);
        socket.connected.add(null);
        await tester.pumpAndSettle();
        expect(_badges(tester), isEmpty);
        chats.counts['Ali'] = 1;
        container.invalidate(
          chatConversationsProvider,
        ); // app.dart resume path.
        await tester.pumpAndSettle();
        expect(_badges(tester), [1]);
        expect(find.text('Home remains visible'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'Naya Kaam opening clears nav and Home; later eligible events restore both',
    (tester) async {
      final socket = _Socket();
      final worker = _Worker();
      final now = DateTime.now().toUtc();
      worker.jobs = [
        _job('a', now.subtract(const Duration(minutes: 5))),
        _job('b', now.subtract(const Duration(hours: 2))),
        _job('expired', now.subtract(const Duration(hours: 25))),
      ];
      final container = ProviderContainer(
        overrides: [
          chatSocketServiceProvider.overrideWithValue(socket),
          chatRepositoryProvider.overrideWithValue(_Chats()),
          workerRepositoryProvider.overrideWithValue(worker),
        ],
      );
      final router = GoRouter(
        initialLocation: '/worker/home',
        routes: [
          GoRoute(
            path: '/worker/home',
            builder: (_, _) => Scaffold(
              body: WorkerQuickTiles(profile: _profile()),
              bottomNavigationBar: const WorkerBottomNavBar(currentIndex: 0),
            ),
          ),
          GoRoute(
            path: '/worker/new-jobs',
            builder: (_, _) => const WorkerNewJobsPage(),
          ),
        ],
      );
      addTearDown(() async {
        router.dispose();
        container.dispose();
        await socket.close();
      });
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedRouterApp(router),
        ),
      );
      await tester.pumpAndSettle();
      void expectHome(bool highlighted, int count) {
        final title = find.text(l10n.workerFindNewWork);
        expect(
          tester.widget<Text>(title).style!.color,
          highlighted
              ? AppSemanticColors.light.onPrimary
              : AppSemanticColors.light.primary,
        );
        final card = tester
            .widgetList<Container>(
              find.ancestor(of: title, matching: find.byType(Container)),
            )
            .firstWhere((c) => c.decoration is BoxDecoration);
        expect(
          (card.decoration as BoxDecoration).color,
          highlighted
              ? AppSemanticColors.light.primary
              : AppSemanticColors.light.surface,
        );
        expect(_badges(tester), count == 0 ? isEmpty : [count]);
      }

      expectHome(true, 2);
      worker.pendingStamp = Completer<Either<Failure, DateTime>>();
      await tester.tap(find.text(l10n.workerNewJobsTitle));
      await tester.pumpAndSettle();
      expect(worker.stamps, 1);
      expect(container.read(workerNewJobsUnreadCountProvider), 0);
      expect(_badges(tester), isEmpty); // No individual job was opened.
      worker.seenAt = DateTime.now().toUtc();
      worker.pendingStamp!.complete(Right(worker.seenAt!));
      await tester.pumpAndSettle();
      router.go('/worker/home');
      await tester.pumpAndSettle();
      expectHome(false, 0);

      // These are the existing socket/FCM event keys used by JobBroadcastService.
      for (final key in [
        'booking.standard.worker_listed',
        'booking.inspection.available',
        'booking.bidding.available',
        'booking.inspection.find_other_ustaad_available',
      ]) {
        worker.jobs = [
          ...worker.jobs,
          _job(key, worker.seenAt!.add(const Duration(milliseconds: 1))),
        ];
        final targets = notificationRefreshTargets(
          key,
          isWorker: true,
          hasBookingId: true,
        );
        expect(targets, {NotificationRefreshTarget.newJobs});
        for (final target in targets) {
          if (target == NotificationRefreshTarget.newJobs) {
            container.invalidate(newJobsProvider);
          }
        }
        await tester.pumpAndSettle();
        expectHome(true, worker.jobs.length - 3);
      }
      // Reconnect on Home catches feed changes without opening the jobs page.
      worker.jobs = [];
      socket.connected.add(null);
      await tester.pumpAndSettle();
      expectHome(false, 0);
      final reads = worker.reads;
      await tester.pump(const Duration(seconds: 31));
      expect(worker.reads, reads); // No recurring jobs poll.
    },
  );

  test(
    'failed seen write restores prior cutoff; stale profile cannot undo confirmed cutoff',
    () async {
      final worker = _Worker();
      final container = ProviderContainer(
        overrides: [workerRepositoryProvider.overrideWithValue(worker)],
      );
      addTearDown(container.dispose);
      worker.pendingStamp = Completer<Either<Failure, DateTime>>();
      final action = container.read(markNewJobsSeenProvider)();
      expect(container.read(newJobsSeenAtOverrideProvider), isNotNull);
      worker.pendingStamp!.complete(const Left(ServerFailure('failed')));
      await action;
      expect(container.read(newJobsSeenAtOverrideProvider), isNull);

      worker.pendingStamp = null;
      await container.read(markNewJobsSeenProvider)();
      final confirmed = container.read(newJobsSeenAtOverrideProvider);
      worker.seenAt = null; // Simulate an older profile response.
      await container.read(workerProfileProvider.future);
      expect(container.read(newJobsSeenAtOverrideProvider), confirmed);
    },
  );
}
