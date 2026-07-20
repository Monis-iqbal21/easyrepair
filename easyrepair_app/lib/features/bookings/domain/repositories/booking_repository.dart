import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/booking_entity.dart';
import '../entities/create_booking_request.dart';
import '../entities/inspection_report_entity.dart';
import '../entities/nearby_worker_entity.dart';
import '../entities/update_booking_request.dart';

abstract class BookingRepository {
  /// Fetch all bookings for the currently authenticated client.
  Future<Either<Failure, List<BookingEntity>>> getClientBookings();

  /// Fetch a single booking by id.
  Future<Either<Failure, BookingEntity>> getBookingById(String bookingId);

  /// Create a new service request / booking.
  Future<Either<Failure, BookingEntity>> createBooking(
    CreateBookingRequest request,
  );

  /// Update a PENDING booking (no worker assigned yet).
  Future<Either<Failure, BookingEntity>> updateBooking(
    UpdateBookingRequest request,
  );

  /// Cancel a booking by id (only valid for PENDING/ACCEPTED status).
  /// A reason is required — the backend rejects an empty reason.
  Future<Either<Failure, BookingEntity>> cancelBooking(
    String bookingId,
    String reason,
  );

  /// Submit a review for a completed booking.
  Future<Either<Failure, BookingEntity>> submitReview(ReviewRequest request);

  /// Upload a file attachment to an existing PENDING booking.
  Future<Either<Failure, BookingAttachmentEntity>> uploadAttachment(
    String bookingId,
    File file,
    String mimeType, {
    double? durationSeconds,
  });

  /// Delete an attachment from a PENDING booking.
  Future<Either<Failure, void>> deleteAttachment(
    String bookingId,
    String attachmentId,
  );

  /// Fetch workers near the booking location within [radiusKm].
  /// When [radiusKm] is omitted the backend runs its full expansion ladder.
  Future<Either<Failure, NearbyWorkersResult>> getNearbyWorkers(
    String bookingId, {
    double? radiusKm,
  });

  /// Assign a specific worker to a PENDING booking → transitions to ACCEPTED.
  Future<Either<Failure, BookingEntity>> assignWorker(
    String bookingId,
    String workerProfileId,
  );

  /// Client "Make Live Again" on an EXPIRED booking.
  Future<Either<Failure, BookingEntity>> relistBooking(String bookingId);

  // ── Worker lifecycle (assigned worker only) ─────────────────────────────

  /// ACCEPTED → EN_ROUTE.
  Future<Either<Failure, BookingEntity>> markOnMyWay(String bookingId);

  /// EN_ROUTE → ARRIVED.
  Future<Either<Failure, BookingEntity>> markArrived(String bookingId);

  /// ARRIVED → IN_PROGRESS.
  Future<Either<Failure, BookingEntity>> startJob(String bookingId);

  /// Completes an active job (backward compatible with older statuses).
  Future<Either<Failure, BookingEntity>> completeJobLifecycle(
    String bookingId,
  );

  /// Worker cancels before arrival — requires a reason.
  Future<Either<Failure, BookingEntity>> workerCancelBooking(
    String bookingId,
    String reason,
  );

  // ── Inspection report (INSPECTION lane) ─────────────────────────────────

  /// Assigned worker submits the inspection report + repair quote.
  Future<Either<Failure, InspectionReportEntity>> submitInspectionReport(
    String bookingId, {
    String? issueFound,
    String? recommendedRepair,
    required double labourCost,
    required bool partsNeeded,
    required List<InspectionReportPartDraft> parts,
    String? notes,
    required List<File> photos,
    File? voiceNoteFile,
    double? voiceNoteDurationSeconds,
  });

  /// Fetch the submitted report for a booking (client/assigned worker/admin).
  Future<Either<Failure, InspectionReportEntity>> getInspectionReport(
    String bookingId,
  );

  /// Client: "Accept Quote & Continue Repair".
  Future<Either<Failure, BookingEntity>> acceptInspectionQuote(
    String bookingId,
  );

  /// Client: "Close After Inspection" — booking completes at the inspection fee.
  Future<Either<Failure, BookingEntity>> closeAfterInspection(
    String bookingId,
  );
}
