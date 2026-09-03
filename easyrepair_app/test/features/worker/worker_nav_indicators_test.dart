import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/theme/app_semantic_colors.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/chat/domain/entities/chat_entities.dart';
import 'package:handygo_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:handygo_app/features/worker/domain/entities/new_job_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/ongoing_job_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_profile_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_stats_entity.dart';
import 'package:handygo_app/features/worker/presentation/pages/worker_home_page.dart';
import 'package:handygo_app/features/worker/presentation/providers/worker_job_providers.dart';
import 'package:handygo_app/features/worker/presentation/providers/worker_providers.dart';
import 'package:handygo_app/features/worker/presentation/widgets/worker_bottom_nav_bar.dart';
import 'package:handygo_app/l10n/app_localizations.dart';

import '../../support/l10n_test_app.dart';

/// The Ustaad bottom-bar indicators and the Home "Nayi Shikayat" tile.
///
/// Every test here drives the REAL source providers — the conversations feed,
/// the new-jobs feed, the worker profile — and never the derived counts. That
/// is the point: the counts are supposed to fall out of state the app already
/// holds, so a test that stubbed the count would prove nothing about where the
/// number came from.

// ── Palette under test ───────────────────────────────────────────────────────
//
// The widgets ask `context.semanticColors`; these tests pump the light theme
// and assert against the same palette, so a token that moves moves in both
// places at once and nothing here has to be re-typed.
const _c = AppSemanticColors.light;

// ── Fakes ────────────────────────────────────────────────────────────────────
//
// Each overrides only `build()`, which drops the real notifier's socket
// subscriptions and 30 s timers — a widget test must not open either.

class _FakeConversations extends ChatConversationsNotifier {
  _FakeConversations(this.items);
  final List<ConversationEntity> items;

  @override
  Future<List<ConversationEntity>> build() async => items;
}

class _FakeNewJobs extends NewJobsNotifier {
  _FakeNewJobs(this.items);
  final List<NewJobEntity> items;

  @override
  Future<List<NewJobEntity>> build() async {
    // The suspension matters. The real notifier publishes this only after
    // awaiting the repository, and Riverpod forbids a provider writing to
    // another one during its own synchronous build. A fake that wrote
    // straight away would be exercising a code path the app never takes.
    await Future<void>.delayed(Duration.zero);
    // Publishes the unfiltered list exactly as the real notifier does — that
    // side channel is what the badge counts, so a fake that skipped it would
    // be testing a different thing entirely.
    ref.read(newJobsUnfilteredProvider.notifier).state = items;
    return items;
  }
}

class _FakeProfile extends WorkerProfileNotifier {
  _FakeProfile(this.profile);
  final WorkerProfileEntity profile;

  @override
  Future<WorkerProfileEntity> build() async => profile;
}

// ── Fixtures ─────────────────────────────────────────────────────────────────

ConversationEntity _conversation(String id, {required int unread}) =>
    ConversationEntity(
      id: id,
      clientUserId: 'client-$id',
      workerUserId: 'worker-1',
      createdByUserId: 'client-$id',
      createdAt: '2026-09-01T10:00:00.000Z',
      updatedAt: '2026-09-01T10:00:00.000Z',
      otherParticipant: ConversationParticipantEntity(
        userId: 'client-$id',
        firstName: id,
        lastName: 'Khan',
      ),
      unreadCount: unread,
    );

NewJobEntity _newJob(String id, {required DateTime createdAt}) => NewJobEntity(
      id: id,
      status: BookingStatus.pending,
      urgency: BookingUrgency.normal,
      city: 'Lahore',
      latitude: 31.5,
      longitude: 74.3,
      createdAt: createdAt,
      category: const NewJobCategoryEntity(id: 'cat-1', name: 'Electrician'),
      client: const NewJobClientEntity(
        id: 'client-1',
        firstName: 'Ali',
        lastName: 'Raza',
      ),
      bidCount: 0,
    );

