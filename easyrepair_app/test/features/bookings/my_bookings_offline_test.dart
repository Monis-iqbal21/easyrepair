import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:handygo_app/core/data/cached_result.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/network/connectivity_service.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/domain/entities/create_booking_request.dart';
import 'package:handygo_app/features/bookings/domain/repositories/booking_repository.dart';
import 'package:handygo_app/features/bookings/presentation/providers/booking_providers.dart';

/// CLIENT offline behaviour, driven through the real providers.
///
/// The repository is faked at its boundary (it is what owns cache fallback),
/// so what these tests exercise is the wiring the user actually experiences:
/// does the cached list reach the screen, does the stale flag light the
/// banner, do filters still work on cached rows, and — critically — are
/// server-changing actions still refused while offline instead of being
/// optimistically applied.
class _FakeBookingRepository implements BookingRepository {
  _FakeBookingRepository();

  /// Queued list results, consumed one per fetch, so a test can model
  /// "offline first, then reconnect returns fresh data".
  final List<Either<Failure, CachedResult<List<BookingEntity>>>> listResults =
      [];
  final List<Either<Failure, CachedResult<BookingEntity>>> detailResults = [];
  int cancelCalls = 0;

  @override
  Future<Either<Failure, CachedResult<List<BookingEntity>>>>
      getClientBookings() async {
    if (listResults.isEmpty) return Right(CachedResult(const []));
    return listResults.length == 1
        ? listResults.first
        : listResults.removeAt(0);
  }

  @override
  Future<Either<Failure, CachedResult<BookingEntity>>> getBookingById(
    String bookingId,
  ) async {
    if (detailResults.isEmpty) {
      return Left(NetworkFailure('', code: FailureCode.noInternet));
    }
    return detailResults.length == 1
        ? detailResults.first
        : detailResults.removeAt(0);
  }

