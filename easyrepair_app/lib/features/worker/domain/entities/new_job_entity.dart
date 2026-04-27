import '../../../bookings/domain/entities/booking_entity.dart';

class NewJobCategoryEntity {
  final String id;
  final String name;
  final String? iconUrl;

  const NewJobCategoryEntity({
    required this.id,
    required this.name,
    this.iconUrl,
  });
}

class NewJobClientEntity {
  final String id;
  final String firstName;
  final String lastName;
  final String? avatarUrl;

  const NewJobClientEntity({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
  });

  String get fullName => '$firstName $lastName';
}

/// Represents a PENDING booking returned by GET /workers/jobs/new.
/// This is a lightweight view — not the full BookingEntity.
class NewJobEntity {
  final String id;
  final String? title;
  final String? description;
  final BookingStatus status;
  final BookingUrgency urgency;
  final TimeSlot? timeSlot;
  final String addressLine;
  final String city;
  final double latitude;
  final double longitude;
  final DateTime? scheduledAt;
  final DateTime createdAt;
  final NewJobCategoryEntity category;
  final NewJobClientEntity client;
  final int bidCount;
  final double? distanceKm;

  const NewJobEntity({
    required this.id,
    this.title,
    this.description,
    required this.status,
    required this.urgency,
    this.timeSlot,
    required this.addressLine,
    required this.city,
    required this.latitude,
    required this.longitude,
    this.scheduledAt,
    required this.createdAt,
    required this.category,
    required this.client,
    required this.bidCount,
    this.distanceKm,
  });

  String get displayTitle => title?.isNotEmpty == true ? title! : category.name;

  String get distanceLabel {
    if (distanceKm == null) return '';
    if (distanceKm! < 1) return '${(distanceKm! * 1000).round()} m away';
    return '${distanceKm!.toStringAsFixed(1)} km away';
  }
}
