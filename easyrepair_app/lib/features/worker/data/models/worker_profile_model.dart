import '../../domain/entities/worker_profile_entity.dart';
import '../../domain/entities/worker_skill_entity.dart';
import '../../domain/entities/worker_stats_entity.dart';
import '../../domain/entities/ongoing_job_entity.dart';

class WorkerProfileModel {
  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String? bio;
  final String status;
  final String verificationStatus;
  final String availabilityStatus;
  final bool currentlyWorking;
  final double? currentLat;
  final double? currentLng;
  final double rating;
  final int totalRatings;
  final List<WorkerSkillModel> skills;
  final WorkerStatsModel stats;
  final OngoingJobModel? ongoingJob;

  // ── Ustaad onboarding / profile completion ─────────────────────────────
  final String? fullLegalName;
  final String? residentialAddress;
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

  const WorkerProfileModel({
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

  factory WorkerProfileModel.fromJson(Map<String, dynamic> json) {
    return WorkerProfileModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      status: json['status'] as String,
      verificationStatus: json['verificationStatus'] as String,
      availabilityStatus: json['availabilityStatus'] as String? ?? 'OFFLINE',
      currentlyWorking: json['currentlyWorking'] as bool? ?? false,
      currentLat: (json['currentLat'] as num?)?.toDouble(),
      currentLng: (json['currentLng'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: json['totalRatings'] as int? ?? 0,
      skills: (json['skills'] as List<dynamic>?)
              ?.map((e) => WorkerSkillModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      stats: WorkerStatsModel.fromJson(json['stats'] as Map<String, dynamic>? ?? {}),
      ongoingJob: json['ongoingJob'] != null
          ? OngoingJobModel.fromJson(json['ongoingJob'] as Map<String, dynamic>)
          : null,
      fullLegalName: json['fullLegalName'] as String?,
      residentialAddress: json['residentialAddress'] as String?,
      cnicFrontUrl: json['cnicFrontUrl'] as String?,
      cnicBackUrl: json['cnicBackUrl'] as String?,
      liveSelfieUrl: json['liveSelfieUrl'] as String?,
      faceMatchStatus: json['faceMatchStatus'] as String? ?? 'PENDING',
      trainingStatus: json['trainingStatus'] as String? ?? 'NOT_STARTED',
      onboardingStatus: json['onboardingStatus'] as String? ?? 'DRAFT',
      legalNameConfirmedAt: json['legalNameConfirmedAt'] != null
          ? DateTime.tryParse(json['legalNameConfirmedAt'] as String)
          : null,
      generalAgreementAcceptedAt: json['generalAgreementAcceptedAt'] != null
          ? DateTime.tryParse(json['generalAgreementAcceptedAt'] as String)
          : null,
      tradeAgreementAcceptedAt: json['tradeAgreementAcceptedAt'] != null
          ? DateTime.tryParse(json['tradeAgreementAcceptedAt'] as String)
          : null,
      generalAgreementVersion: json['generalAgreementVersion'] as String?,
      tradeAgreementVersion: json['tradeAgreementVersion'] as String?,
      submittedForReviewAt: json['submittedForReviewAt'] != null
          ? DateTime.tryParse(json['submittedForReviewAt'] as String)
          : null,
      changesRequiredReason: json['changesRequiredReason'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
    );
  }

  WorkerProfileEntity toEntity() {
    return WorkerProfileEntity(
      id: id,
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      avatarUrl: avatarUrl,
      bio: bio,
      status: status,
      verificationStatus: verificationStatus,
      availabilityStatus: AvailabilityStatusX.fromRaw(availabilityStatus),
      currentlyWorking: currentlyWorking,
      currentLat: currentLat,
      currentLng: currentLng,
      rating: rating,
      totalRatings: totalRatings,
      skills: skills.map((s) => s.toEntity()).toList(),
      stats: stats.toEntity(),
      ongoingJob: ongoingJob?.toEntity(),
      fullLegalName: fullLegalName,
      residentialAddress: residentialAddress,
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

class WorkerSkillModel {
  final String id;
  final int yearsExperience;
  final WorkerCategoryModel category;

  const WorkerSkillModel({
    required this.id,
    required this.yearsExperience,
    required this.category,
  });

  factory WorkerSkillModel.fromJson(Map<String, dynamic> json) {
    return WorkerSkillModel(
      id: json['id'] as String,
      yearsExperience: json['yearsExperience'] as int? ?? 0,
      category: WorkerCategoryModel.fromJson(json['category'] as Map<String, dynamic>),
    );
  }

  WorkerSkillEntity toEntity() {
    return WorkerSkillEntity(
      id: id,
      categoryId: category.id,
      categoryName: category.name,
      categoryIconUrl: category.iconUrl,
      yearsExperience: yearsExperience,
    );
  }
}

class WorkerCategoryModel {
  final String id;
  final String name;
  final String? iconUrl;

  const WorkerCategoryModel({
    required this.id,
    required this.name,
    this.iconUrl,
  });

  factory WorkerCategoryModel.fromJson(Map<String, dynamic> json) {
    return WorkerCategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      iconUrl: json['iconUrl'] as String?,
    );
  }
}

class WorkerStatsModel {
  final int completedJobs;
  final int activeJobs;
  final double todayEarnings;
  final int cancellationRate;
  final int? avgResponseMinutes;
  final String? responseLabel;

  const WorkerStatsModel({
    required this.completedJobs,
    required this.activeJobs,
    this.todayEarnings = 0,
    this.cancellationRate = 0,
    this.avgResponseMinutes,
    this.responseLabel,
  });

  factory WorkerStatsModel.fromJson(Map<String, dynamic> json) {
    return WorkerStatsModel(
      completedJobs: json['completedJobs'] as int? ?? 0,
      activeJobs: json['activeJobs'] as int? ?? 0,
      todayEarnings: (json['todayEarnings'] as num?)?.toDouble() ?? 0,
      cancellationRate: json['cancellationRate'] as int? ?? 0,
      avgResponseMinutes: json['avgResponseMinutes'] as int?,
      responseLabel: json['responseLabel'] as String?,
    );
  }

  WorkerStatsEntity toEntity() {
    return WorkerStatsEntity(
      completedJobs: completedJobs,
      activeJobs: activeJobs,
      todayEarnings: todayEarnings,
      cancellationRate: cancellationRate,
      avgResponseMinutes: avgResponseMinutes,
      responseLabel: responseLabel,
    );
  }
}

class OngoingJobModel {
  final String id;
  final String? title;
  final String categoryName;
  final String clientArea;
  final String addressLine;
  final String status;

  const OngoingJobModel({
    required this.id,
    this.title,
    required this.categoryName,
    required this.clientArea,
    required this.addressLine,
    required this.status,
  });

  factory OngoingJobModel.fromJson(Map<String, dynamic> json) {
    return OngoingJobModel(
      id: json['id'] as String,
      title: json['title'] as String?,
      categoryName: json['categoryName'] as String,
      clientArea: json['clientArea'] as String,
      addressLine: json['addressLine'] as String? ?? '',
      status: json['status'] as String,
    );
  }

  OngoingJobEntity toEntity() {
    return OngoingJobEntity(
      id: id,
      title: title,
      categoryName: categoryName,
      clientArea: clientArea,
      addressLine: addressLine,
      status: status,
    );
  }
}
