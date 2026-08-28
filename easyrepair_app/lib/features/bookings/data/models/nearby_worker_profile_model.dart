import '../../domain/entities/nearby_worker_profile_entity.dart';

class NearbyWorkerProfileModel {
  final String workerProfileId;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String? phone;
  final double averageRating;
  final int totalReviews;
  final int completedJobs;
  final bool cnicVerified;
  final int? relevantExperienceYears;
  final List<NearbyWorkerSkillModel> skills;
  final List<NearbyWorkerReviewModel> reviews;

  const NearbyWorkerProfileModel({
    required this.workerProfileId,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.phone,
    required this.averageRating,
    required this.totalReviews,
    required this.completedJobs,
    required this.cnicVerified,
    this.relevantExperienceYears,
    required this.skills,
    required this.reviews,
  });

  factory NearbyWorkerProfileModel.fromJson(Map<String, dynamic> json) {
    return NearbyWorkerProfileModel(
      workerProfileId: json['workerProfileId'] as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      phone: json['phone'] as String?,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: (json['totalReviews'] as num?)?.toInt() ?? 0,
      completedJobs: (json['completedJobs'] as num?)?.toInt() ?? 0,
      // Absent is NOT verified — a missing flag must never read as a badge.
      cnicVerified: json['cnicVerified'] as bool? ?? false,
      relevantExperienceYears: (json['relevantExperienceYears'] as num?)
          ?.toInt(),
      skills:
          (json['skills'] as List<dynamic>?)
              ?.map(
                (e) => NearbyWorkerSkillModel.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          const [],
      reviews:
          (json['reviews'] as List<dynamic>?)
              ?.map(
                (e) => NearbyWorkerReviewModel.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          const [],
    );
  }

  NearbyWorkerProfileEntity toEntity() => NearbyWorkerProfileEntity(
    workerProfileId: workerProfileId,
    firstName: firstName,
    lastName: lastName,
    avatarUrl: avatarUrl,
    phone: phone,
    averageRating: averageRating,
    totalReviews: totalReviews,
    completedJobs: completedJobs,
    cnicVerified: cnicVerified,
    relevantExperienceYears: relevantExperienceYears,
    skills: skills.map((s) => s.toEntity()).toList(),
    reviews: reviews.map((r) => r.toEntity()).toList(),
  );
}

class NearbyWorkerSkillModel {
  final String name;
  final int yearsExperience;

  const NearbyWorkerSkillModel({
    required this.name,
    required this.yearsExperience,
  });

  factory NearbyWorkerSkillModel.fromJson(Map<String, dynamic> json) {
    return NearbyWorkerSkillModel(
      name: json['name'] as String? ?? '',
      yearsExperience: (json['yearsExperience'] as num?)?.toInt() ?? 0,
    );
  }

  NearbyWorkerSkillEntity toEntity() =>
      NearbyWorkerSkillEntity(name: name, yearsExperience: yearsExperience);
}

class NearbyWorkerReviewModel {
  final String id;
  final int rating;
  final String? comment;
  final String? reviewerName;
  final String serviceCategory;
  final DateTime createdAt;

  const NearbyWorkerReviewModel({
    required this.id,
    required this.rating,
    this.comment,
    this.reviewerName,
    required this.serviceCategory,
    required this.createdAt,
  });

  factory NearbyWorkerReviewModel.fromJson(Map<String, dynamic> json) {
    return NearbyWorkerReviewModel(
      id: json['id'] as String,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment'] as String?,
      reviewerName: json['reviewerName'] as String?,
      serviceCategory: json['serviceCategory'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  NearbyWorkerReviewEntity toEntity() => NearbyWorkerReviewEntity(
    id: id,
    rating: rating,
    comment: comment,
    reviewerName: reviewerName,
    serviceCategory: serviceCategory,
    createdAt: createdAt,
  );
}
