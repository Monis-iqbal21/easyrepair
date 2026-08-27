import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/presentation/utils/status_labels.dart';
import 'package:handygo_app/l10n/app_localizations.dart';

import '../../support/l10n_test_app.dart';

/// AWAITING_CONFIRMATION and SETTLED are real values of the backend
/// `BookingStatus` enum (added by migration
/// 20260821000000_add_booking_settlement_foundation). Before this test they
/// fell through `BookingStatusX.fromRaw`'s defensive default and silently
/// became PENDING, which showed a finished job as "Live"/Active.
///
/// Authoritative grouping evidence, both backend-side:
///   * admin-operations.service.ts — settleableStatuses =
///     [COMPLETED, AWAITING_CONFIRMATION, SETTLED]
///   * admin-operations.repository.ts — earnings/commission queries count
///     status IN (COMPLETED, SETTLED)
/// Neither value appears in any active/live set anywhere in the backend.
void main() {
  group('settlement-era BookingStatus parsing', () {
    test('AWAITING_CONFIRMATION does not silently become PENDING', () {
      final status = BookingStatusX.fromRaw('AWAITING_CONFIRMATION');

      expect(status, BookingStatus.awaitingConfirmation);
      expect(status, isNot(BookingStatus.pending));
    });

    test('SETTLED does not silently become PENDING', () {
      final status = BookingStatusX.fromRaw('SETTLED');

      expect(status, BookingStatus.settled);
      expect(status, isNot(BookingStatus.pending));
    });

    test('raw round-trips for both new statuses', () {
      expect(BookingStatus.awaitingConfirmation.raw, 'AWAITING_CONFIRMATION');
      expect(BookingStatus.settled.raw, 'SETTLED');
      for (final status in BookingStatus.values) {
        expect(BookingStatusX.fromRaw(status.raw), status);
      }
    });

    test('genuinely unknown future values still degrade to PENDING', () {
      expect(
        BookingStatusX.fromRaw('SOME_STATUS_INVENTED_IN_2027'),
        BookingStatus.pending,
      );
      expect(BookingStatusX.fromRaw(''), BookingStatus.pending);
    });

    test('every pre-existing status mapping is unchanged', () {
      expect(BookingStatusX.fromRaw('PENDING'), BookingStatus.pending);
      expect(BookingStatusX.fromRaw('ACCEPTED'), BookingStatus.accepted);
      expect(BookingStatusX.fromRaw('EN_ROUTE'), BookingStatus.enRoute);
      expect(BookingStatusX.fromRaw('ARRIVED'), BookingStatus.arrived);
      expect(BookingStatusX.fromRaw('IN_PROGRESS'), BookingStatus.inProgress);
      expect(BookingStatusX.fromRaw('COMPLETED'), BookingStatus.completed);
      expect(BookingStatusX.fromRaw('REJECTED'), BookingStatus.rejected);
      expect(BookingStatusX.fromRaw('CANCELLED'), BookingStatus.cancelled);
      expect(BookingStatusX.fromRaw('EXPIRED'), BookingStatus.expired);
    });
  });

  group('settlement-era Client filter placement', () {
    test('both land in the Completed group, never Live or Assigned', () {
      expect(BookingStatus.awaitingConfirmation.tab, BookingTab.completed);
      expect(BookingStatus.settled.tab, BookingTab.completed);
    });

    test('pre-existing tab placement is unchanged', () {
      expect(BookingStatus.pending.tab, BookingTab.live);
      expect(BookingStatus.inProgress.tab, BookingTab.live);
      expect(BookingStatus.accepted.tab, BookingTab.assigned);
      expect(BookingStatus.enRoute.tab, BookingTab.assigned);
      expect(BookingStatus.arrived.tab, BookingTab.assigned);
      expect(BookingStatus.completed.tab, BookingTab.completed);
      expect(BookingStatus.rejected.tab, BookingTab.cancelled);
      expect(BookingStatus.cancelled.tab, BookingTab.cancelled);
      expect(BookingStatus.expired.tab, BookingTab.cancelled);
    });

    test('neither status counts as a worker-actionable job', () {
      expect(BookingStatus.awaitingConfirmation.isWorkerActive, isFalse);
      expect(BookingStatus.settled.isWorkerActive, isFalse);
    });
  });

  group('settlement-era status labels', () {
    late AppLocalizations en;
    late AppLocalizations urLatn;

    testWidgets('resolve localizations', (tester) async {
      await tester.pumpWidget(
        localizedApp(
          Builder(
            builder: (context) {
              en = AppLocalizations.of(context)!;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        localizedApp(
          Builder(
            builder: (context) {
              urLatn = AppLocalizations.of(context)!;
              return const SizedBox.shrink();
            },
          ),
          locale: AppLocale.romanUrdu,
        ),
      );

      // Client-facing label: a settling job reads as finished, not live.
      expect(
        bookingStatusLabel(en, BookingStatus.awaitingConfirmation),
        en.bookingStatusCompleted,
      );
      expect(
        bookingStatusLabel(en, BookingStatus.settled),
        en.bookingStatusCompleted,
      );
      expect(
        bookingStatusLabel(en, BookingStatus.awaitingConfirmation),
        isNot(en.bookingStatusLive),
      );
      expect(
        bookingStatusLabel(en, BookingStatus.settled),
        isNot(en.bookingStatusLive),
      );

      // Bookings-card wording, English and Roman Urdu.
      expect(
        bookingCardStatusLabel(en, BookingStatus.awaitingConfirmation),
        en.bookingStatusCompleted,
      );
      expect(
        bookingCardStatusLabel(en, BookingStatus.settled),
        en.bookingStatusCompleted,
      );
      expect(
        bookingCardStatusLabel(
          urLatn,
          BookingStatus.awaitingConfirmation,
          romanUrdu: true,
        ),
        urLatn.workerComplete,
      );
      expect(
        bookingCardStatusLabel(urLatn, BookingStatus.settled, romanUrdu: true),
        urLatn.workerComplete,
      );

      // Ustaad-facing label.
      expect(
        workerJobStatusLabel(en, BookingStatus.awaitingConfirmation),
        en.bookingStatusCompleted,
      );
      expect(
        workerJobStatusLabel(en, BookingStatus.settled),
        en.bookingStatusCompleted,
      );
    });
  });
}
