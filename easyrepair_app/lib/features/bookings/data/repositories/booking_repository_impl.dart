import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/create_booking_request.dart';
import '../../domain/entities/update_booking_request.dart';
import '../../domain/entities/nearby_worker_entity.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/booking_remote_datasource.dart';

class BookingRepositoryImpl implements BookingRepository {
  final BookingRemoteDataSource _dataSource;

  const BookingRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, BookingEntity>> createBooking(
    CreateBookingRequest request,
  ) async {
    try {
      final model = await _dataSource.createBooking(request);
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<BookingEntity>>> getClientBookings() async {
    try {
      final models = await _dataSource.getClientBookings();
      return Right(models.map((m) => m.toEntity()).toList());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BookingEntity>> getBookingById(
    String bookingId,
  ) async {
    try {
      final model = await _dataSource.getBookingById(bookingId);
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BookingEntity>> updateBooking(
    UpdateBookingRequest request,
  ) async {
    try {
      final model = await _dataSource.updateBooking(request);
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BookingEntity>> cancelBooking(
    String bookingId,
  ) async {
    try {
      final model = await _dataSource.cancelBooking(bookingId);
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BookingEntity>> submitReview(
    ReviewRequest request,
  ) async {
    try {
      final model = await _dataSource.submitReview(request);
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BookingAttachmentEntity>> uploadAttachment(
    String bookingId,
    File file,
    String mimeType, {
    double? durationSeconds,
  }) async {
    try {
      final model = await _dataSource.uploadAttachment(
        bookingId,
        file,
        mimeType,
        durationSeconds: durationSeconds,
      );
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAttachment(
    String bookingId,
    String attachmentId,
  ) async {
    try {
      await _dataSource.deleteAttachment(bookingId, attachmentId);
      return const Right(null);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, NearbyWorkersResult>> getNearbyWorkers(
    String bookingId, {
    double? radiusKm,
  }) async {
    try {
      final model = await _dataSource.getNearbyWorkers(bookingId, radiusKm: radiusKm);
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BookingEntity>> assignWorker(
    String bookingId,
    String workerProfileId,
  ) async {
    try {
      final model = await _dataSource.assignWorker(bookingId, workerProfileId);
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BookingEntity>> relistBooking(
    String bookingId,
  ) async {
    try {
      final model = await _dataSource.relistBooking(bookingId);
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BookingEntity>> markOnMyWay(String bookingId) async {
    try {
      final model = await _dataSource.markOnMyWay(bookingId);
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BookingEntity>> markArrived(String bookingId) async {
    try {
      final model = await _dataSource.markArrived(bookingId);
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BookingEntity>> startJob(String bookingId) async {
    try {
      final model = await _dataSource.startJob(bookingId);
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BookingEntity>> completeJobLifecycle(
    String bookingId,
  ) async {
    try {
      final model = await _dataSource.completeJobLifecycle(bookingId);
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BookingEntity>> workerCancelBooking(
    String bookingId,
    String reason,
  ) async {
    try {
      final model = await _dataSource.workerCancelBooking(bookingId, reason);
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
