import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/data/cached_result.dart';
import '../../../../core/errors/failures.dart';
import '../entities/attachable_inspection_entity.dart';
import '../entities/booking_entity.dart';
import '../entities/create_booking_request.dart';
import '../entities/inspection_report_entity.dart';
import '../entities/nearby_worker_entity.dart';
import '../entities/update_booking_request.dart';

abstract class BookingRepository {
  /// Fetch all bookings for the currently authenticated client. Falls back
  /// to the last cached list (`CachedResult.isStale == true`) when the live
  /// request fails and something was cached.
  Future<Either<Failure, CachedResult<List<BookingEntity>>>> getClientBookings();

  /// Fetch a single booking by id. Falls back to cache on failure — see
  /// [getClientBookings].
  Future<Either<Failure, CachedResult<BookingEntity>>> getBookingById(
    String bookingId,
  );

  /// Completed bookings this client still owes a review for.
  ///
  /// Backend truth for "a review is pending" — the app never relies on an
  /// in-memory notification callback, so a missed completion push can never
  /// permanently lose the prompt. A booking leaves this list only once its
  /// review actually exists.
  Future<Either<Failure, List<BookingEntity>>> getPendingReviews();

  /// Create a new service request / booking.
  /// The client's own previously completed inspections whose report may be
  /// attached to a new bidding job. Never cached — see the datasource note.
  Future<Either<Failure, List<AttachableInspectionEntity>>>
      getAttachableInspections({String? categoryId});

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

  /// Client reopens a booking after the worker cancelled it, to find/hire
  /// another worker — excludes the cancelling worker.
  Future<Either<Failure, BookingEntity>> reopenAfterWorkerCancellation(
    String bookingId,
  );

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

  /// Client: "Find Other Ustaad" — pays only the inspection fee, preserves
  /// the report/quote/inspecting worker, reopens the booking for bidding.
  Future<Either<Failure, BookingEntity>> findOtherUstaad(
    String bookingId,
  );

  /// Client: re-hires the original inspecting worker after "Find Other
  /// Ustaad", using their already-submitted quote.
  Future<Either<Failure, BookingEntity>> hireInspectingWorker(
    String bookingId,
  );
}
