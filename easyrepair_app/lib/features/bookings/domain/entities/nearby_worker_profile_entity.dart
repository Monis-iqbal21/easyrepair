/// One Ustaad's public profile, as shown in the Standard/Inspection
/// worker-selection modal.
///
/// Everything here comes from
/// `GET /bookings/:id/nearby-workers/:workerProfileId/profile`, which is
/// deliberately narrow: no CNIC number, no CNIC/selfie images, no address,
/// no date of birth. If a field is not on this entity, the client is not
/// meant to see it.
class NearbyWorkerProfileEntity {
  final String workerProfileId;
  final String firstName;
  final String lastName;
  final String? avatarUrl;

  /// The Ustaad's contact number. Null when the backend has none on file.
  final String? phone;

  final double averageRating;
  final int totalReviews;
  final int completedJobs;

  /// True only when an admin has matched this Ustaad's CNIC photos against
  /// their live selfie. Computed server-side — never inferred in the UI.
  final bool cnicVerified;

  /// Years of experience on the skill matching THIS booking's category.
  /// Null when the worker has none recorded for it.
  final int? relevantExperienceYears;

  final List<NearbyWorkerSkillEntity> skills;

  /// The latest 5 reviews at most, newest first. Empty when there are none.
  final List<NearbyWorkerReviewEntity> reviews;

  const NearbyWorkerProfileEntity({
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

  String get fullName => '$firstName $lastName';

  String get initials =>
      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
          .toUpperCase();
}

class NearbyWorkerSkillEntity {
  final String name;
  final int yearsExperience;

  const NearbyWorkerSkillEntity({
    required this.name,
    required this.yearsExperience,
  });
}

class NearbyWorkerReviewEntity {
  final String id;
  final int rating;
  final String? comment;

  /// The reviewer's display name, or null when it is not available.
  final String? reviewerName;
  final String serviceCategory;
  final DateTime createdAt;

  const NearbyWorkerReviewEntity({
    required this.id,
    required this.rating,
    this.comment,
    this.reviewerName,
    required this.serviceCategory,
    required this.createdAt,
  });
}
