import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/data/cached_result.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/domain/entities/nearby_worker_entity.dart';
import 'package:handygo_app/features/bookings/domain/entities/nearby_worker_profile_entity.dart';
import 'package:handygo_app/features/bookings/domain/repositories/booking_repository.dart';
import 'package:handygo_app/features/bookings/presentation/pages/choose_ustaad_page.dart';
import 'package:handygo_app/features/bookings/presentation/providers/booking_providers.dart';
import 'package:handygo_app/features/chat/domain/entities/chat_entities.dart';
import 'package:handygo_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:handygo_app/features/chat/presentation/providers/chat_providers.dart';

import '../../support/l10n_test_app.dart';

/// The STANDARD and INSPECTION Ustaad list, after the prototype redesign.
///
/// Both lanes render through the same [ChooseUstaadPage]; only the notifier
/// behind them and the money line differ, so every structural expectation
/// here is asserted against both. BIDDING is a different page
/// (WorkerDiscoveryMapPage) and is deliberately not touched by any of this.

// ── Fakes ────────────────────────────────────────────────────────────────────

class _FakeBookingRepository implements BookingRepository {
  _FakeBookingRepository(this.workers, {this.profile, this.profileFails = false});

  final List<NearbyWorkerEntity> workers;

  /// What the detail endpoint returns for any worker in this list.
  NearbyWorkerProfileEntity? profile;

  /// When true the detail endpoint fails, so the sheet must show retry.
  bool profileFails;

  /// Every (bookingId, workerProfileId) pair the profile sheet asked for.
  final List<(String, String)> profileCalls = [];

  /// Completes only when [releaseProfile] is called, so a test can assert on
  /// the sheet's loading state.
  Completer<void>? gate;

  void releaseProfile() => gate?.complete();

  /// Every (bookingId, workerProfileId) pair `Chunain` assigned.
  final List<(String, String)> assigned = [];

  @override
  Future<Either<Failure, NearbyWorkerProfileEntity>> getNearbyWorkerProfile(
    String bookingId,
    String workerProfileId,
  ) async {
    profileCalls.add((bookingId, workerProfileId));
    if (gate != null) await gate!.future;
    if (profileFails) {
      return const Left(
        ServerFailure('boom', code: FailureCode.unknown),
      );
    }
    return Right(profile ?? _profile());
  }

  @override
  Future<Either<Failure, NearbyWorkersResult>> getNearbyWorkers(
    String bookingId, {
    double? radiusKm,
  }) async => Right(
    NearbyWorkersResult(
      workers: workers,
      searchedRadiusKm: radiusKm ?? 5,
      totalFound: workers.length,
      searchCompleted: workers.isNotEmpty,
    ),
  );

