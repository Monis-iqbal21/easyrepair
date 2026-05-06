import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/booking_entity.dart';
import '../entities/create_booking_request.dart';
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
  Future<Either<Failure, BookingEntity>> cancelBooking(String bookingId);

  /// Submit a review for a completed booking.
  Future<Either<Failure, BookingEntity>> submitReview(ReviewRequest request);

  /// Upload a file attachment to an existing PENDING booking.
  Future<Either<Failure, BookingAttachmentEntity>> uploadAttachment(
    String bookingId,
    File file,
    String mimeType,
  );

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
}
