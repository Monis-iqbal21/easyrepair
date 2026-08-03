import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';

/// Two bugs that both came from a screen deriving something the entity should
/// own:
///
///  * Booking Details read estimated/final price directly and so disagreed
///    with Track Worker, which already preferred the accepted bid.
///  * Booking Details hid the inspection report unless the booking was still
///    INSPECTION-lane *and* currently assigned, so the report vanished the
///    moment the client pressed "Find Other Ustaad".
BookingEntity _booking({
  BookingLane lane = BookingLane.standard,
  BookingStatus status = BookingStatus.accepted,
  double? estimatedPrice,
  double? finalPrice,
  double? acceptedBidAmount,
  String? sourceInspectionBookingId,
}) {
  return BookingEntity(
    id: 'b1',
    referenceId: 'HG-1',
    serviceCategory: 'Electrician',
    serviceEmoji: '⚡',
    status: status,
    urgency: BookingUrgency.normal,
    createdAt: DateTime(2026, 7, 1),
    lane: lane,
    estimatedPrice: estimatedPrice,
    finalPrice: finalPrice,
    acceptedBidAmount: acceptedBidAmount,
    sourceInspectionBookingId: sourceInspectionBookingId,
  );
}

void main() {
  group('agreedPrice — the one figure both screens read', () {
    test('prefers the accepted bid over the client\'s original estimate', () {
      // A BIDDING or rehired job: estimatedPrice is what the client guessed,
      // acceptedBidAmount is what they actually agreed to pay.
      final booking = _booking(
        lane: BookingLane.bidding,
        estimatedPrice: 3000,
        acceptedBidAmount: 4500,
      );

      expect(booking.agreedPrice, 4500);
    });

    test('falls back to the final price when there was no bid', () {
      expect(_booking(estimatedPrice: 3000, finalPrice: 3200).agreedPrice, 3200);
    });

    test('falls back to the estimate when nothing has been agreed yet', () {
      expect(_booking(estimatedPrice: 3000).agreedPrice, 3000);
    });

    test('is null when there is no figure at all', () {
      expect(_booking().agreedPrice, isNull);
    });

    test('resolves identically for Track Worker and Booking Details', () {
      // Both screens now call this getter. Reproducing Track Worker's old
      // inline expression here proves Booking Details cannot drift from it.
      for (final booking in [
        _booking(estimatedPrice: 3000, acceptedBidAmount: 4500),
        _booking(estimatedPrice: 3000, finalPrice: 3200),
        _booking(estimatedPrice: 3000),
        _booking(),
      ]) {
        final trackWorkerValue = booking.acceptedBidAmount ??
            booking.finalPrice ??
            booking.estimatedPrice;
        expect(booking.agreedPrice, trackWorkerValue);
      }
    });
  });

  group('hasInspectionReportToShow — survives every re-hire', () {
    test('an inspection booking offers its report', () {
      expect(
        _booking(lane: BookingLane.inspection).hasInspectionReportToShow,
        isTrue,
      );
    });

    test('still offers it while unassigned after Find Other Ustaad', () {
      // The window that used to lose the report: the client has released the
      // inspector and not yet hired a replacement.
      final booking = _booking(
        lane: BookingLane.inspection,
        status: BookingStatus.pending,
      );

      expect(booking.assignedWorker, isNull);
      expect(booking.hasInspectionReportToShow, isTrue);
    });

    test('the linked BIDDING repair booking offers it too', () {
      // The child carries no report row of its own; the backend resolves the
      // id back to the source inspection booking.
      final booking = _booking(
        lane: BookingLane.bidding,
        sourceInspectionBookingId: 'inspection-1',
      );

      expect(booking.hasInspectionReportToShow, isTrue);
    });

    test('holds no matter how many times the worker changes', () {
      // The flag depends only on the booking's identity, never on who is
      // currently hired, so repeated re-hires cannot drop it.
      for (final status in [
        BookingStatus.pending,
        BookingStatus.accepted,
        BookingStatus.inProgress,
        BookingStatus.completed,
      ]) {
        expect(
          _booking(lane: BookingLane.inspection, status: status)
              .hasInspectionReportToShow,
          isTrue,
          reason: 'lost the report at $status',
        );
      }
    });

    test('an ordinary standard job never asks for one', () {
      expect(_booking().hasInspectionReportToShow, isFalse);
      expect(
        _booking(lane: BookingLane.bidding).hasInspectionReportToShow,
        isFalse,
      );
    });
  });
}
