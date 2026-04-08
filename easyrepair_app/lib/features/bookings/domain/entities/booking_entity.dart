enum BookingStatus {
  pending,
  accepted,
  enRoute,
  inProgress,
  completed,
  rejected,
  cancelled,
}

enum BookingUrgency {
  urgent,
  normal,
}

enum TimeSlot {
  morning,
  afternoon,
  evening,
  night,
}

enum AttachmentType { image, video, audio }

extension BookingStatusX on BookingStatus {
  /// Maps internal status → client-facing display label
  String get displayLabel {
    return switch (this) {
      BookingStatus.pending => 'Live',
      BookingStatus.accepted => 'Assigned',
      BookingStatus.enRoute => 'Assigned',
      BookingStatus.inProgress => 'Live',
      BookingStatus.completed => 'Completed',
      BookingStatus.rejected => 'Cancelled',
      BookingStatus.cancelled => 'Cancelled',
    };
  }

  /// Worker-facing label for job status
  String get workerLabel {
    return switch (this) {
      BookingStatus.pending => 'Pending',
      BookingStatus.accepted => 'Assigned',
      BookingStatus.enRoute => 'En Route',
      BookingStatus.inProgress => 'In Progress',
      BookingStatus.completed => 'Completed',
      BookingStatus.rejected => 'Rejected',
      BookingStatus.cancelled => 'Cancelled',
    };
  }

  /// True when the worker can still act on this job (not yet terminal)
  bool get isWorkerActive =>
      this == BookingStatus.accepted ||
      this == BookingStatus.enRoute ||
      this == BookingStatus.inProgress;

  /// Client-facing tab category
  BookingTab get tab {
    return switch (this) {
      BookingStatus.pending => BookingTab.live,
      BookingStatus.accepted => BookingTab.assigned,
      BookingStatus.enRoute => BookingTab.assigned,
      BookingStatus.inProgress => BookingTab.live,
      BookingStatus.completed => BookingTab.completed,
      BookingStatus.rejected => BookingTab.cancelled,
      BookingStatus.cancelled => BookingTab.cancelled,
    };
  }

  String get raw {
    return switch (this) {
      BookingStatus.pending => 'PENDING',
      BookingStatus.accepted => 'ACCEPTED',
      BookingStatus.enRoute => 'EN_ROUTE',
      BookingStatus.inProgress => 'IN_PROGRESS',
      BookingStatus.completed => 'COMPLETED',
      BookingStatus.rejected => 'REJECTED',
      BookingStatus.cancelled => 'CANCELLED',
    };
  }

  static BookingStatus fromRaw(String raw) {
    return switch (raw.toUpperCase()) {
      'PENDING' => BookingStatus.pending,
      'ACCEPTED' => BookingStatus.accepted,
      'EN_ROUTE' => BookingStatus.enRoute,
      'IN_PROGRESS' => BookingStatus.inProgress,
      'COMPLETED' => BookingStatus.completed,
      'REJECTED' => BookingStatus.rejected,
      'CANCELLED' => BookingStatus.cancelled,
      _ => BookingStatus.pending,
    };
  }
}

extension BookingUrgencyX on BookingUrgency {
  String get raw => this == BookingUrgency.urgent ? 'URGENT' : 'NORMAL';

  static BookingUrgency fromRaw(String raw) =>
      raw.toUpperCase() == 'URGENT' ? BookingUrgency.urgent : BookingUrgency.normal;
}

extension TimeSlotX on TimeSlot {
  String get label {
    return switch (this) {
      TimeSlot.morning => 'Morning',
      TimeSlot.afternoon => 'Afternoon',
      TimeSlot.evening => 'Evening',
      TimeSlot.night => 'Night',
    };
  }

  static TimeSlot? fromRaw(String? raw) {
    if (raw == null) return null;
    return switch (raw.toUpperCase()) {
      'MORNING' => TimeSlot.morning,
      'AFTERNOON' => TimeSlot.afternoon,
      'EVENING' => TimeSlot.evening,
      'NIGHT' => TimeSlot.night,
      _ => null,
    };
  }
}