WorkerProfileEntity _profile({
  DateTime? newJobsSeenAt,
  OngoingJobEntity? ongoingJob,
}) =>
    WorkerProfileEntity(
      id: 'w1',
      userId: 'u1',
      firstName: 'Kamran',
      lastName: 'Sheikh',
      status: 'ACTIVE',
      verificationStatus: 'APPROVED',
      availabilityStatus: AvailabilityStatus.online,
      rating: 4.5,
      totalRatings: 10,
      skills: const [],
      stats: const WorkerStatsEntity(completedJobs: 3, activeJobs: 1),
      onboardingStatus: 'APPROVED',
      ongoingJob: ongoingJob,
      newJobsSeenAt: newJobsSeenAt,
    );

const _ongoingJob = OngoingJobEntity(
  id: 'job-1',
  categoryName: 'Electrician',
  clientArea: 'Johar Town',
  addressLine: 'House 12',
  status: 'IN_PROGRESS',
);

// ── Harness ──────────────────────────────────────────────────────────────────

List<Override> _overrides({
  List<ConversationEntity> conversations = const [],
  List<NewJobEntity> newJobs = const [],
  DateTime? newJobsSeenAt,
  OngoingJobEntity? ongoingJob,
}) =>
    [
      chatConversationsProvider
          .overrideWith(() => _FakeConversations(conversations)),
      newJobsProvider.overrideWith(() => _FakeNewJobs(newJobs)),
      workerProfileProvider.overrideWith(
        () => _FakeProfile(
          _profile(newJobsSeenAt: newJobsSeenAt, ongoingJob: ongoingJob),
        ),
      ),
    ];

