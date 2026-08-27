import 'worker_skill_entity.dart';
import 'ongoing_job_entity.dart';
import 'worker_stats_entity.dart';

enum AvailabilityStatus { offline, online, busy }

extension AvailabilityStatusX on AvailabilityStatus {
  String get raw {
    switch (this) {
      case AvailabilityStatus.offline:
        return 'OFFLINE';
      case AvailabilityStatus.online:
        return 'ONLINE';
      case AvailabilityStatus.busy:
        return 'BUSY';
    }
  }

  // Display wording lives in presentation/utils/worker_labels.dart —
  // availabilityLabel() and availabilityHelper(). The enum and its raw API
  // value are untouched.

  static AvailabilityStatus fromRaw(String raw) {
    switch (raw.toUpperCase()) {
      case 'ONLINE':
        return AvailabilityStatus.online;
      case 'BUSY':
        return AvailabilityStatus.busy;
      default:
        return AvailabilityStatus.offline;
    }
  }
}

class WorkerProfileEntity {
  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String? bio;
  final String status;
  final String verificationStatus;
  final AvailabilityStatus availabilityStatus;
  final bool currentlyWorking;
  final double? currentLat;
  final double? currentLng;
  final double rating;
  final int totalRatings;
  final List<WorkerSkillEntity> skills;
  final WorkerStatsEntity stats;
  final OngoingJobEntity? ongoingJob;

  // ── Ustaad onboarding / profile completion ─────────────────────────────
  final String? fullLegalName;
  final String? residentialAddress;
  final String? cnicNumber;
  /// Father's name as per CNIC — required by the EVS Consent document.
  final String? fatherName;
  /// Date of birth as per CNIC, kept as the ISO calendar date (yyyy-MM-dd)
  /// the Ustaad entered so no timezone can shift it by a day.
  final String? dateOfBirth;
  /// Optional "Name, +92…" — the EVS document prints a controlled
  /// "Not applicable" when it is absent.
  final String? emergencyContact;
  final String? cnicFrontUrl;
  final String? cnicBackUrl;
  final String? liveSelfieUrl;
  final String faceMatchStatus;
  final String trainingStatus;
  final String onboardingStatus;
  final DateTime? legalNameConfirmedAt;
  final DateTime? generalAgreementAcceptedAt;
  final DateTime? tradeAgreementAcceptedAt;
  final String? generalAgreementVersion;
  final String? tradeAgreementVersion;
  final DateTime? submittedForReviewAt;
  final String? changesRequiredReason;
  final String? rejectionReason;

  const WorkerProfileEntity({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.bio,
    required this.status,
    required this.verificationStatus,
    required this.availabilityStatus,
    this.currentlyWorking = false,
    this.currentLat,
    this.currentLng,
    required this.rating,
    required this.totalRatings,
    required this.skills,
    required this.stats,
    this.ongoingJob,
    this.fullLegalName,
    this.residentialAddress,
    this.cnicNumber,
    this.fatherName,
    this.dateOfBirth,
    this.emergencyContact,
    this.cnicFrontUrl,
    this.cnicBackUrl,
    this.liveSelfieUrl,
    this.faceMatchStatus = 'PENDING',
    this.trainingStatus = 'NOT_STARTED',
    this.onboardingStatus = 'DRAFT',
    this.legalNameConfirmedAt,
    this.generalAgreementAcceptedAt,
    this.tradeAgreementAcceptedAt,
    this.generalAgreementVersion,
    this.tradeAgreementVersion,
    this.submittedForReviewAt,
    this.changesRequiredReason,
    this.rejectionReason,
  });

  /// The single gate for hireability — go online, matching, bidding, hire.
  // ── Onboarding state ──────────────────────────────────────────────────
  //
  // The UI needs three different answers from `onboardingStatus`, and asking
  // `!isOnboardingApproved` conflates all of them: an Ustaad who has just
  // submitted is blocked from work for a completely different reason than one
  // who never finished their forms, and must not be told to go and fill them
  // in again. These getters are the single place those distinctions live.

