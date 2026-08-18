import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/features/bookings/data/models/booking_model.dart';
import 'package:handygo_app/features/bookings/domain/entities/attachable_inspection_entity.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/domain/entities/create_booking_request.dart';

/// "Attach a previous inspection report" — the OPTIONAL, read-only reference
/// a client may add while independently posting a BIDDING job.
///
/// The critical property throughout: it must be indistinguishable from an
/// ordinary bidding job except for the extra report entry point, and it must
/// never be conflated with `sourceInspectionBookingId` (the post-inspection
/// "Find Other Ustaad" relationship).
void main() {
  Map<String, dynamic> bookingJson({
    String? sourceInspectionBookingId,
    String? attachedInspectionBookingId,
    String lane = 'BIDDING',
  }) =>
      {
        'id': 'booking-1',
        'serviceCategory': 'AC Technician',
        'status': 'PENDING',
        'urgency': 'NORMAL',
        'city': 'Karachi',
        'createdAt': '2026-08-12T10:00:00.000Z',
        'lane': lane,
        // Sent explicitly (including as null) — the parser reads both as
        // nullable, so this mirrors a real payload without conditionals.
        'sourceInspectionBookingId': sourceInspectionBookingId,
        'attachedInspectionBookingId': attachedInspectionBookingId,
      };

  group('BookingEntity — attached inspection reference', () {
    test('parses attachedInspectionBookingId independently of the source link',
        () {
      final entity = BookingModel.fromJson(
        bookingJson(attachedInspectionBookingId: 'old-inspection-1'),
      ).toEntity();

      expect(entity.attachedInspectionBookingId, 'old-inspection-1');
      // The post-inspection relationship must stay empty — these are
      // different concepts and must never be conflated.
      expect(entity.sourceInspectionBookingId, isNull);
    });

    test('an ordinary bidding job has neither reference', () {
      final entity = BookingModel.fromJson(bookingJson()).toEntity();

      expect(entity.attachedInspectionBookingId, isNull);
      expect(entity.sourceInspectionBookingId, isNull);
      expect(entity.hasLinkedInspectionReport, isFalse);
      expect(entity.hasInspectionReportToShow, isFalse);
    });

    test('hasLinkedInspectionReport is true for an ATTACHED report', () {
      final entity = BookingModel.fromJson(
        bookingJson(attachedInspectionBookingId: 'old-inspection-1'),
      ).toEntity();

      expect(entity.hasLinkedInspectionReport, isTrue);
    });

    test('hasLinkedInspectionReport is still true for a SPAWNED repair job '
        '(existing Find Other Ustaad flow unchanged)', () {
      final entity = BookingModel.fromJson(
        bookingJson(sourceInspectionBookingId: 'inspection-1'),
      ).toEntity();

      expect(entity.hasLinkedInspectionReport, isTrue);
      expect(entity.attachedInspectionBookingId, isNull);
    });

    test('the client detail page offers the report viewer for an attachment', () {
      final entity = BookingModel.fromJson(
        bookingJson(attachedInspectionBookingId: 'old-inspection-1'),
      ).toEntity();

      expect(entity.hasInspectionReportToShow, isTrue);
    });

    test('both routes look identical to the UI — one entry point, no branching',
        () {
      final attached = BookingModel.fromJson(
        bookingJson(attachedInspectionBookingId: 'old-inspection-1'),
      ).toEntity();
      final spawned = BookingModel.fromJson(
        bookingJson(sourceInspectionBookingId: 'inspection-1'),
      ).toEntity();

      expect(
        attached.hasLinkedInspectionReport,
        spawned.hasLinkedInspectionReport,
      );
      expect(
        attached.hasInspectionReportToShow,
        spawned.hasInspectionReportToShow,
      );
    });
  });

  group('CreateBookingRequest — optional attachment', () {
    test('defaults to no attachment, leaving normal posting unchanged', () {
      const request = CreateBookingRequest(
        serviceCategory: 'AC Technician',
        urgency: BookingUrgency.normal,
        addressLine: '123 Street',
      );

      expect(request.attachedInspectionBookingId, isNull);
    });

    test('carries the chosen inspection booking id when one is attached', () {
      const request = CreateBookingRequest(
        serviceCategory: 'AC Technician',
        urgency: BookingUrgency.normal,
        addressLine: '123 Street',
        lane: BookingLane.bidding,
        attachedInspectionBookingId: 'old-inspection-1',
      );

      expect(request.attachedInspectionBookingId, 'old-inspection-1');
    });
  });

  group('AttachableInspectionEntity', () {
    Map<String, dynamic> json({
      String? issueFound,
      String? recommendedRepair,
    }) =>
        {
          'bookingId': 'insp-1',
          'categoryId': 'cat-1',
          'categoryName': 'AC Technician',
          'inspectionDate': '2026-08-12T10:00:00.000Z',
          'issueFound': issueFound,
          'recommendedRepair': recommendedRepair,
        };

    test('parses the selector payload', () {
      final e = AttachableInspectionEntity.fromJson(
        json(issueFound: 'Cooling issue diagnosed'),
      );

      expect(e.bookingId, 'insp-1');
      expect(e.categoryName, 'AC Technician');
      expect(e.inspectionDate.toUtc().year, 2026);
      expect(e.summary, 'Cooling issue diagnosed');
    });

    test('falls back to the recommended repair when no issue text exists', () {
      final e = AttachableInspectionEntity.fromJson(
        json(recommendedRepair: 'Replace compressor'),
      );

      expect(e.summary, 'Replace compressor');
    });

    test('a voice-note-only report (no written text) has no summary line', () {
      final e = AttachableInspectionEntity.fromJson(json());

      expect(e.summary, isNull);
    });

    test('blank strings are treated as absent, never rendered as empty text', () {
      final e = AttachableInspectionEntity.fromJson(
        json(issueFound: '   ', recommendedRepair: ''),
      );

      expect(e.summary, isNull);
    });
  });
}