/// Pumps the bottom bar and the Home tile row inside ONE ProviderScope.
///
/// One container is the whole point of the Naye Kaam assertions: both
/// surfaces read the same container, so if they ever disagreed it could only
/// be because one of them counted for itself.
Future<void> _pump(WidgetTester tester, List<Override> overrides) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: localizedApp(
        Scaffold(
          body: WorkerQuickTiles(profile: _profile()),
          bottomNavigationBar: const WorkerBottomNavBar(currentIndex: 0),
        ),
        theme: AppTheme.lightTheme,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// True when some box on screen is painted in [color]. Both indicators are a
/// single decorated box, so this is how "the badge is there" is asked without
/// reaching into private widget types.
bool _hasBoxPainted(WidgetTester tester, Color color) => tester
    .widgetList<Container>(find.byType(Container))
    .any((box) => (box.decoration as BoxDecoration?)?.color == color);

/// The style the given text is actually rendered in.
TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  // ── Chat ───────────────────────────────────────────────────────────────────

  group('the Chat badge counts conversations, not messages', () {
    testWidgets('two people waiting reads 2', (tester) async {
      await _pump(
        tester,
        _overrides(
          conversations: [
            _conversation('Ali', unread: 3),
            _conversation('Hamza', unread: 1),
          ],
        ),
      );

      expect(find.text('2'), findsOneWidget);
      expect(_hasBoxPainted(tester, _c.urgent), isTrue);
    });

    testWidgets('ten messages from one person still reads 1', (tester) async {
      await _pump(
        tester,
        _overrides(conversations: [_conversation('Ali', unread: 10)]),
      );

      // The badge must never show 10: an Ustaad reads it as "how many people
      // am I keeping waiting", and Ali is one person however much he types.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('10'), findsNothing);
    });

    testWidgets('nothing unread shows no badge at all', (tester) async {
      await _pump(
        tester,
        _overrides(
          conversations: [
            _conversation('Ali', unread: 0),
            _conversation('Hamza', unread: 0),
          ],
        ),
      );

      expect(_hasBoxPainted(tester, _c.urgent), isFalse);
      expect(find.text('0'), findsNothing);
    });
  });

  // ── Naye Kaam ──────────────────────────────────────────────────────────────

  group('the Naye Kaam count has exactly one source', () {
    testWidgets('the tab badge and the Home tile show the same number',
        (tester) async {
      final now = DateTime.now().toUtc();
      await _pump(
        tester,
        _overrides(
          newJobs: [
            _newJob('a', createdAt: now.subtract(const Duration(minutes: 5))),
            _newJob('b', createdAt: now.subtract(const Duration(hours: 2))),
            _newJob('c', createdAt: now.subtract(const Duration(hours: 6))),
            // Older than the 24h window — never "new", however long ago the
            // Ustaad last looked.
            _newJob('d', createdAt: now.subtract(const Duration(hours: 30))),
          ],
          newJobsSeenAt: now.subtract(const Duration(hours: 8)),
        ),
      );

      // The bar renders the bare number; the tile renders it through the
      // plural message. Both come from workerNewJobsUnreadCountProvider.
      expect(find.text('3'), findsOneWidget);
      expect(find.text(l10n.workerNewComplaintsCount(3)), findsOneWidget);
    });

    testWidgets('jobs older than the seen marker are not new', (tester) async {
      final now = DateTime.now().toUtc();
      await _pump(
        tester,
        _overrides(
          newJobs: [
            _newJob('old', createdAt: now.subtract(const Duration(hours: 3))),
            _newJob('new', createdAt: now.subtract(const Duration(minutes: 1))),
          ],
          newJobsSeenAt: now.subtract(const Duration(hours: 2)),
        ),
      );

      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('never having opened the screen leaves the window in charge',
        (tester) async {
      final now = DateTime.now().toUtc();
      await _pump(
        tester,
        _overrides(
          newJobs: [
            _newJob('a', createdAt: now.subtract(const Duration(hours: 3))),
            _newJob('b', createdAt: now.subtract(const Duration(hours: 20))),
            _newJob('c', createdAt: now.subtract(const Duration(hours: 25))),
          ],
          // Null: the Ustaad has never opened Naye Kaam. Everything inside
          // the 24h window is unread, which is the truthful answer rather
          // than a migration artefact.
        ),
      );

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('no new jobs hides the badge and leaves the tile inviting',
        (tester) async {
      await _pump(tester, _overrides());

      expect(_hasBoxPainted(tester, _c.urgent), isFalse);
      // At zero the tile says "Dekhein" again rather than announcing "0 new".
      expect(find.text(l10n.workerViewNewJobs), findsOneWidget);
    });
  });

  // ── Mere Kaam ──────────────────────────────────────────────────────────────

  group('the Mere Kaam dot follows the ongoing job', () {
    testWidgets('a job in hand lights the dot', (tester) async {
      await _pump(tester, _overrides(ongoingJob: _ongoingJob));

      // `success`, not `urgent` — having work is a good state.
      expect(_hasBoxPainted(tester, _c.success), isTrue);
    });

    testWidgets('no job in hand shows nothing', (tester) async {
      await _pump(tester, _overrides());

      expect(_hasBoxPainted(tester, _c.success), isFalse);
    });
  });

  // ── The tile itself ────────────────────────────────────────────────────────

  group('the Nayi Shikayat tile is painted from the palette', () {
    testWidgets('the whole card is primary with onPrimary marks on it',
        (tester) async {
      await _pump(tester, _overrides(newJobs: [
        _newJob('fresh', createdAt: DateTime.now().toUtc()),
      ]));

      expect(_hasBoxPainted(tester, _c.primary), isTrue);
      expect(_styleOf(tester, l10n.workerFindNewWork).color, _c.onPrimary);
      expect(_styleOf(tester, l10n.workerNewComplaintsCount(1)).color, _c.onPrimaryMuted);
    });

    testWidgets('the tile beside it is untouched', (tester) async {
      await _pump(tester, _overrides());

      // Only one tile in the row may claim the fill — two teal blocks side by
      // side single out neither.
      expect(_styleOf(tester, l10n.workerTodaysEarnings).color, _c.textPrimary);
    });
  });
}
