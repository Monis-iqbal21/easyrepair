import '../../domain/entities/bid_entity.dart';
import '../../domain/repositories/bid_repository.dart';

class BidModel {
  final String id;
  final String bookingId;
  final String workerProfileId;
  final double amount;
  final String? message;
  final String status;
  final int editCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BidModel({
    required this.id,
    required this.bookingId,
    required this.workerProfileId,
    required this.amount,
    this.message,
    required this.status,
    required this.editCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BidModel.fromJson(Map<String, dynamic> json) {
    return BidModel(
      id: json['id'] as String,
      bookingId: json['bookingId'] as String,
      workerProfileId: json['workerProfileId'] as String,
      amount: (json['amount'] as num).toDouble(),
      message: json['message'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      editCount: json['editCount'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  BidEntity toEntity() => BidEntity(
        id: id,
        bookingId: bookingId,
        workerProfileId: workerProfileId,
        amount: amount,
        message: message,
        status: BidStatusX.fromRaw(status),
        editCount: editCount,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

class BidWithWorkerModel {
  final BidModel bid;
  final String workerProfileId;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final double rating;
  final int completedJobs;
  final double distanceKm;
  final List<String> skills;

  const BidWithWorkerModel({
    required this.bid,
    required this.workerProfileId,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    required this.rating,
    required this.completedJobs,
    required this.distanceKm,
    required this.skills,
  });

  factory BidWithWorkerModel.fromJson(Map<String, dynamic> json) {
    final bidJson = json['bid'] as Map<String, dynamic>? ?? json;
    final workerJson = json['worker'] as Map<String, dynamic>? ?? {};

    return BidWithWorkerModel(
      bid: BidModel.fromJson(bidJson),
      workerProfileId: json['workerProfileId'] as String? ??
          workerJson['id'] as String? ??
          bidJson['workerProfileId'] as String,
      firstName: workerJson['firstName'] as String? ?? '',
      lastName: workerJson['lastName'] as String? ?? '',
      avatarUrl: workerJson['avatarUrl'] as String?,
      rating: (workerJson['rating'] as num?)?.toDouble() ?? 0.0,
      completedJobs: (workerJson['completedJobs'] as num?)?.toInt() ?? 0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      skills: (workerJson['skills'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  BidWithWorkerEntity toEntity() => BidWithWorkerEntity(
        bid: bid.toEntity(),
        workerProfileId: workerProfileId,
        firstName: firstName,
        lastName: lastName,
        avatarUrl: avatarUrl,
        rating: rating,
        completedJobs: completedJobs,
        distanceKm: distanceKm,
        skills: skills,
      );
}
