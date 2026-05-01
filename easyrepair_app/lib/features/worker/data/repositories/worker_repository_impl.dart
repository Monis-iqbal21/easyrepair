import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/dio_failure_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../../domain/entities/worker_profile_entity.dart';
import '../../domain/entities/worker_skill_entity.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/new_job_entity.dart';
import '../../domain/entities/worker_review_entity.dart';
import '../../domain/repositories/worker_repository.dart';
import '../datasources/worker_remote_datasource.dart';

class WorkerRepositoryImpl implements WorkerRepository {
  final WorkerRemoteDatasource _datasource;

  const WorkerRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, WorkerProfileEntity>> getProfile() async {
    try {
      final model = await _datasource.getProfile();
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AvailabilityStatus>> updateAvailability({
    required AvailabilityStatus status,
    double? lat,
    double? lng,
  }) async {
    try {
      final data = await _datasource.updateAvailability(
        status: status.raw,
        lat: lat,
        lng: lng,
      );
      final raw = data['availabilityStatus'] as String? ?? 'OFFLINE';
      return Right(AvailabilityStatusX.fromRaw(raw));
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateLocationOnly({
    required double lat,
    required double lng,
  }) async {
    try {
      await _datasource.updateLocationOnly(lat: lat, lng: lng);
      return const Right(null);
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<WorkerSkillEntity>>> updateSkills(
    List<String> categoryIds,
  ) async {
    try {
      final models = await _datasource.updateSkills(categoryIds);
      return Right(models.map((m) => m.toEntity()).toList());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories() async {
    try {
      final models = await _datasource.getCategories();
      return Right(models.map((m) => m.toEntity()).toList());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<NewJobEntity>>> getNewJobs() async {
    try {
      final maps = await _datasource.getNewJobs();
      return Right(maps.map(_parseNewJob).toList());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  NewJobEntity _parseNewJob(Map<String, dynamic> j) {
    final cat = j['category'] as Map<String, dynamic>;
    final cli = j['client'] as Map<String, dynamic>;
    return NewJobEntity(
      id: j['id'] as String,
      title: j['title'] as String?,
      description: j['description'] as String?,
      status: BookingStatus.pending,
      urgency: (j['urgency'] as String?) == 'URGENT'
          ? BookingUrgency.urgent
          : BookingUrgency.normal,
      timeSlot: _parseTimeSlot(j['timeSlot'] as String?),
      addressLine: j['addressLine'] as String? ?? '',
      city: j['city'] as String? ?? '',
      latitude: (j['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (j['longitude'] as num?)?.toDouble() ?? 0,
      scheduledAt: j['scheduledAt'] != null
          ? DateTime.tryParse(j['scheduledAt'] as String)
          : null,
      createdAt: DateTime.parse(j['createdAt'] as String),
      category: NewJobCategoryEntity(
        id: cat['id'] as String,
        name: cat['name'] as String,
        iconUrl: cat['iconUrl'] as String?,
      ),
      client: NewJobClientEntity(
        id: cli['id'] as String,
        firstName: cli['firstName'] as String,
        lastName: cli['lastName'] as String,
        avatarUrl: cli['avatarUrl'] as String?,
      ),
      bidCount: (j['bidCount'] as num?)?.toInt() ?? 0,
      distanceKm: (j['distanceKm'] as num?)?.toDouble(),
      hasMyBid: j['hasMyBid'] as bool? ?? false,
      workerProfileId: j['workerProfileId'] as String?,
    );
  }

  TimeSlot? _parseTimeSlot(String? raw) {
    if (raw == null) return null;
    return switch (raw.toUpperCase()) {
      'MORNING' => TimeSlot.morning,
      'AFTERNOON' => TimeSlot.afternoon,
      'EVENING' => TimeSlot.evening,
      'NIGHT' => TimeSlot.night,
      _ => null,
    };
  }

  @override
  Future<Either<Failure, List<BookingEntity>>> getWorkerJobs(
    String? statusFilter,
  ) async {
    try {
      final models = await _datasource.getWorkerJobs(statusFilter);
      return Right(models.map((m) => m.toEntity()).toList());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BookingEntity>> getWorkerJobById(
    String bookingId,
  ) async {
    try {
      final model = await _datasource.getWorkerJobById(bookingId);
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BookingEntity>> completeWorkerJob(
    String bookingId,
  ) async {
    try {
      final model = await _datasource.completeWorkerJob(bookingId);
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<WorkerReviewEntity>>> getWorkerReviews({
    int? limit,
  }) async {
    try {
      final models = await _datasource.getWorkerReviews(limit: limit);
      return Right(models.map((m) => m.toEntity()).toList());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, WorkerReviewSummaryEntity>>
      getWorkerReviewSummary() async {
    try {
      final model = await _datasource.getWorkerReviewSummary();
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}

final workerRepositoryProvider = Provider<WorkerRepository>((ref) {
  return WorkerRepositoryImpl(ref.watch(workerRemoteDatasourceProvider));
});
