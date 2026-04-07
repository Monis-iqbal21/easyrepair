class NearbyWorkerEntity {
  final String id;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final double rating;
  final int completedJobs;
  final double distanceKm;
  final List<String> skills;

  const NearbyWorkerEntity({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    required this.rating,
    required this.completedJobs,
    required this.distanceKm,
    required this.skills,
  });

  String get fullName => '$firstName $lastName';

  String get initials =>
      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
          .toUpperCase();

  /// e.g. "4.6/5 (12 jobs)" or "No ratings yet"
  String get ratingLabel {
    if (completedJobs == 0) return 'New worker';
    final rStr = rating > 0 ? '${rating.toStringAsFixed(1)}/5' : 'No rating';
    return '$rStr ($completedJobs ${completedJobs == 1 ? 'job' : 'jobs'})';
  }

  /// e.g. "1.8 km away" or "< 1 km away"
  String get distanceLabel {
    if (distanceKm < 1) return '< 1 km away';
    return '${distanceKm.toStringAsFixed(1)} km away';
  }
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

  /// e.g. "Searched within 5 km" or "Searched up to 20 km"
  String get radiusLabel => 'within ${searchedRadiusKm.toStringAsFixed(0)} km';
}
