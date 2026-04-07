import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../entities/worker_profile_entity.dart';
import '../entities/worker_skill_entity.dart';
import '../entities/category_entity.dart';

abstract class WorkerRepository {
  Future<Either<Failure, WorkerProfileEntity>> getProfile();

  Future<Either<Failure, AvailabilityStatus>> updateAvailability({
    required AvailabilityStatus status,
    double? lat,
    double? lng,
  });

  Future<Either<Failure, List<WorkerSkillEntity>>> updateSkills(
    List<String> categoryIds,
  );

  Future<Either<Failure, List<CategoryEntity>>> getCategories();

  Future<Either<Failure, List<BookingEntity>>> getWorkerJobs(
    String? statusFilter,
  );

  Future<Either<Failure, BookingEntity>> getWorkerJobById(String bookingId);

  Future<Either<Failure, BookingEntity>> completeWorkerJob(String bookingId);
}
