class WorkerReviewEntity {
  final String id;
  final int rating;
  final String? comment;
  final String serviceCategory;
  final String? clientName;
  final DateTime createdAt;
  final String? bookingId;

  const WorkerReviewEntity({
    required this.id,
    required this.rating,
    this.comment,
    required this.serviceCategory,
    this.clientName,
    required this.createdAt,
    this.bookingId,
  });
}

class WorkerReviewSummaryEntity {
  final int totalReviews;
  final double averageRating;

  const WorkerReviewSummaryEntity({
    required this.totalReviews,
    required this.averageRating,
  });
}