  @override
  Future<Either<Failure, BookingEntity>> assignWorker(
    String bookingId,
    String workerProfileId,
  ) async {
    assigned.add((bookingId, workerProfileId));
    return Right(_booking(lane: BookingLane.standard));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

class _FakeChatRepository implements ChatRepository {
  /// Every (bookingId, workerProfileId) pair the Chat button asked for.
  final List<(String, String)> getOrCreateCalls = [];

  @override
  Future<Either<Failure, ConversationEntity>> getOrCreateConversation(
    String bookingId,
    String workerProfileId,
  ) async {
    getOrCreateCalls.add((bookingId, workerProfileId));
    return Right(_conversation);
  }

  @override
  Future<Either<Failure, CachedResult<List<ConversationEntity>>>>
  getConversations() async => const Right(CachedResult(<ConversationEntity>[]));

  @override
  Future<Either<Failure, void>> ensureSupportConversation() async =>
      const Right(null);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

// ── Fixtures ─────────────────────────────────────────────────────────────────

final _conversation = ConversationEntity(
  id: 'conv-1',
  clientUserId: 'client-1',
  workerUserId: 'worker-user-1',
  createdByUserId: 'client-1',
  createdAt: '2026-07-01T10:00:00.000Z',
  updatedAt: '2026-07-01T10:00:00.000Z',
  otherParticipant: const ConversationParticipantEntity(
    userId: 'worker-user-1',
    firstName: 'Rashid',
    lastName: 'Ali',
  ),
  isSupport: false,
);

NearbyWorkerEntity _worker({
  String id = 'worker-1',
  String firstName = 'Rashid',
  String lastName = 'Ali',
  double rating = 4.6,
  int completedJobs = 214,
  int reviewsCount = 12,
  double distanceKm = 0.6,
  List<String> skills = const ['AC Repair', 'Refrigeration'],
  bool cnicVerified = true,
  int? relevantExperienceYears = 8,
}) => NearbyWorkerEntity(
  id: id,
  firstName: firstName,
  lastName: lastName,
  rating: rating,
  completedJobs: completedJobs,
  reviewsCount: reviewsCount,
  cancellationRate: 3,
  distanceKm: distanceKm,
  skills: skills,
  cnicVerified: cnicVerified,
  relevantExperienceYears: relevantExperienceYears,
);

NearbyWorkerProfileEntity _profile({
  String firstName = 'Rashid',
  String lastName = 'Ali',
  String? phone = '+923001234567',
  double averageRating = 4.9,
  int totalReviews = 12,
  int completedJobs = 214,
  bool cnicVerified = true,
  int? relevantExperienceYears = 8,
  List<NearbyWorkerSkillEntity> skills = const [
    NearbyWorkerSkillEntity(name: 'AC Repair', yearsExperience: 8),
    NearbyWorkerSkillEntity(name: 'Refrigeration', yearsExperience: 3),
  ],
  int reviewCount = 5,
}) => NearbyWorkerProfileEntity(
  workerProfileId: 'worker-1',
  firstName: firstName,
  lastName: lastName,
  avatarUrl: null,
  phone: phone,
  averageRating: averageRating,
  totalReviews: totalReviews,
  completedJobs: completedJobs,
  cnicVerified: cnicVerified,
  relevantExperienceYears: relevantExperienceYears,
  skills: skills,
  reviews: List.generate(
    reviewCount,
    (i) => NearbyWorkerReviewEntity(
      id: 'review-$i',
      rating: 5,
      comment: 'Bohat acha kaam kiya number $i',
      reviewerName: 'Client $i',
      serviceCategory: 'AC Repair',
      createdAt: DateTime(2026, 8, i + 1),
    ),
  ),
);

BookingEntity _booking({required BookingLane lane}) => BookingEntity(
  id: 'booking-1',
  referenceId: '#ER-ABC123',
  serviceCategory: 'AC Repair',
  serviceEmoji: '❄️',
  status: BookingStatus.pending,
  urgency: BookingUrgency.normal,
  createdAt: DateTime(2026, 8, 20, 9),
  lane: lane,
  inspection: lane == BookingLane.inspection,
  inspectionFeeSnapshot: lane == BookingLane.inspection ? 700 : null,
  standardServiceItems: lane == BookingLane.standard
      ? const [
          BookingStandardServiceItemEntity(
            id: 'svc-1',
            nameSnapshot: 'AC General Service',
            priceSnapshot: 4200,
          ),
          BookingStandardServiceItemEntity(
            id: 'svc-2',
            nameSnapshot: 'Split AC Installation',
            priceSnapshot: 3500,
          ),
        ]
      : const [],
);

// ── Harness ──────────────────────────────────────────────────────────────────

/// Pumps the page inside a real GoRouter, so `context.push` to the chat detail
/// route behaves exactly as it does in the app (and Android back returns here).
Future<
  ({_FakeBookingRepository bookings, _FakeChatRepository chat})
>
_pumpPage(
  WidgetTester tester, {
  required BookingLane lane,
  List<NearbyWorkerEntity>? workers,
  NearbyWorkerProfileEntity? profile,
  bool profileFails = false,
  bool holdProfile = false,
  AppLocale locale = AppLocale.english,
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  tester.view.devicePixelRatio = tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);

  final bookingRepo = _FakeBookingRepository(
    workers ?? [_worker()],
    profile: profile,
    profileFails: profileFails,
  );
  if (holdProfile) bookingRepo.gate = Completer<void>();
  final chatRepo = _FakeChatRepository();
  final booking = _booking(lane: lane);

  final router = GoRouter(
    initialLocation: '/client/choose',
    routes: [
      GoRoute(
        path: '/client/choose',
        builder: (_, _) => ChooseUstaadPage(booking: booking),
      ),
      GoRoute(
        path: '/client/chat/:id',
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('CHAT DETAIL'))),
      ),
      GoRoute(
        path: '/client/booking/:id',
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('BOOKING DETAIL'))),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bookingRepositoryProvider.overrideWithValue(bookingRepo),
        chatRepositoryProvider.overrideWithValue(chatRepo),
      ],
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: localizedRouterApp(
          router,
          locale: locale,
          theme: AppTheme.lightTheme,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (bookings: bookingRepo, chat: chatRepo);
}

void main() {
  // ── The redesigned list, on both lanes ────────────────────────────────────

  for (final lane in [BookingLane.standard, BookingLane.inspection]) {
    final name = lane.name;

    testWidgets('$lane list renders the redesigned header and card', (
      tester,
    ) async {
      await _pumpPage(tester, lane: lane);

      // Header: title + the nearest-first / availability line.
      expect(find.text('Choose Ustaad'), findsOneWidget);
      expect(find.textContaining('Nearest first'), findsOneWidget);
      expect(find.textContaining('1 available'), findsOneWidget);

      // Card identity + the facts that come from the nearby-workers payload.
      expect(find.text('Rashid Ali'), findsOneWidget);
      expect(find.text('4.6'), findsOneWidget);
      expect(find.text('214 jobs'), findsOneWidget);
      expect(find.text('< 1 km away'), findsOneWidget);
      // Review TEXT and the phone number belong to the sheet, not the card.
      expect(find.text('+923001234567'), findsNothing);

      // Both actions, with Chunain as the primary CTA — the same product
      // word in English as in Roman Urdu.
      expect(find.text('Chunain'), findsOneWidget);

      // Card-level facts that came from the list payload.
      expect(find.text('CNIC verified'), findsOneWidget);
      expect(find.text('8 yrs experience'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);

      expect(tester.takeException(), isNull, reason: '$name lane');
    });

    testWidgets('$lane: no card carries a BoxShadow', (tester) async {
      await _pumpPage(tester, lane: lane);
      final shadowed = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => (c.decoration as BoxDecoration?)?.boxShadow != null);
      expect(shadowed, isEmpty);
    });
  }

  testWidgets('STANDARD summary shows the service total', (tester) async {
    await _pumpPage(tester, lane: BookingLane.standard);
    expect(find.text('Total'), findsOneWidget);
    expect(find.textContaining('7,700'), findsOneWidget);
    expect(find.textContaining('AC General Service'), findsOneWidget);
  });

  testWidgets('INSPECTION summary shows the inspection fee, not a total', (
    tester,
  ) async {
    await _pumpPage(tester, lane: BookingLane.inspection);
    expect(find.text('Inspection fee'), findsOneWidget);
    expect(find.textContaining('700'), findsWidgets);
    expect(find.text('Total'), findsNothing);
  });

  // ── Avatar → profile sheet, on the same page ─────────────────────────────

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byTooltip('View profile'));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping the avatar opens the sheet without leaving the list '
      'or selecting the worker', (tester) async {
    final fakes = await _pumpPage(tester, lane: BookingLane.standard);
    await openSheet(tester);

    // Still on the list — the sheet is layered over it.
    expect(find.text('Choose Ustaad'), findsOneWidget);
    // And nothing was hired by looking.
    expect(fakes.bookings.assigned, isEmpty);
    // The profile is fetched for exactly this (booking, worker).
    expect(fakes.bookings.profileCalls, [('booking-1', 'worker-1')]);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the sheet shows the identity immediately and a loading state '
      'while the profile is in flight', (tester) async {
    final fakes = await _pumpPage(
      tester,
      lane: BookingLane.standard,
      holdProfile: true,
    );
    await tester.tap(find.byTooltip('View profile'));
    await tester.pump(); // open the sheet, leave the request pending
    await tester.pump(const Duration(milliseconds: 300));

    // Identity is already on screen; the detail is not.
    expect(find.text('Rashid Ali'), findsNWidgets(2)); // card + sheet
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('+923001234567'), findsNothing);

    fakes.bookings.releaseProfile();
    await tester.pumpAndSettle();
    expect(find.text('+923001234567'), findsOneWidget);
  });

