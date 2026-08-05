import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/new_job_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/ongoing_job_entity.dart';

/// HandyGo has no "estimated price" concept for jobs. Every screen that
/// shows a job/booking price reads BookingEntity.canonicalPrice (or the
/// equivalent NewJobEntity.displayPrice / OngoingJobEntity.displayPrice,
/// which both delegate to the same canonicalWorkPrice rule) — never
/// estimatedPrice — so none of them can ever disagree or show a fake
/// estimate, Rs 0, or a fee+work breakdown that double-counts a number.
BookingEntity _booking({
  BookingLane lane = BookingLane.standard,
  BookingStatus status = BookingStatus.accepted,
  double? estimatedPrice,
  double? finalPrice,
  double? acceptedBidAmount,
  String? sourceInspectionBookingId,
  double? inspectionFeeSnapshot,
  InspectionDecisionStatus? inspectionDecisionStatus,
  AssignedWorkerEntity? assignedWorker,
  List<BookingStandardServiceItemEntity> standardServiceItems = const [],
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
    inspectionFeeSnapshot: inspectionFeeSnapshot,
    inspectionDecisionStatus: inspectionDecisionStatus,
    assignedWorker: assignedWorker,
    standardServiceItems: standardServiceItems,
  );
}

const _worker = AssignedWorkerEntity(
  id: 'w1',
  firstName: 'Ali',
  lastName: 'Khan',
);

