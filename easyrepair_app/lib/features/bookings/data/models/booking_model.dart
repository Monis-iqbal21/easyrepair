import '../../../../core/config/app_config.dart';
import '../../domain/entities/booking_entity.dart';

class BookingAttachmentModel {
  final String id;
  final String type; // 'IMAGE' | 'VIDEO' | 'AUDIO'
  final String url;
  final String? storageKey;
  final String? fileName;
  final String? mimeType;
  final int? sizeBytes;
  final double? durationSeconds;
  final String? thumbnailUrl;
  final DateTime createdAt;

  const BookingAttachmentModel({
    required this.id,
    required this.type,
    required this.url,
    this.storageKey,
    this.fileName,
    this.mimeType,
    this.sizeBytes,
    this.durationSeconds,
    this.thumbnailUrl,
    required this.createdAt,
  });

  factory BookingAttachmentModel.fromJson(Map<String, dynamic> json) {
    return BookingAttachmentModel(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'IMAGE',
      url: json['url'] as String,
      storageKey: json['storageKey'] as String?,
      fileName: json['fileName'] as String?,
      mimeType: json['mimeType'] as String?,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
      thumbnailUrl: json['thumbnailUrl'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  BookingAttachmentEntity toEntity() => BookingAttachmentEntity(
        id: id,
        type: AttachmentTypeX.fromRaw(type),
        url: _resolveUrl(url),
        storageKey: storageKey,
        fileName: fileName,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
        durationSeconds: durationSeconds,
        thumbnailUrl: thumbnailUrl,
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

class BookingStandardServiceItemModel {
  final String id;
  final String? standardServiceId;
  final String nameSnapshot;
  final double priceSnapshot;
  final int quantity;

  const BookingStandardServiceItemModel({
    required this.id,
    this.standardServiceId,
    required this.nameSnapshot,
    required this.priceSnapshot,
    this.quantity = 1,
  });

  factory BookingStandardServiceItemModel.fromJson(Map<String, dynamic> json) {
    return BookingStandardServiceItemModel(
      id: json['id'] as String,
      standardServiceId: json['standardServiceId'] as String?,
      nameSnapshot: json['nameSnapshot'] as String? ?? '',
      priceSnapshot: (json['priceSnapshot'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }

  BookingStandardServiceItemEntity toEntity() => BookingStandardServiceItemEntity(
        id: id,
        standardServiceId: standardServiceId,
        nameSnapshot: nameSnapshot,
        priceSnapshot: priceSnapshot,
        quantity: quantity,
      );
}

class BookingWorkerExclusionModel {
  final String workerProfileId;
  final String? workerName;
  final String? reason;
  final DateTime createdAt;

  const BookingWorkerExclusionModel({
    required this.workerProfileId,
    this.workerName,
    this.reason,
    required this.createdAt,
  });

  factory BookingWorkerExclusionModel.fromJson(Map<String, dynamic> json) {
    return BookingWorkerExclusionModel(
      workerProfileId: json['workerProfileId'] as String? ?? '',
      workerName: json['workerName'] as String?,
      reason: json['reason'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  BookingWorkerExclusionEntity toEntity() => BookingWorkerExclusionEntity(
        workerProfileId: workerProfileId,
        workerName: workerName,
        reason: reason,
        createdAt: createdAt,
      );
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
  final String? urgentWindow;
  final DateTime? scheduledDate;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? enRouteAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final double? estimatedPrice;
  final double? finalPrice;
  final String? address;
  final String city;
  final double latitude;
  final double longitude;
  final double? distanceKm;
  final DateTime? completedAt;
  final String? cancellationReason;
  final String? cancelledByRole;
  final DateTime? expiresAt;
  final DateTime? liveStartedAt;
  final DateTime? relistedAt;
  final AssignedWorkerModel? assignedWorker;
  final int? availableWorkersCount;
  final double? acceptedBidAmount;
  final List<BookingAttachmentModel> attachments;
  final BookingReviewModel? review;
  final List<BookingStatusHistoryModel> statusHistory;
  final String? clientName;
  final String? clientPhone;
  final bool inspection;
  final String lane;
  final String? standardServiceId;
  final String? standardServiceNameSnapshot;
  final double? standardServicePriceSnapshot;
  final List<BookingStandardServiceItemModel> standardServiceItems;
  final double? inspectionFeeSnapshot;
  final List<BookingWorkerExclusionModel> workerExclusions;
  final String? lastWorkerCancellationReason;
  final String? lastWorkerCancellationWorkerName;
  final bool inspectionReportSubmitted;
  final String? inspectionDecisionStatus;
  final DateTime? inspectionReportSubmittedAt;

  const BookingModel({
    required this.id,
    required this.serviceCategory,
    this.title,
    this.description,
    required this.status,
    required this.urgency,
    this.timeSlot,
    this.urgentWindow,
    this.scheduledDate,
    required this.createdAt,
    this.acceptedAt,
    this.enRouteAt,
    this.arrivedAt,
    this.startedAt,
    this.estimatedPrice,
    this.finalPrice,
    this.address,
    this.city = '',
    this.latitude = 0,
    this.longitude = 0,
    this.distanceKm,
    this.completedAt,
    this.cancellationReason,
    this.cancelledByRole,
    this.expiresAt,
    this.liveStartedAt,
    this.relistedAt,
    this.assignedWorker,
    this.availableWorkersCount,
    this.acceptedBidAmount,
    this.attachments = const [],
    this.review,
    this.statusHistory = const [],
    this.clientName,
    this.clientPhone,
    this.inspection = false,
    this.lane = 'BIDDING',
    this.standardServiceId,
    this.standardServiceNameSnapshot,
    this.standardServicePriceSnapshot,
    this.standardServiceItems = const [],
    this.inspectionFeeSnapshot,
    this.workerExclusions = const [],
    this.lastWorkerCancellationReason,
    this.lastWorkerCancellationWorkerName,
    this.inspectionReportSubmitted = false,
    this.inspectionDecisionStatus,
    this.inspectionReportSubmittedAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final workerJson = json['worker'] as Map<String, dynamic>?;
    final reviewJson = json['review'] as Map<String, dynamic>?;
    final attachmentsJson = json['attachments'] as List<dynamic>? ?? [];
    final historyJson = json['statusHistory'] as List<dynamic>? ?? [];
    final standardServiceItemsJson =
        json['standardServiceItems'] as List<dynamic>? ?? [];
    final workerExclusionsJson =
        json['workerExclusions'] as List<dynamic>? ?? [];
    return BookingModel(
      id: json['id'] as String,
      serviceCategory: json['serviceCategory'] as String? ?? 'Service',
      title: json['title'] as String?,
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      urgency: json['urgency'] as String? ?? 'NORMAL',
      timeSlot: json['timeSlot'] as String?,
      urgentWindow: json['urgentWindow'] as String?,
      scheduledDate: json['scheduledDate'] != null
          ? DateTime.tryParse(json['scheduledDate'] as String)
          : null,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      acceptedAt: json['acceptedAt'] != null
          ? DateTime.tryParse(json['acceptedAt'] as String)
          : null,
      enRouteAt: json['enRouteAt'] != null
          ? DateTime.tryParse(json['enRouteAt'] as String)
          : null,
      arrivedAt: json['arrivedAt'] != null
          ? DateTime.tryParse(json['arrivedAt'] as String)
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
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      cancellationReason: json['cancellationReason'] as String?,
      cancelledByRole: json['cancelledByRole'] as String?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      liveStartedAt: json['liveStartedAt'] != null
          ? DateTime.tryParse(json['liveStartedAt'] as String)
          : null,
      relistedAt: json['relistedAt'] != null
          ? DateTime.tryParse(json['relistedAt'] as String)
          : null,
      assignedWorker:
          workerJson != null ? AssignedWorkerModel.fromJson(workerJson) : null,
      availableWorkersCount: json['availableWorkersCount'] as int?,
      acceptedBidAmount: (json['acceptedBidAmount'] as num?)?.toDouble(),
      attachments: attachmentsJson
          .map((e) => BookingAttachmentModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      review: reviewJson != null ? BookingReviewModel.fromJson(reviewJson) : null,
      statusHistory: historyJson
          .map((e) => BookingStatusHistoryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      clientName: json['clientName'] as String?,
      clientPhone: json['clientPhone'] as String?,
      inspection: json['inspection'] as bool? ?? false,
      lane: json['lane'] as String? ?? 'BIDDING',
      standardServiceId: json['standardServiceId'] as String?,
      standardServiceNameSnapshot:
          json['standardServiceNameSnapshot'] as String?,
      standardServicePriceSnapshot:
          (json['standardServicePriceSnapshot'] as num?)?.toDouble(),
      standardServiceItems: standardServiceItemsJson
          .map((e) => BookingStandardServiceItemModel.fromJson(
              e as Map<String, dynamic>))
          .toList(),
      inspectionFeeSnapshot:
          (json['inspectionFeeSnapshot'] as num?)?.toDouble(),
      workerExclusions: workerExclusionsJson
          .map((e) =>
              BookingWorkerExclusionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      lastWorkerCancellationReason:
          json['lastWorkerCancellationReason'] as String?,
      lastWorkerCancellationWorkerName:
          json['lastWorkerCancellationWorkerName'] as String?,
      inspectionReportSubmitted:
          json['inspectionReportSubmitted'] as bool? ?? false,
      inspectionDecisionStatus: json['inspectionDecisionStatus'] as String?,
      inspectionReportSubmittedAt: json['inspectionReportSubmittedAt'] != null
          ? DateTime.tryParse(json['inspectionReportSubmittedAt'] as String)
          : null,
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
      'pest control' || 'pest' => '🐛',
      'car wash' => '🚗',
      'gardener' || 'gardening' => '🌿',
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
      urgentWindow: UrgentWindowX.fromRaw(urgentWindow),
      scheduledDate: scheduledDate,
      createdAt: createdAt,
      acceptedAt: acceptedAt,
      enRouteAt: enRouteAt,
      arrivedAt: arrivedAt,
      startedAt: startedAt,
      estimatedPrice: estimatedPrice,
      finalPrice: finalPrice,
      address: address,
      city: city,
      latitude: latitude,
      longitude: longitude,
      distanceKm: distanceKm,
      completedAt: completedAt,
      cancellationReason: cancellationReason,
      cancelledByRole: CancelledByRoleX.fromRaw(cancelledByRole),
      expiresAt: expiresAt,
      liveStartedAt: liveStartedAt,
      relistedAt: relistedAt,
      assignedWorker: assignedWorker?.toEntity(),
      availableWorkersCount: availableWorkersCount,
      acceptedBidAmount: acceptedBidAmount,
      attachments: attachments.map((a) => a.toEntity()).toList(),
      review: review?.toEntity(),
      statusHistory: statusHistory.map((h) => h.toEntity()).toList(),
      clientName: clientName,
      clientPhone: clientPhone,
      inspection: inspection,
      lane: BookingLaneX.fromRaw(lane),
      standardServiceId: standardServiceId,
      standardServiceNameSnapshot: standardServiceNameSnapshot,
      standardServicePriceSnapshot: standardServicePriceSnapshot,
      standardServiceItems:
          standardServiceItems.map((i) => i.toEntity()).toList(),
      inspectionFeeSnapshot: inspectionFeeSnapshot,
      workerExclusions: workerExclusions.map((e) => e.toEntity()).toList(),
      lastWorkerCancellationReason: lastWorkerCancellationReason,
      lastWorkerCancellationWorkerName: lastWorkerCancellationWorkerName,
      inspectionReportSubmitted: inspectionReportSubmitted,
      inspectionDecisionStatus:
          InspectionDecisionStatusX.fromRaw(inspectionDecisionStatus),
      inspectionReportSubmittedAt: inspectionReportSubmittedAt,
    );
  }
}

// ── Internal model for status history entries ─────────────────────────────────

class BookingStatusHistoryModel {
  final String id;
  final String status;
  final String? note;
  final DateTime createdAt;

  const BookingStatusHistoryModel({
    required this.id,
    required this.status,
    this.note,
    required this.createdAt,
  });

  factory BookingStatusHistoryModel.fromJson(Map<String, dynamic> json) {
    return BookingStatusHistoryModel(
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
