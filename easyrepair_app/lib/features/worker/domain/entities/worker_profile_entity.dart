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

  String get label {
    switch (this) {
      case AvailabilityStatus.offline:
        return 'Offline';
      case AvailabilityStatus.online:
        return 'Online';
      case AvailabilityStatus.busy:
        return 'Busy';
    }
  }

  String get helperText {
    switch (this) {
      case AvailabilityStatus.offline:
        return 'You are hidden from clients';
      case AvailabilityStatus.online:
        return 'Clients near your location can see you';
      case AvailabilityStatus.busy:
        return 'You are currently working on a job';
    }
  }

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
  });

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
    );
  }
}