  testWidgets('the sheet renders every real profile field', (tester) async {
    await _pumpPage(tester, lane: BookingLane.standard);
    await openSheet(tester);

    // Name and average rating.
    expect(find.text('Rashid Ali'), findsNWidgets(2)); // card + sheet
    expect(find.text('4.9'), findsWidgets);
    // Verification badge — from the server-computed boolean only.
    expect(find.text('CNIC Verified Ustaad'), findsOneWidget);
    // Completed jobs and the booking-relevant experience.
    expect(find.text('Jobs Done'), findsOneWidget);
    expect(find.text('214'), findsOneWidget);
    expect(find.text('Experience in Years'), findsOneWidget);
    // Skills, each with its own years — never summed.
    expect(find.text('AC Repair · 8 yrs experience'), findsOneWidget);
    expect(find.text('Refrigeration · 3 yrs experience'), findsOneWidget);
    // Phone.
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('+923001234567'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the profile image is rendered in the sheet', (tester) async {
    await _pumpPage(tester, lane: BookingLane.standard);
    await openSheet(tester);
    // No avatarUrl on this fixture, so the initials stand in for the photo —
    // one in the card, one at 88px in the sheet.
    expect(find.text('RA'), findsNWidgets(2));
  });

  testWidgets('no verification badge when the server says unverified', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      lane: BookingLane.standard,
      workers: [_worker(cnicVerified: false)],
      profile: _profile(cnicVerified: false),
    );
    await openSheet(tester);
    expect(find.text('CNIC Verified Ustaad'), findsNothing);
    expect(find.text('CNIC verified'), findsNothing);
  });

  // ── Reviews: 5 / 4 / 3 / 2 / 1 / 0 ───────────────────────────────────────

  for (final count in [5, 4, 3, 2, 1]) {
    testWidgets('$count reviews → exactly $count review cards', (tester) async {
      await _pumpPage(
        tester,
        lane: BookingLane.standard,
        profile: _profile(reviewCount: count),
      );
      await openSheet(tester);

      for (var i = 0; i < count; i++) {
        expect(
          find.text('Bohat acha kaam kiya number $i'),
          findsOneWidget,
          reason: 'review $i of $count',
        );
      }
      expect(find.text('Bohat acha kaam kiya number $count'), findsNothing);
      expect(find.text('No reviews available'), findsNothing);
    });
  }

  testWidgets('0 reviews → the localized empty state, not a count', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      lane: BookingLane.standard,
      profile: _profile(reviewCount: 0),
    );
    await openSheet(tester);
    expect(find.text('No reviews available'), findsOneWidget);
  });

  testWidgets('a failed profile fetch retries inside the sheet, without '
      'closing the Ustaad list', (tester) async {
    final fakes = await _pumpPage(
      tester,
      lane: BookingLane.standard,
      profileFails: true,
    );
    await openSheet(tester);

    expect(find.textContaining('Could not load'), findsOneWidget);
    // The list is still there behind the sheet.
    expect(find.text('Choose Ustaad'), findsOneWidget);

    fakes.bookings.profileFails = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('+923001234567'), findsOneWidget);
    expect(fakes.bookings.profileCalls, hasLength(2));
  });

  testWidgets('the INSPECTION lane opens the same profile sheet', (
    tester,
  ) async {
    final fakes = await _pumpPage(tester, lane: BookingLane.inspection);
    await tester.tap(find.byTooltip('View profile'));
    await tester.pumpAndSettle();

    expect(fakes.bookings.profileCalls, [('booking-1', 'worker-1')]);
    expect(find.text('CNIC Verified Ustaad'), findsOneWidget);
    expect(find.text('+923001234567'), findsOneWidget);
  });

  // ── Chunain → the existing, lane-specific selection path ──────────────────

  for (final lane in [BookingLane.standard, BookingLane.inspection]) {
    testWidgets('$lane Chunain assigns through the existing hire flow', (
      tester,
    ) async {
      final fakes = await _pumpPage(tester, lane: lane);

      await tester.tap(find.text('Chunain'));
      await tester.pumpAndSettle();

      // Same confirmation gate as before the redesign.
      expect(find.textContaining('Rashid Ali'), findsWidgets);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Chunain').last);
      await tester.pumpAndSettle();

      expect(fakes.bookings.assigned, [('booking-1', 'worker-1')]);
    });
  }

  // ── Chat → the existing idempotent get-or-create ──────────────────────────

  testWidgets('Chat opens the existing conversation flow exactly once and '
      'back returns to the Ustaad list', (tester) async {
    final fakes = await _pumpPage(tester, lane: BookingLane.standard);

    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
    await tester.pumpAndSettle();

    // One get-or-create for this (booking, worker) — no duplicate thread.
    expect(fakes.chat.getOrCreateCalls, [('booking-1', 'worker-1')]);
    expect(find.text('CHAT DETAIL'), findsOneWidget);

    // Pushed, not replaced — back lands on the list it came from.
    final NavigatorState nav = tester.state(find.byType(Navigator).first);
    nav.pop();
    await tester.pumpAndSettle();
    expect(find.text('Choose Ustaad'), findsOneWidget);
    expect(find.text('Rashid Ali'), findsOneWidget);
  });

  // ── Responsiveness ───────────────────────────────────────────────────────

  final longNameWorkers = [
    _worker(
      id: 'w-long',
      firstName: 'Muhammad Abdul Rehman',
      lastName: 'Shaikh Qureshi',
      skills: const [
        'Air Conditioning Installation',
        'Refrigeration Repair',
        'Electrical Wiring',
        'Washing Machine Repair',
      ],
    ),
    _worker(id: 'w-2', firstName: 'Imran', lastName: 'Sadiq'),
  ];

  for (final width in <double>[320, 360, 390, 430]) {
    testWidgets('no overflow at ${width.toInt()}px', (tester) async {
      await _pumpPage(
        tester,
        lane: BookingLane.standard,
        workers: longNameWorkers,
        size: Size(width, 780),
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('View profile').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The loaded sheet, not just its identity strip.
      expect(find.text('+923001234567'), findsOneWidget);
    });
  }

  for (final locale in AppLocale.values) {
    testWidgets('no overflow at text scale 2.0 (${locale.name})', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        lane: BookingLane.standard,
        workers: longNameWorkers,
        locale: locale,
        size: const Size(320, 780),
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip(_viewProfileLabel[locale]!).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  // ── Localisation ─────────────────────────────────────────────────────────

  testWidgets('the CTA reads Chunain in Roman Urdu', (tester) async {
    await _pumpPage(
      tester,
      lane: BookingLane.standard,
      locale: AppLocale.romanUrdu,
    );
    expect(find.text('Chunain'), findsOneWidget);
    expect(find.textContaining('Qareeb wale pehle'), findsOneWidget);
  });

  testWidgets('the sheet is translated in Roman Urdu', (tester) async {
    await _pumpPage(
      tester,
      lane: BookingLane.standard,
      locale: AppLocale.romanUrdu,
      profile: _profile(reviewCount: 0),
    );
    await tester.tap(find.byTooltip('Profile dekhein'));
    await tester.pumpAndSettle();
    expect(find.text('Koi review mojood nahi'), findsOneWidget);
    expect(find.text('CNIC Verified Ustaad'), findsOneWidget);
  });

  testWidgets('the sheet is translated in Urdu', (tester) async {
    await _pumpPage(
      tester,
      lane: BookingLane.standard,
      locale: AppLocale.urdu,
      profile: _profile(reviewCount: 0),
    );
    await tester.tap(find.byTooltip('پروفائل دیکھیں'));
    await tester.pumpAndSettle();
    expect(find.text('کوئی ریویو دستیاب نہیں'), findsOneWidget);
    expect(find.text('شناختی کارڈ تصدیق شدہ استاد'), findsOneWidget);
  });

  testWidgets('the CTA and header are translated in Urdu', (tester) async {
    await _pumpPage(
      tester,
      lane: BookingLane.standard,
      locale: AppLocale.urdu,
    );
    // The CTA is the brand word in every locale except Urdu script, which
    // has its own established wording.
    expect(find.text('منتخب کریں'), findsOneWidget);
    expect(find.textContaining('قریب والے پہلے'), findsOneWidget);
  });
}

const _viewProfileLabel = {
  AppLocale.english: 'View profile',
  AppLocale.romanUrdu: 'Profile dekhein',
  AppLocale.urdu: 'پروفائل دیکھیں',
};