  /// Still owes us something: never finished registration, or an admin sent
  /// the profile back. This is the only state that should offer a form.
  bool get needsProfileAction =>
      onboardingStatus == 'DRAFT' || onboardingStatus == 'CHANGES_REQUIRED';

  /// Submitted and waiting on an admin. Blocked from work, but there is
  /// nothing left for the Ustaad to do — and nothing left to edit, since the
  /// backend only accepts profile changes while DRAFT or CHANGES_REQUIRED.
  bool get isPendingReview => onboardingStatus == 'SUBMITTED_FOR_REVIEW';

  bool get isOnboardingRejected => onboardingStatus == 'REJECTED';

  bool get isOnboardingApproved => onboardingStatus == 'APPROVED';

  /// True when the profile already carries everything the 4-step registration
  /// collects BEFORE Step 4, so an unfinished registration can be resumed at
  /// its last step instead of being restarted in the legacy full form.
  ///
  /// Deliberately conservative: a legacy DRAFT profile that predates the new
  /// flow will be missing at least one of these and correctly falls back.
  ///
  /// This is precisely the set `submitProfileForReview` requires MINUS what
  /// Step 4 itself collects (CNIC front/back, live selfie, agreements). Every
  /// entry here is one Step 4 has no input for, so resuming there with any of
  /// them absent would strand the Ustaad in a loop: Worker Home → Step 4 →
  /// submit rejected with MISSING_PROFILE_DATA → Worker Home. Anything this
  /// returns false for goes to the legacy form, which can fix all of it.
  bool get hasRegistrationProfileData =>
      (fullLegalName?.trim().isNotEmpty ?? false) &&
      (fatherName?.trim().isNotEmpty ?? false) &&
      (dateOfBirth?.trim().isNotEmpty ?? false) &&
      (cnicNumber?.trim().isNotEmpty ?? false) &&
      (residentialAddress?.trim().isNotEmpty ?? false) &&
      legalNameConfirmedAt != null &&
      // Exactly one — the backend's own definition of a complete main skill,
      // and what `profileCompleted` mirrors.
      skills.length == 1;

  WorkerProfileEntity copyWith({
    AvailabilityStatus? availabilityStatus,
    bool? currentlyWorking,
    double? currentLat,
    double? currentLng,
    List<WorkerSkillEntity>? skills,
    OngoingJobEntity? ongoingJob,
    bool clearOngoingJob = false,
  }) {
    return WorkerProfileEntity(
      id: id,
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      avatarUrl: avatarUrl,
      bio: bio,
      status: status,
      verificationStatus: verificationStatus,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      currentlyWorking: currentlyWorking ?? this.currentlyWorking,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      rating: rating,
      totalRatings: totalRatings,
      skills: skills ?? this.skills,
      stats: stats,
      ongoingJob: clearOngoingJob ? null : (ongoingJob ?? this.ongoingJob),
      fullLegalName: fullLegalName,
      residentialAddress: residentialAddress,
      cnicNumber: cnicNumber,
      fatherName: fatherName,
      dateOfBirth: dateOfBirth,
      emergencyContact: emergencyContact,
      cnicFrontUrl: cnicFrontUrl,
      cnicBackUrl: cnicBackUrl,
      liveSelfieUrl: liveSelfieUrl,
      faceMatchStatus: faceMatchStatus,
      trainingStatus: trainingStatus,
      onboardingStatus: onboardingStatus,
      legalNameConfirmedAt: legalNameConfirmedAt,
      generalAgreementAcceptedAt: generalAgreementAcceptedAt,
      tradeAgreementAcceptedAt: tradeAgreementAcceptedAt,
      generalAgreementVersion: generalAgreementVersion,
      tradeAgreementVersion: tradeAgreementVersion,
      submittedForReviewAt: submittedForReviewAt,
      changesRequiredReason: changesRequiredReason,
      rejectionReason: rejectionReason,
    );
  }
}
