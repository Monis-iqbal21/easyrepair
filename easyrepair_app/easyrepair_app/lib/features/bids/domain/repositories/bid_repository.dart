import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/bid_entity.dart';

abstract class BidRepository {
  /// Submit a new bid on a booking.
  Future<Either<Failure, BidEntity>> submitBid({
    required String bookingId,
    required double amount,
    String? message,
  });

  /// Edit an existing bid (only once — editCount must be 0).
  Future<Either<Failure, BidEntity>> editBid({
    required String bidId,
    required double amount,
    String? message,
  });

  /// Fetch the worker's own bid for a booking (null if not yet submitted).
  Future<Either<Failure, BidEntity?>> getMyBid(String bookingId);

  /// Fetch all bids for a booking (client-facing).
  Future<Either<Failure, List<BidWithWorkerEntity>>> getBidsForBooking(
    String bookingId,
  );

  /// Accept a bid (client hires a worker via their bid).
  Future<Either<Failure, BidEntity>> acceptBid(String bidId);
}

/// A bid together with the submitting worker's public profile info.
class BidWithWorkerEntity {
  final BidEntity bid;
  final String workerProfileId;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final double rating;
  final int completedJobs;
  final double distanceKm;
  final List<String> skills;
  final double? currentLat;
  final double? currentLng;
  final DateTime? locationUpdatedAt;

  const BidWithWorkerEntity({
    required this.bid,
    required this.workerProfileId,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    required this.rating,
    required this.completedJobs,
    required this.distanceKm,
    required this.skills,
    this.currentLat,
    this.currentLng,
    this.locationUpdatedAt,
  });

  String get fullName => '$firstName $lastName'.trim();
  String get initials =>
      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
          .toUpperCase();

  String get ratingLabel {
    if (completedJobs == 0) return 'New worker';
    final rStr = rating > 0 ? '${rating.toStringAsFixed(1)}/5' : 'No rating';
    return '$rStr ($completedJobs ${completedJobs == 1 ? 'job' : 'jobs'})';
  }

  String get distanceLabel {
    if (distanceKm < 1) return '< 1 km away';
    return '${distanceKm.toStringAsFixed(1)} km away';
  }
}
