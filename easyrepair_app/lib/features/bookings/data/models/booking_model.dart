import '../../../../core/config/app_config.dart';
import '../../domain/entities/booking_entity.dart';

class BookingAttachmentModel {
  final String id;
  final String type; // 'IMAGE' | 'VIDEO' | 'AUDIO'
  final String url;
  final String? fileName;
  final String? mimeType;
  final DateTime createdAt;

  const BookingAttachmentModel({
    required this.id,
    required this.type,
    required this.url,
    this.fileName,
    this.mimeType,
    required this.createdAt,
  });

  factory BookingAttachmentModel.fromJson(Map<String, dynamic> json) {
    return BookingAttachmentModel(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'IMAGE',
      url: json['url'] as String,
      fileName: json['fileName'] as String?,
      mimeType: json['mimeType'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  BookingAttachmentEntity toEntity() => BookingAttachmentEntity(
        id: id,
        type: AttachmentTypeX.fromRaw(type),
        url: _resolveUrl(url),
        fileName: fileName,
        mimeType: mimeType,
        createdAt: createdAt,
      );

  /// Returns the URL as-is when it's already absolute.
  /// For relative paths (e.g. /uploads/...) prepends the backend origin so
  /// the audio player, image network, and video player all receive a full URL.
  static String _resolveUrl(String raw) {
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final base =
        AppConfig.apiBaseUrl.replaceAll(RegExp(r'/api/v\d+/?$'), '');
    return raw.startsWith('/') ? '$base$raw' : '$base/$raw';
  }
}

class BookingReviewModel {
  final String id;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const BookingReviewModel({
    required this.id,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory BookingReviewModel.fromJson(Map<String, dynamic> json) {
    return BookingReviewModel(
      id: json['id'] as String,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  BookingReviewEntity toEntity() => BookingReviewEntity(
        id: id,
        rating: rating,
        comment: comment,
        createdAt: createdAt,
      );
}

class AssignedWorkerModel {
  final String id;
  final String firstName;
  final String lastName;
  final double? rating;
  final String? avatarUrl;
  final double? currentLat;
  final double? currentLng;
  final String? phone;

  const AssignedWorkerModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.rating,
    this.avatarUrl,
    this.currentLat,
    this.currentLng,
    this.phone,
  });

  factory AssignedWorkerModel.fromJson(Map<String, dynamic> json) {
    return AssignedWorkerModel(
      id: json['id'] as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble(),
      avatarUrl: json['avatarUrl'] as String?,
      currentLat: (json['currentLat'] as num?)?.toDouble(),
      currentLng: (json['currentLng'] as num?)?.toDouble(),
      phone: json['phone'] as String?,
    );
  }

  AssignedWorkerEntity toEntity() => AssignedWorkerEntity(
        id: id,
        firstName: firstName,
        lastName: lastName,
        rating: rating,
        avatarUrl: avatarUrl,
        currentLat: currentLat,
        currentLng: currentLng,
        phone: phone,
      );
}

/// Maps the raw API response to [BookingEntity].
/// Handles both the client booking response (BookingResponseDto) and the
/// worker job response (WorkerJobResponseDto), which share the same field
/// names plus optional extras (acceptedAt, startedAt, statusHistory).
class BookingModel {
  final String id;
  final String serviceCategory;
  final String? title;
  final String? description;
  final String status;
  final String urgency;
  final String? timeSlot;
  final DateTime? scheduledDate;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final double? estimatedPrice;
  final double? finalPrice;
  final String? address;
  final String city;
  final double latitude;
  final double longitude;
  final DateTime? completedAt;
  final String? cancellationReason;
  final AssignedWorkerModel? assignedWorker;
  final int? availableWorkersCount;
  final double? acceptedBidAmount;
  final List<BookingAttachmentModel> attachments;
  final BookingReviewModel? review;
  final List<_StatusHistoryModel> statusHistory;
  final String? clientName;

  const BookingModel({
    required this.id,
    required this.serviceCategory,
    this.title,
    this.description,
    required this.status,
    required this.urgency,
    this.timeSlot,
    this.scheduledDate,
    required this.createdAt,
    this.acceptedAt,
    this.startedAt,
    this.estimatedPrice,
    this.finalPrice,
    this.address,
    this.city = '',
    this.latitude = 0,
    this.longitude = 0,
    this.completedAt,
    this.cancellationReason,
    this.assignedWorker,
    this.availableWorkersCount,
    this.acceptedBidAmount,
    this.attachments = const [],
    this.review,
    this.statusHistory = const [],
    this.clientName,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final workerJson = json['worker'] as Map<String, dynamic>?;
    final reviewJson = json['review'] as Map<String, dynamic>?;
    final attachmentsJson = json['attachments'] as List<dynamic>? ?? [];
    final historyJson = json['statusHistory'] as List<dynamic>? ?? [];
    return BookingModel(
      id: json['id'] as String,
      serviceCategory: json['serviceCategory'] as String? ?? 'Service',
      title: json['title'] as String?,
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      urgency: json['urgency'] as String? ?? 'NORMAL',
      timeSlot: json['timeSlot'] as String?,
      scheduledDate: json['scheduledDate'] != null
          ? DateTime.tryParse(json['scheduledDate'] as String)
          : null,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      acceptedAt: json['acceptedAt'] != null
          ? DateTime.tryParse(json['acceptedAt'] as String)
          : null,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'] as String)
          : null,
      estimatedPrice: (json['estimatedPrice'] as num?)?.toDouble(),
      finalPrice: (json['finalPrice'] as num?)?.toDouble(),
      address: json['address'] as String?,
      city: json['city'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      cancellationReason: json['cancellationReason'] as String?,
      assignedWorker:
          workerJson != null ? AssignedWorkerModel.fromJson(workerJson) : null,
      availableWorkersCount: json['availableWorkersCount'] as int?,
      acceptedBidAmount: (json['acceptedBidAmount'] as num?)?.toDouble(),
      attachments: attachmentsJson
          .map((e) => BookingAttachmentModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      review: reviewJson != null ? BookingReviewModel.fromJson(reviewJson) : null,
      statusHistory: historyJson
          .map((e) => _StatusHistoryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      clientName: json['clientName'] as String?,
    );
  }

  static String _emojiForCategory(String category) {
    return switch (category.toLowerCase()) {
      'ac technician' || 'ac' => '❄️',
      'electrician' => '⚡',
      'plumber' || 'plumbing' => '🔧',
      'handyman' => '🔨',
      'painter' || 'painting' => '🎨',
      'carpenter' || 'carpentry' => '🪚',
      'cleaner' || 'cleaning' => '🧹',
      _ => '🛠️',
    };
  }

  BookingEntity toEntity() {
    final shortId = id.length >= 6
        ? '#ER-${id.substring(id.length - 6).toUpperCase()}'
        : '#${id.toUpperCase()}';
    return BookingEntity(
      id: id,
      referenceId: shortId,
      serviceCategory: serviceCategory,
      serviceEmoji: _emojiForCategory(serviceCategory),
      title: title,
      description: description,
      status: BookingStatusX.fromRaw(status),
      urgency: BookingUrgencyX.fromRaw(urgency),
      timeSlot: TimeSlotX.fromRaw(timeSlot),
      scheduledDate: scheduledDate,
      createdAt: createdAt,
      acceptedAt: acceptedAt,
      startedAt: startedAt,
      estimatedPrice: estimatedPrice,
      finalPrice: finalPrice,
      address: address,
      city: city,
      latitude: latitude,
      longitude: longitude,
      completedAt: completedAt,
      cancellationReason: cancellationReason,
      assignedWorker: assignedWorker?.toEntity(),
      availableWorkersCount: availableWorkersCount,
      acceptedBidAmount: acceptedBidAmount,
      attachments: attachments.map((a) => a.toEntity()).toList(),
      review: review?.toEntity(),
      statusHistory: statusHistory.map((h) => h.toEntity()).toList(),
      clientName: clientName,
    );
  }
}

// ── Internal model for status history entries ─────────────────────────────────

class _StatusHistoryModel {
  final String id;
  final String status;
  final String? note;
  final DateTime createdAt;

  const _StatusHistoryModel({
    required this.id,
    required this.status,
    this.note,
    required this.createdAt,
  });

  factory _StatusHistoryModel.fromJson(Map<String, dynamic> json) {
    return _StatusHistoryModel(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'PENDING',
      note: json['note'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  BookingStatusHistoryEntry toEntity() => BookingStatusHistoryEntry(
        id: id,
        status: BookingStatusX.fromRaw(status),
        note: note,
        createdAt: createdAt,
      );
}
