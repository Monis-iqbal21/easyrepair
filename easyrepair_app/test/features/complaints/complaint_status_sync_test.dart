import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/complaints/domain/entities/complaint_entity.dart';
import 'package:handygo_app/features/complaints/domain/repositories/complaint_repository.dart';
import 'package:handygo_app/features/complaints/presentation/providers/complaint_providers.dart';
import 'package:handygo_app/features/complaints/presentation/widgets/booking_complaint_section.dart';
import 'package:handygo_app/l10n/app_localizations.dart';

/// Issue 4: Admin moves a report on (OPEN -> IN_PROGRESS -> RESOLVED ->
/// CLOSED) and the client app must end up showing the real server status.
///
/// The server is authoritative, so every one of these asserts that the app
/// RE-READS it — never that some local copy was patched.
void main() {
  group('complaint status stays in sync with the server', () {
    test('an authoritative refetch reflects every admin transition', () async {
      final repository = _FakeComplaintRepository(ComplaintStatus.open);
      final container = ProviderContainer(
        overrides: [complaintRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      // 1. Client sees PENDING (the server's OPEN).
      expect(
        (await container.read(bookingComplaintProvider('booking-1').future))
            ?.status,
        ComplaintStatus.open,
      );

      // 2..4. Admin drives it forward. Each fresh read must return the new
      // authoritative state, not the first one that was ever fetched.
      for (final next in [
        ComplaintStatus.inProgress,
        ComplaintStatus.resolved,
        ComplaintStatus.closed,
      ]) {
        repository.status = next;
        // Let the autoDispose provider actually drop: with nothing watching it
        // (Booking Detail closed), the next read has to go back to the server.
        await container.pump();
        final seen =
            (await container.read(bookingComplaintProvider('booking-1').future))
                ?.status;
        expect(seen, next, reason: next.name);
      }

      // No cache pinned the original status: every read hit the server.
      expect(repository.lookupCalls, 4);
    });

    test('invalidation refreshes a complaint that is being watched', () async {
      final repository = _FakeComplaintRepository(ComplaintStatus.open);
      final container = ProviderContainer(
        overrides: [complaintRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      // A live listener is what a mounted Booking Detail looks like.
      final sub = container.listen(
        bookingComplaintProvider('booking-1'),
        (_, _) {},
      );
      addTearDown(sub.close);
      expect(
        (await container.read(bookingComplaintProvider('booking-1').future))
            ?.status,
        ComplaintStatus.open,
      );

      // This is exactly what the complaint push handler in app.dart does.
      repository.status = ComplaintStatus.resolved;
      container.invalidate(bookingComplaintProvider('booking-1'));

      expect(
        (await container.read(bookingComplaintProvider('booking-1').future))
            ?.status,
        ComplaintStatus.resolved,
      );
      expect(repository.lookupCalls, 2);
    });

    testWidgets(
      'reopening Booking Detail after a missed push still shows the latest status',
      (tester) async {
        final repository = _FakeComplaintRepository(ComplaintStatus.open);
        final router = _router();
        await tester.pumpWidget(_app(repository: repository, router: router));
        await tester.pumpAndSettle();

        expect(find.text('Pending'), findsOneWidget);
        expect(repository.lookupCalls, 1);

        // Admin resolves it. No push is delivered to this device at all.
        repository.status = ComplaintStatus.resolved;

        // The client leaves Booking Detail and comes back — the ONE recovery
        // path that must always work.
        router.go('/elsewhere');
        await tester.pumpAndSettle();
        router.go('/client/booking/booking-1');
        await tester.pumpAndSettle();

        expect(repository.lookupCalls, 2);
        expect(find.text('Resolved'), findsOneWidget);
        expect(find.text('Pending'), findsNothing);
      },
    );

    testWidgets('a CLOSED report is never shown as pending', (tester) async {
      final repository = _FakeComplaintRepository(ComplaintStatus.open);
      final router = _router();
      await tester.pumpWidget(_app(repository: repository, router: router));
      await tester.pumpAndSettle();
      expect(find.text('Pending'), findsOneWidget);

      repository.status = ComplaintStatus.closed;
      router.go('/elsewhere');
      await tester.pumpAndSettle();
      router.go('/client/booking/booking-1');
      await tester.pumpAndSettle();

      expect(find.text('Pending'), findsNothing);
    });
  });
}

Widget _app({
  required _FakeComplaintRepository repository,
  required GoRouter router,
}) {
  return ProviderScope(
    overrides: [complaintRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/client/booking/booking-1',
    routes: [
      GoRoute(
        path: '/client/booking/:id',
        builder: (_, state) => Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: BookingComplaintSection(
              bookingId: state.pathParameters['id']!,
              bookingStatus: BookingStatus.completed,
              isClient: true,
              ownsBooking: true,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/elsewhere',
        builder: (_, _) => const Scaffold(body: Text('elsewhere')),
      ),
    ],
  );
}

/// Server-side state the client can only learn about by asking.
class _FakeComplaintRepository implements ComplaintRepository {
  _FakeComplaintRepository(this.status);

  ComplaintStatus status;
  int lookupCalls = 0;

  @override
  Future<Either<Failure, ComplaintEntity?>> getForBooking(
    String bookingId,
  ) async {
    lookupCalls += 1;
    return Right(
      ComplaintEntity(
        id: 'complaint-1',
        bookingId: bookingId,
        reporterUserId: 'client-1',
        reportedWorkerProfileId: 'worker-1',
        issueTypes: const [ComplaintIssueType.workQuality],
        source: 'APP_CUSTOMER',
        status: status,
        humanRequested: false,
        createdAt: DateTime.utc(2026, 8, 27, 10),
        updatedAt: DateTime.utc(2026, 8, 27, 10),
      ),
    );
  }

  @override
  Future<Either<Failure, ComplaintEntity>> createForBooking({
    required String bookingId,
    required Set<ComplaintIssueType> issueTypes,
    String? otherText,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ComplaintEntity>> requestHuman(
    String complaintId,
  ) async => throw UnimplementedError();
}
