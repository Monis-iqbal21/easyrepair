import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../entities/worker_profile_entity.dart';
import '../entities/worker_skill_entity.dart';
import '../entities/category_entity.dart';
import '../entities/new_job_entity.dart';
import '../entities/worker_review_entity.dart';
import '../entities/agreement_template_entity.dart';

abstract class WorkerRepository {
  Future<Either<Failure, WorkerProfileEntity>> getProfile();

  // ── Profile completion (Ustaad onboarding) ────────────────────────────
  Future<Either<Failure, void>> updateProfileCompletion({
    String? fullLegalName,
    String? residentialAddress,
    String? cnicNumber,
    int? experienceYears,
    bool? legalNameConfirmed,
    bool? generalAgreementAccepted,
    bool? tradeAgreementAccepted,
  });

  Future<Either<Failure, String>> uploadCnicFront(File file);
  Future<Either<Failure, String>> uploadCnicBack(File file);
  Future<Either<Failure, String>> uploadLiveSelfie(File file);
  Future<Either<Failure, void>> submitProfileForReview();

  /// Exact text/version of the agreements the worker is about to accept.
  Future<Either<Failure, List<AgreementTemplateEntity>>> getAgreementTemplates();

  Future<Either<Failure, AvailabilityStatus>> updateAvailability({
    required AvailabilityStatus status,
    double? lat,
    double? lng,
  });

  /// Location-only ping — never changes availabilityStatus.
  Future<Either<Failure, void>> updateLocationOnly({
    required double lat,
    required double lng,
  });

  Future<Either<Failure, List<WorkerSkillEntity>>> updateSkills(
    List<String> categoryIds,
  );

  Future<Either<Failure, List<CategoryEntity>>> getCategories();

  Future<Either<Failure, List<NewJobEntity>>> getNewJobs();

  Future<Either<Failure, List<BookingEntity>>> getWorkerJobs(
    String? statusFilter,
  );

  Future<Either<Failure, BookingEntity>> getWorkerJobById(String bookingId);

  Future<Either<Failure, BookingEntity>> completeWorkerJob(String bookingId);

  /// Returns reviews for this worker's completed bookings, latest first.
  /// Pass [limit] to cap the result (e.g. 2 for the dashboard preview).
  Future<Either<Failure, List<WorkerReviewEntity>>> getWorkerReviews({
    int? limit,
  });

  /// Returns aggregate rating stats (average + total count).
  Future<Either<Failure, WorkerReviewSummaryEntity>> getWorkerReviewSummary();
}