void main() {
  group('canonicalPrice — the one figure every screen reads', () {
    test('STANDARD: shows the fixed catalog total before any hire', () {
      // Known upfront from the item snapshots — never waits for assignment,
      // and never reads estimatedPrice even when it happens to be set.
      final booking = _booking(
        lane: BookingLane.standard,
        status: BookingStatus.pending,
        estimatedPrice: 9999,
        standardServiceItems: const [
          BookingStandardServiceItemEntity(
            id: 'i1',
            nameSnapshot: 'AC Service',
            priceSnapshot: 2500,
          ),
        ],
      );
      expect(booking.canonicalPrice, 2500);
    });

    test('STANDARD: stays the same fixed price once a worker is hired', () {
      final booking = _booking(
        lane: BookingLane.standard,
        status: BookingStatus.accepted,
        finalPrice: 2500,
        standardServiceItems: const [
          BookingStandardServiceItemEntity(
            id: 'i1',
            nameSnapshot: 'AC Service',
            priceSnapshot: 2500,
          ),
        ],
        assignedWorker: _worker,
      );
      expect(booking.canonicalPrice, 2500);
    });

    test('INSPECTION: shows the fee before any hire', () {
      final booking = _booking(
        lane: BookingLane.inspection,
        status: BookingStatus.pending,
        estimatedPrice: 9999,
        inspectionFeeSnapshot: 500,
      );
      expect(booking.canonicalPrice, 500);
    });

    test('BIDDING: null before any bid is accepted — never Rs 0', () {
      final booking = _booking(
        lane: BookingLane.bidding,
        status: BookingStatus.pending,
        estimatedPrice: 3000,
      );
      expect(booking.canonicalPrice, isNull);
    });

    test('BIDDING: shows only the accepted bid once hired', () {
      final booking = _booking(
        lane: BookingLane.bidding,
        status: BookingStatus.accepted,
        estimatedPrice: 3000,
        acceptedBidAmount: 4500,
        assignedWorker: _worker,
      );
      expect(booking.canonicalPrice, 4500);
    });

    test('never reads estimatedPrice, even as a last resort', () {
      for (final lane in BookingLane.values) {
        final booking = _booking(lane: lane, estimatedPrice: 7777);
        expect(
          booking.canonicalPrice,
          isNot(7777),
          reason: '$lane leaked estimatedPrice into canonicalPrice',
        );
      }
    });
  });

  group('displayPrice — the one row the Qeemat card renders', () {
    test('STANDARD: shows the fixed job price as Agreed Price while live', () {
      final booking = _booking(
        lane: BookingLane.standard,
        status: BookingStatus.accepted,
        finalPrice: 2500,
        assignedWorker: _worker,
      );
      expect(booking.displayPrice, (DisplayPriceLabel.agreed, 2500));
    });

    test('STANDARD: relabels Final Price once completed, same amount', () {
      final booking = _booking(
        lane: BookingLane.standard,
        status: BookingStatus.completed,
        finalPrice: 2500,
        assignedWorker: _worker,
      );
      expect(booking.displayPrice, (DisplayPriceLabel.finalPrice, 2500));
    });

    test('BIDDING: shows the accepted bid, never the original estimate', () {
      final live = _booking(
        lane: BookingLane.bidding,
        status: BookingStatus.accepted,
        estimatedPrice: 3000,
        acceptedBidAmount: 4500,
        assignedWorker: _worker,
      );
      expect(live.displayPrice, (DisplayPriceLabel.agreed, 4500));

      final completed = _booking(
        lane: BookingLane.bidding,
        status: BookingStatus.completed,
        estimatedPrice: 3000,
        acceptedBidAmount: 4500,
        finalPrice: 4500,
        assignedWorker: _worker,
      );
      expect(completed.displayPrice, (DisplayPriceLabel.finalPrice, 4500));
    });

    test('BIDDING: hidden entirely before a bid is accepted', () {
      final booking = _booking(
        lane: BookingLane.bidding,
        status: BookingStatus.pending,
        estimatedPrice: 3000,
      );
      final (label, amount) = booking.displayPrice;
      expect(label, DisplayPriceLabel.agreed);
      expect(amount, isNull);
    });

    test('INSPECTION closed after inspection: fee only, no breakdown', () {
      final booking = _booking(
        lane: BookingLane.inspection,
        status: BookingStatus.completed,
        finalPrice: 500,
        inspectionFeeSnapshot: 500,
        inspectionDecisionStatus:
            InspectionDecisionStatus.closedAfterInspection,
        assignedWorker: _worker,
      );
      expect(
        booking.displayPrice,
        (DisplayPriceLabel.inspectionFee, 500),
      );
    });

    test('INSPECTION rehired inspector: repair price only, fee waived', () {
      // setInspectionRepairPrice already replaced finalPrice with the repair
      // quote server-side — the fee is gone from the number entirely.
      final booking = _booking(
        lane: BookingLane.inspection,
        status: BookingStatus.completed,
        inspectionFeeSnapshot: 500,
        finalPrice: 3000,
        inspectionDecisionStatus: InspectionDecisionStatus.acceptedRepair,
        assignedWorker: _worker,
      );
      expect(booking.displayPrice, (DisplayPriceLabel.finalPrice, 3000));
    });

    test(
      'INSPECTION find other Ustaad: original booking shows fee only, '
      'never fee+work',
      () {
        // The backend never touches finalPrice for this outcome — it stays
        // equal to inspectionFeeSnapshot from assignment time. The old UI
        // treated that as a "work charge" on top of the fee and doubled the
        // total; displayPrice must collapse it to one number.
        final original = _booking(
          lane: BookingLane.inspection,
          status: BookingStatus.completed,
          finalPrice: 500,
          inspectionFeeSnapshot: 500,
          inspectionDecisionStatus: InspectionDecisionStatus.findOtherUstaad,
          assignedWorker: _worker,
        );
        expect(
          original.displayPrice,
          (DisplayPriceLabel.inspectionFee, 500),
        );
      },
    );

    test(
      'INSPECTION → BIDDING child: shows only the new worker\'s accepted bid',
      () {
        final child = _booking(
          lane: BookingLane.bidding,
          status: BookingStatus.completed,
          sourceInspectionBookingId: 'inspection-1',
          acceptedBidAmount: 4500,
          finalPrice: 4500,
          assignedWorker: _worker,
        );
        expect(child.displayPrice, (DisplayPriceLabel.finalPrice, 4500));
      },
    );

    test(
      'original inspection and linked repair child never merge into one '
      'total',
      () {
        // Two separate work units, two separate bookings — the original
        // inspection booking's own price must stay just the fee even though
        // a same-session repair child exists and was hired for far more.
        final original = _booking(
          lane: BookingLane.inspection,
          status: BookingStatus.completed,
          finalPrice: 500,
          inspectionFeeSnapshot: 500,
          inspectionDecisionStatus: InspectionDecisionStatus.findOtherUstaad,
        );
        final child = _booking(
          lane: BookingLane.bidding,
          status: BookingStatus.completed,
          sourceInspectionBookingId: 'inspection-1',
          acceptedBidAmount: 6000,
          finalPrice: 6000,
        );

        expect(original.displayPrice.$2, 500);
        expect(child.displayPrice.$2, 6000);
        // Never the sum of the two separate work units.
        expect(original.displayPrice.$2! + child.displayPrice.$2!, isNot(6000));
      },
    );

    test('no double-counting: amount never sums fee and work price', () {
      final original = _booking(
        lane: BookingLane.inspection,
        status: BookingStatus.completed,
        finalPrice: 500,
        inspectionFeeSnapshot: 500,
        inspectionDecisionStatus: InspectionDecisionStatus.findOtherUstaad,
        assignedWorker: _worker,
      );
      final (_, amount) = original.displayPrice;
      // The old breakdown rendered inspectionFeeSnapshot + finalPrice = 1000.
      expect(amount, 500);
      expect(amount, isNot(1000));
    });

    test('nothing at all: amount is null, never estimatedPrice', () {
      final (label, amount) = _booking().displayPrice;
      expect(label, DisplayPriceLabel.agreed);
      expect(amount, isNull);
    });

    test(
      'Booking Details amount equals Track Worker\'s canonicalPrice for '
      'every lane/outcome',
      () {
        // Track Worker renders booking.canonicalPrice directly (see
        // track_worker_page.dart). Reproducing every shape here proves the
        // Qeemat card can never show a different number.
        for (final booking in [
          _booking(
            lane: BookingLane.standard,
            status: BookingStatus.accepted,
            finalPrice: 2500,
            assignedWorker: _worker,
          ),
          _booking(
            lane: BookingLane.standard,
            status: BookingStatus.completed,
            finalPrice: 2500,
            assignedWorker: _worker,
          ),
          _booking(
            lane: BookingLane.bidding,
            status: BookingStatus.completed,
            acceptedBidAmount: 4500,
            finalPrice: 4500,
            assignedWorker: _worker,
          ),
          _booking(
            lane: BookingLane.inspection,
            status: BookingStatus.completed,
            finalPrice: 3000,
            inspectionFeeSnapshot: 500,
            inspectionDecisionStatus: InspectionDecisionStatus.acceptedRepair,
            assignedWorker: _worker,
          ),
          _booking(
            lane: BookingLane.bidding,
            status: BookingStatus.completed,
            sourceInspectionBookingId: 'inspection-1',
            acceptedBidAmount: 4500,
            finalPrice: 4500,
            assignedWorker: _worker,
          ),
        ]) {
          final (_, amount) = booking.displayPrice;
          expect(amount, booking.canonicalPrice);
        }

        // The two FIND_OTHER_USTAAD/CLOSED_AFTER_INSPECTION fee-only shapes:
        // Track Worker's canonicalPrice resolves to finalPrice (no bid, no
        // repair-quote overwrite), which the backend always keeps equal to
        // inspectionFeeSnapshot for these outcomes.
        for (final decision in [
          InspectionDecisionStatus.closedAfterInspection,
          InspectionDecisionStatus.findOtherUstaad,
        ]) {
          final booking = _booking(
            lane: BookingLane.inspection,
            status: BookingStatus.completed,
            finalPrice: 500,
            inspectionFeeSnapshot: 500,
            inspectionDecisionStatus: decision,
            assignedWorker: _worker,
          );
          final (_, amount) = booking.displayPrice;
          expect(amount, booking.canonicalPrice);
        }
      },
    );
  });

  group('NewJobEntity.displayPrice — Available Ustaad / New Jobs card', () {
    NewJobEntity job({
      BookingLane lane = BookingLane.standard,
      double? inspectionFeeSnapshot,
      List<BookingStandardServiceItemEntity> items = const [],
    }) {
      return NewJobEntity(
        id: 'j1',
        status: BookingStatus.pending,
        urgency: BookingUrgency.normal,
        city: 'Lahore',
        latitude: 0,
        longitude: 0,
        createdAt: DateTime(2026, 7, 1),
        category: const NewJobCategoryEntity(id: 'c1', name: 'Electrician'),
        client: const NewJobClientEntity(id: 'cl1', firstName: 'A', lastName: 'B'),
        bidCount: 0,
        lane: lane,
        inspectionFeeSnapshot: inspectionFeeSnapshot,
        standardServiceItems: items,
      );
    }

    test('STANDARD: shows the fixed catalog total', () {
      final j = job(
        lane: BookingLane.standard,
        items: const [
          BookingStandardServiceItemEntity(
            id: 'i1',
            nameSnapshot: 'AC Service',
            priceSnapshot: 2200,
          ),
        ],
      );
      expect(j.displayPrice, 2200);
    });

    test('INSPECTION: shows the fee', () {
      final j = job(lane: BookingLane.inspection, inspectionFeeSnapshot: 500);
      expect(j.displayPrice, 500);
    });

    test('BIDDING: no price before a bid is placed/accepted', () {
      final j = job(lane: BookingLane.bidding);
      expect(j.displayPrice, isNull);
    });
  });

  group('OngoingJobEntity.displayPrice — Worker Home active-job card', () {
    OngoingJobEntity job({
      required String lane,
      double? finalPrice,
      double? acceptedBidAmount,
      double? inspectionFeeSnapshot,
      double? standardServicesTotal,
      String? inspectionDecisionStatusRaw,
    }) {
      return OngoingJobEntity(
        id: 'o1',
        categoryName: 'Electrician',
        clientArea: 'Lahore',
        addressLine: 'Street 1',
        status: 'ACCEPTED',
        lane: lane,
        finalPrice: finalPrice,
        acceptedBidAmount: acceptedBidAmount,
        inspectionFeeSnapshot: inspectionFeeSnapshot,
        standardServicesTotal: standardServicesTotal,
        inspectionDecisionStatusRaw: inspectionDecisionStatusRaw,
      );
    }

    test('STANDARD: shows the hired fixed price', () {
      final j = job(lane: 'STANDARD', standardServicesTotal: 2500, finalPrice: 2500);
      expect(j.displayPrice, 2500);
    });

    test('INSPECTION: shows the fee before a decision', () {
      final j = job(lane: 'INSPECTION', inspectionFeeSnapshot: 500, finalPrice: 500);
      expect(j.displayPrice, 500);
    });

    test('INSPECTION rehired: shows the repair price, fee waived', () {
      final j = job(
        lane: 'INSPECTION',
        inspectionFeeSnapshot: 500,
        finalPrice: 3000,
        inspectionDecisionStatusRaw: 'ACCEPTED_REPAIR',
      );
      expect(j.displayPrice, 3000);
    });

    test('BIDDING: shows the accepted bid', () {
      final j = job(lane: 'BIDDING', acceptedBidAmount: 4500, finalPrice: 4500);
      expect(j.displayPrice, 4500);
    });

    test('matches BookingEntity.canonicalPrice for the same work unit', () {
      // My Jobs (BookingEntity) and Home (OngoingJobEntity) must never show
      // a different number for the booking currently being worked on.
      final booking = _booking(
        lane: BookingLane.inspection,
        status: BookingStatus.accepted,
        finalPrice: 500,
        inspectionFeeSnapshot: 500,
        assignedWorker: _worker,
      );
      final ongoing = job(
        lane: 'INSPECTION',
        inspectionFeeSnapshot: 500,
        finalPrice: 500,
      );
      expect(ongoing.displayPrice, booking.canonicalPrice);
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
