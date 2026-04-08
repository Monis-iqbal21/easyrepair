import '../../domain/entities/worker_review_entity.dart';

class WorkerReviewModel {
  final String id;
  final int rating;
  final String? comment;
  final String serviceCategory;
  final String? clientName;
  final DateTime createdAt;

  const WorkerReviewModel({
    required this.id,
    required this.rating,
    this.comment,
    required this.serviceCategory,
    this.clientName,
    required this.createdAt,
  });

  factory WorkerReviewModel.fromJson(Map<String, dynamic> json) {
    return WorkerReviewModel(
      id: json['id'] as String,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      serviceCategory: json['serviceCategory'] as String? ?? 'Service',
      clientName: json['clientName'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  WorkerReviewEntity toEntity() => WorkerReviewEntity(
        id: id,
        rating: rating,
        comment: comment,
        serviceCategory: serviceCategory,
        clientName: clientName,
        createdAt: createdAt,
      );
}

class WorkerReviewSummaryModel {
  final int totalReviews;
  final double averageRating;

  const WorkerReviewSummaryModel({
    required this.totalReviews,
    required this.averageRating,
  });

  factory WorkerReviewSummaryModel.fromJson(Map<String, dynamic> json) {
    return WorkerReviewSummaryModel(
      totalReviews: json['totalReviews'] as int? ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
    );
  }

  WorkerReviewSummaryEntity toEntity() => WorkerReviewSummaryEntity(
        totalReviews: totalReviews,
        averageRating: averageRating,
      );
}
