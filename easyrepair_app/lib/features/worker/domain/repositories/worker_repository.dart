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
import '../entities/earning_history_entity.dart';

abstract class WorkerRepository {
  Future<Either<Failure, WorkerProfileEntity>> getProfile();

  // ── Profile completion (Ustaad onboarding) ────────────────────────────
  Future<Either<Failure, void>> updateProfileCompletion({
    String? fullLegalName,
    String? residentialAddress,
    String? cnicNumber,
    String? fatherName,
    String? dateOfBirth,
    String? emergencyContact,
    int? experienceYears,
    bool? legalNameConfirmed,
  });

  Future<Either<Failure, String>> uploadCnicFront(File file);
  Future<Either<Failure, String>> uploadCnicBack(File file);
  Future<Either<Failure, String>> uploadLiveSelfie(File file);

  /// Seals the three acceptance records and submits the profile for review.
  /// [agreements] must carry exactly one evidence object per Ustaad document.
  Future<Either<Failure, List<AcceptedAgreementEntity>>> submitProfileForReview({
    required String submissionAttemptId,
    required List<AgreementEvidence> agreements,
  });

  /// All three agreements the worker must read, in [appLocale].
  Future<Either<Failure, List<AgreementTemplateEntity>>> getAgreementTemplates({
    required String appLocale,
  });

  /// The worker's own sealed acceptance records.
  Future<Either<Failure, List<AcceptedAgreementEntity>>> getMyAgreements();

  /// The accepted PDF bytes for one of the worker's own acceptances.
  Future<Either<Failure, List<int>>> downloadAgreementPdf(String acceptanceId);

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

  /// All-time completed-job earnings grouped by date (gross, newest first).
  Future<Either<Failure, List<EarningHistoryDayEntity>>> getEarningsHistory();
}