  @override
  Future<Either<Failure, BookingEntity>> cancelBooking(
    String bookingId,
    String reason,
  ) async {
    cancelCalls++;
    return Right(_booking(bookingId, status: BookingStatus.cancelled));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

BookingEntity _booking(
  String id, {
  BookingStatus status = BookingStatus.pending,
  String category = 'Plumbing',
  DateTime? createdAt,
}) {
  return BookingEntity(
    id: id,
    referenceId: '#ER-$id',
    serviceCategory: category,
    serviceEmoji: '🔧',
    status: status,
    urgency: BookingUrgency.normal,
    createdAt: createdAt ?? DateTime(2026, 8, 1),
  );
}

ProviderContainer _container(_FakeBookingRepository repo) {
  final container = ProviderContainer(
    overrides: [bookingRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() => ConnectivityService.instance.debugIsOnline = true);
  tearDown(() => ConnectivityService.instance.debugIsOnline = true);

  group('My Bookings offline', () {
    test('renders the last cached list when the server is unreachable',
        () async {
      final repo = _FakeBookingRepository()
        ..listResults.add(Right(CachedResult(
          [_booking('b1'), _booking('b2')],
          isStale: true,
        )));
      final container = _container(repo);

      final bookings =
          await container.read(bookingsNotifierProvider.future);

      expect(bookings.map((b) => b.id), ['b1', 'b2']);
    });

    test('flags the stale state so the offline banner shows', () async {
      final repo = _FakeBookingRepository()
        ..listResults.add(Right(CachedResult([_booking('b1')], isStale: true)));
      final container = _container(repo);

      await container.read(bookingsNotifierProvider.future);

      expect(container.read(bookingsIsOfflineProvider), isTrue);
    });

    test('a live fetch clears the stale flag — server data always wins',
        () async {
      final repo = _FakeBookingRepository()
        ..listResults.add(Right(CachedResult([_booking('b1')])));
      final container = _container(repo);

      await container.read(bookingsNotifierProvider.future);

      expect(container.read(bookingsIsOfflineProvider), isFalse);
    });

    test('offline with NOTHING cached surfaces the failure — a clean empty '
        'state, never an endless spinner', () async {
      final repo = _FakeBookingRepository()
        ..listResults.add(Left(NetworkFailure('', code: FailureCode.noInternet)));
      final container = _container(repo);

      await expectLater(
        container.read(bookingsNotifierProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
      expect(container.read(bookingsNotifierProvider).hasError, isTrue);
    });

    test('a 403 is surfaced as a restriction, not silently replaced by a '
        'cached list', () async {
      final repo = _FakeBookingRepository()
        ..listResults.add(Left(ForbiddenFailure('Account suspended')));
      final container = _container(repo);

      await expectLater(
        container.read(bookingsNotifierProvider.future),
        throwsA(isA<ForbiddenFailure>()),
      );
      expect(container.read(bookingsIsOfflineProvider), isFalse,
          reason: 'a suspension is not an offline condition');
    });
  });

  group('filters keep working on cached rows', () {
    test('the tab filter narrows a cached list without another fetch',
        () async {
      final repo = _FakeBookingRepository()
        ..listResults.add(Right(CachedResult(
          [
            _booking('live-1'),
            _booking('done-1', status: BookingStatus.completed),
            _booking('done-2', status: BookingStatus.completed),
          ],
          isStale: true,
        )));
      final container = _container(repo);
      await container.read(bookingsNotifierProvider.future);

      container
          .read(bookingFilterProvider.notifier)
          .setTab(BookingTab.completed);

      final visible = container.read(filteredBookingsProvider);
      expect(visible.map((b) => b.id), ['done-1', 'done-2']);
    });

    test('search works against cached rows too', () async {
      final repo = _FakeBookingRepository()
        ..listResults.add(Right(CachedResult(
          [
            _booking('b1', category: 'Plumbing'),
            _booking('b2', category: 'Electrical'),
          ],
          isStale: true,
        )));
      final container = _container(repo);
      await container.read(bookingsNotifierProvider.future);

      container.read(bookingFilterProvider.notifier).setSearchQuery('electr');

      expect(container.read(filteredBookingsProvider).map((b) => b.id), ['b2']);
    });
  });

  group('Booking Detail offline', () {
    test('renders the last-known detail and flags it stale', () async {
      final repo = _FakeBookingRepository()
        ..detailResults.add(Right(CachedResult(_booking('b1'), isStale: true)));
      final container = _container(repo);

      final booking = await container.read(bookingDetailProvider('b1').future);

      expect(booking.id, 'b1');
      expect(container.read(bookingDetailIsOfflineProvider('b1')), isTrue);
    });

    test('a booking never loaded before has nothing to show offline',
        () async {
      final container = _container(_FakeBookingRepository());

      await expectLater(
        container.read(bookingDetailProvider('never-opened').future),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('server-changing actions stay blocked offline', () {
    test('creating a booking is refused before any request is attempted',
        () async {
      ConnectivityService.instance.debugIsOnline = false;
      final repo = _FakeBookingRepository();
      final container = _container(repo);

      await expectLater(
        container
            .read(createBookingNotifierProvider.notifier)
            .submit(const CreateBookingRequest(
              serviceCategory: 'Plumbing',
              urgency: BookingUrgency.normal,
              description: 'leaky tap',
              addressLine: 'somewhere',
              city: 'Karachi',
              latitude: 24.86,
              longitude: 67.0,
            )),
        throwsA(
          isA<Failure>().having(
            (f) => f.code,
            'code',
            FailureCode.offlineActionBlocked,
          ),
        ),
      );
    });

    test('a blocked action creates NO record and queues NOTHING for later — '
        'HandyGo has no offline write queue', () async {
      ConnectivityService.instance.debugIsOnline = false;
      final repo = _FakeBookingRepository();
      final container = _container(repo);

      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          await container
              .read(createBookingNotifierProvider.notifier)
              .submit(const CreateBookingRequest(
                serviceCategory: 'Plumbing',
                urgency: BookingUrgency.normal,
                description: 'leaky tap',
                addressLine: 'somewhere',
                city: 'Karachi',
                latitude: 24.86,
                longitude: 67.0,
              ));
        } catch (_) {
          // expected
        }
      }

      // Coming back online must not flush anything that was "saved" offline.
      ConnectivityService.instance.debugIsOnline = true;
      await Future<void>.delayed(Duration.zero);

      expect(repo.cancelCalls, 0);
      final state = container.read(createBookingNotifierProvider);
      // The notifier's initial value is `null` (no booking); a blocked write
      // must leave it that way and stay in the error state, never produce a
      // BookingEntity that the UI would read as "created".
      expect(state.valueOrNull, isNull,
          reason: 'a blocked write must never produce a booking');
      expect(state.hasError, isTrue,
          reason: 'the block must surface, not silently succeed');
    });
  });

  group('reconnect refresh', () {
    test('replaces stale cached rows with authoritative server state',
        () async {
      final repo = _FakeBookingRepository()
        ..listResults.addAll([
          // First read: offline, last-known snapshot.
          Right(CachedResult([_booking('b1')], isStale: true)),
          // After reconnect: the server says it is now completed.
          Right(CachedResult([_booking('b1', status: BookingStatus.completed)])),
        ]);
      final container = _container(repo);

      var bookings = await container.read(bookingsNotifierProvider.future);
      expect(bookings.single.status, BookingStatus.pending);
      expect(container.read(bookingsIsOfflineProvider), isTrue);

      await container.read(bookingsNotifierProvider.notifier).refresh();

      bookings = container.read(bookingsNotifierProvider).requireValue;
      expect(bookings.single.status, BookingStatus.completed);
      expect(container.read(bookingsIsOfflineProvider), isFalse);
    });

    test('a status change moves the booking between filter tabs instead of '
        'vanishing', () async {
      final repo = _FakeBookingRepository()
        ..listResults.addAll([
          Right(CachedResult([_booking('b1')], isStale: true)),
          Right(CachedResult([_booking('b1', status: BookingStatus.completed)])),
        ]);
      final container = _container(repo);
      await container.read(bookingsNotifierProvider.future);

      container.read(bookingFilterProvider.notifier).setTab(BookingTab.completed);
      expect(container.read(filteredBookingsProvider), isEmpty);

      await container.read(bookingsNotifierProvider.notifier).refresh();

      expect(
        container.read(filteredBookingsProvider).map((b) => b.id),
        ['b1'],
      );
    });

    test('a failed background refresh keeps the existing rows on screen',
        () async {
      final repo = _FakeBookingRepository()
        ..listResults.addAll([
          Right(CachedResult([_booking('b1')])),
          Left(NetworkFailure('', code: FailureCode.noInternet)),
        ]);
      final container = _container(repo);
      await container.read(bookingsNotifierProvider.future);

      await container.read(bookingsNotifierProvider.notifier).refresh();

      // AsyncValue keeps the previous data alongside the error, which is what
      // the page's `when(skipError: true)` renders.
      expect(container.read(bookingsNotifierProvider).valueOrNull, isNotNull);
      expect(
        container.read(bookingsNotifierProvider).valueOrNull!.single.id,
        'b1',
      );
    });
  });
}