extension AttachmentTypeX on AttachmentType {
  static AttachmentType fromRaw(String raw) {
    return switch (raw.toUpperCase()) {
      'VIDEO' => AttachmentType.video,
      'AUDIO' => AttachmentType.audio,
      _ => AttachmentType.image,
    };
  }
}

enum BookingTab { all, live, assigned, completed, cancelled }

extension BookingTabX on BookingTab {
  String get label {
    return switch (this) {
      BookingTab.all => 'All',
      BookingTab.live => 'Live',
      BookingTab.assigned => 'Assigned',
      BookingTab.completed => 'Completed',
      BookingTab.cancelled => 'Cancelled',
    };
  }
}

class BookingAttachmentEntity {
  final String id;
  final AttachmentType type;
  final String url;
  final String? fileName;
  final String? mimeType;
  final DateTime createdAt;

  const BookingAttachmentEntity({
    required this.id,
    required this.type,
    required this.url,
    this.fileName,
    this.mimeType,
    required this.createdAt,
  });
}

class BookingReviewEntity {
  final String id;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const BookingReviewEntity({
    required this.id,
    required this.rating,
    this.comment,
    required this.createdAt,
  });
}

class AssignedWorkerEntity {
  final String id;
  final String firstName;
  final String lastName;
  final double? rating;
  final String? avatarUrl;
  final double? currentLat;
  final double? currentLng;

  const AssignedWorkerEntity({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.rating,
    this.avatarUrl,
    this.currentLat,
    this.currentLng,
  });

  String get fullName => '$firstName $lastName';
  String get initials =>
      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
          .toUpperCase();
}

/// One entry from the booking_status_history table.
class BookingStatusHistoryEntry {
  final String id;
  final BookingStatus status;
  final String? note;
  final DateTime createdAt;

  const BookingStatusHistoryEntry({
    required this.id,
    required this.status,
    this.note,
    required this.createdAt,
  });
}

class BookingEntity {
  final String id;
  final String referenceId; // short display ID e.g. #ER-1042
  final String serviceCategory;
  final String serviceEmoji;
  final String? title;
  final String? description;
  final BookingStatus status;
  final BookingUrgency urgency;
  final TimeSlot? timeSlot;
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
  final AssignedWorkerEntity? assignedWorker;
  final int? availableWorkersCount;
  final List<BookingAttachmentEntity> attachments;
  final BookingReviewEntity? review;
  final List<BookingStatusHistoryEntry> statusHistory;
  /// Full name of the client who created the booking.
  /// Populated on worker-facing responses; null on client-facing responses.
  final String? clientName;

  const BookingEntity({
    required this.id,
    required this.referenceId,
    required this.serviceCategory,
    required this.serviceEmoji,
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
    this.attachments = const [],
    this.review,
    this.statusHistory = const [],
    this.clientName,
  });

  BookingEntity copyWith({
    BookingStatus? status,
    double? estimatedPrice,
    double? finalPrice,
    AssignedWorkerEntity? assignedWorker,
    DateTime? completedAt,
    String? cancellationReason,
    List<BookingAttachmentEntity>? attachments,
    BookingReviewEntity? review,
    int? availableWorkersCount,
    List<BookingStatusHistoryEntry>? statusHistory,
  }) {
    return BookingEntity(
      id: id,
      referenceId: referenceId,
      serviceCategory: serviceCategory,
      serviceEmoji: serviceEmoji,
      title: title,
      description: description,
      status: status ?? this.status,
      urgency: urgency,
      timeSlot: timeSlot,
      scheduledDate: scheduledDate,
      createdAt: createdAt,
      acceptedAt: acceptedAt,
      startedAt: startedAt,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      finalPrice: finalPrice ?? this.finalPrice,
      address: address,
      city: city,
      latitude: latitude,
      longitude: longitude,
      completedAt: completedAt ?? this.completedAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      assignedWorker: assignedWorker ?? this.assignedWorker,
      availableWorkersCount: availableWorkersCount ?? this.availableWorkersCount,
      attachments: attachments ?? this.attachments,
      review: review ?? this.review,
      statusHistory: statusHistory ?? this.statusHistory,
      clientName: clientName,
    );
  }
}
