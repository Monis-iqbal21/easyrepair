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

  const WorkerStatsModel({required this.completedJobs, required this.activeJobs});

  factory WorkerStatsModel.fromJson(Map<String, dynamic> json) {
    return WorkerStatsModel(
      completedJobs: json['completedJobs'] as int? ?? 0,
      activeJobs: json['activeJobs'] as int? ?? 0,
    );
  }

  WorkerStatsEntity toEntity() {
    return WorkerStatsEntity(completedJobs: completedJobs, activeJobs: activeJobs);
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
