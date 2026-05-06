import '../../domain/entities/nearby_worker_entity.dart';

class NearbyWorkerModel {
  final String id;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final double rating;
  final int completedJobs;
  final double distanceKm;
  final List<String> skills;

  const NearbyWorkerModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    required this.rating,
    required this.completedJobs,
    required this.distanceKm,
    required this.skills,
  });

  factory NearbyWorkerModel.fromJson(Map<String, dynamic> json) {
    return NearbyWorkerModel(
      id: json['id'] as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      completedJobs: (json['completedJobs'] as num?)?.toInt() ?? 0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      skills: (json['skills'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  NearbyWorkerEntity toEntity() => NearbyWorkerEntity(
        id: id,
        firstName: firstName,
        lastName: lastName,
        avatarUrl: avatarUrl,
        rating: rating,
        completedJobs: completedJobs,
        distanceKm: distanceKm,
        skills: skills,
      );
}

class NearbyWorkersResultModel {
  final List<NearbyWorkerModel> workers;
  final double searchedRadiusKm;
  final int totalFound;
  final bool searchCompleted;

  const NearbyWorkersResultModel({
    required this.workers,
    required this.searchedRadiusKm,
    required this.totalFound,
    required this.searchCompleted,
  });

  factory NearbyWorkersResultModel.fromJson(Map<String, dynamic> json) {
    final workersJson = json['workers'] as List<dynamic>? ?? [];
    return NearbyWorkersResultModel(
      workers: workersJson
          .map((e) => NearbyWorkerModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      searchedRadiusKm:
          (json['searchedRadiusKm'] as num?)?.toDouble() ?? 0.0,
      totalFound: json['totalFound'] as int? ?? 0,
      searchCompleted: json['searchCompleted'] as bool? ?? false,
    );
  }

  NearbyWorkersResult toEntity() => NearbyWorkersResult(
        workers: workers.map((w) => w.toEntity()).toList(),
        searchedRadiusKm: searchedRadiusKm,
        totalFound: totalFound,
        searchCompleted: searchCompleted,
      );
}
