class NearbyWorkerEntity {
  final String id;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final double rating;
  final int completedJobs;
  final int reviewsCount;
  final int cancellationRate;
  final double distanceKm;
  final List<String> skills;
  final bool recommended;

  /// Admin-confirmed CNIC-photo-vs-live-selfie match, computed server-side.
  /// Never inferred in the UI from status or profile completeness.
  final bool cnicVerified;

  /// Years on the skill matching this booking's category; null when the
  /// worker has none recorded. Never a sum across skills.
  final int? relevantExperienceYears;

  const NearbyWorkerEntity({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    required this.rating,
    required this.completedJobs,
    this.reviewsCount = 0,
    this.cancellationRate = 0,
    required this.distanceKm,
    required this.skills,
    this.recommended = false,
    this.cnicVerified = false,
    this.relevantExperienceYears,
  });

  String get fullName => '$firstName $lastName';

  String get initials =>
      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
          .toUpperCase();

  // Rating and distance labels are built in the presentation layer by
  // bookings/presentation/utils/worker_labels.dart — the wording depends on
  // the selected language, the raw numbers above do not.


  // The level badge is built in the presentation layer by
  // presentation/utils/booking_labels.dart — completedJobs above is the input.
}

/// Wraps the nearby-workers list together with search metadata returned by
/// the progressive radius expansion algorithm.
class NearbyWorkersResult {
  final List<NearbyWorkerEntity> workers;

  /// The largest radius that was searched before the target pool was reached.
  final double searchedRadiusKm;

  /// Total unique workers returned.
  final int totalFound;

  /// True when the pool hit the TARGET_POOL size before exhausting the ladder.
  final bool searchCompleted;

  const NearbyWorkersResult({
    required this.workers,
    required this.searchedRadiusKm,
    required this.totalFound,
    required this.searchCompleted,
  });

  // A radius label, if one is ever shown, belongs in the presentation layer:
  // searchedRadiusKm above is the input.
}
