enum BookingStatus {
  pending,
  accepted,
  enRoute,
  arrived,
  inProgress,
  completed,
  rejected,
  cancelled,
  expired,
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

/// Client-selected arrival window for an URGENT booking. Null for
/// scheduled (NORMAL) bookings.
enum UrgentWindow {
  within1Hour,
  within2Hours,
  within4Hours,
}

enum AttachmentType { image, video, audio }

/// Who initiated a cancellation. Null for non-cancelled/non-expired bookings
/// and for historical rows predating this field.
enum CancelledByRole { client, worker }

extension CancelledByRoleX on CancelledByRole {
  String get raw => this == CancelledByRole.client ? 'CLIENT' : 'WORKER';

  static CancelledByRole? fromRaw(String? raw) {
    return switch (raw?.toUpperCase()) {
      'CLIENT' => CancelledByRole.client,
      'WORKER' => CancelledByRole.worker,
      _ => null,
    };
  }
}

/// Booking lane: STANDARD (fixed-price catalog), INSPECTION (fixed
/// inspection fee), or BIDDING (open worker bidding — the existing
/// known-problem flow). Older bookings created before this concept existed
/// always come back as BIDDING from the backend.
enum BookingLane { standard, inspection, bidding }

extension BookingLaneX on BookingLane {
  String get raw {
    return switch (this) {
      BookingLane.standard => 'STANDARD',
      BookingLane.inspection => 'INSPECTION',
      BookingLane.bidding => 'BIDDING',
    };
  }

  static BookingLane fromRaw(String? raw) {
    return switch (raw?.toUpperCase()) {
      'STANDARD' => BookingLane.standard,
      'INSPECTION' => BookingLane.inspection,
      _ => BookingLane.bidding,
    };
  }
}

/// Worker-facing lifecycle action for a STANDARD-lane assigned job — the
/// single next thing a worker should do. This is the shared source of truth
/// for "what button do we show" so the worker My Jobs list and Job Detail
/// page can never disagree about the same booking.
enum WorkerLifecycleAction { onMyWay, arrived, start, complete }

extension WorkerLifecycleActionX on WorkerLifecycleAction {
  String get label => switch (this) {
        WorkerLifecycleAction.onMyWay => 'On My Way',
        WorkerLifecycleAction.arrived => 'Arrived',
        WorkerLifecycleAction.start => 'Start Job',
        WorkerLifecycleAction.complete => 'Complete Job',
      };

  /// Shown in the success snackbar immediately after the action succeeds.
  String get successMessage => switch (this) {
        WorkerLifecycleAction.onMyWay => 'On the way — client notified.',
        WorkerLifecycleAction.arrived => 'Marked as arrived.',
        WorkerLifecycleAction.start => 'Job started.',
        WorkerLifecycleAction.complete => 'Job marked as completed.',
      };
}

extension BookingWorkerLifecycleX on BookingEntity {
  /// The single next lifecycle action a worker should take for this
  /// STANDARD-lane assigned job, or null when no action applies — either the
  /// lane isn't STANDARD (BIDDING/INSPECTION keep their existing generic
  /// "Mark as Completed" flow) or the booking isn't in an active
  /// worker-facing status (pending/completed/cancelled/etc).
  WorkerLifecycleAction? get standardWorkerNextAction {
    if (lane != BookingLane.standard) return null;
    return switch (status) {
      BookingStatus.accepted => WorkerLifecycleAction.onMyWay,
      BookingStatus.enRoute => WorkerLifecycleAction.arrived,
      BookingStatus.arrived => WorkerLifecycleAction.start,
      BookingStatus.inProgress => WorkerLifecycleAction.complete,
      _ => null,
    };
  }
}

/// Shared cancellation-visibility rules — single source of truth so the
/// client Bookings tab / Booking Detail page, and the worker My Jobs tab /
/// Job Detail page, can never disagree about whether a cancel button should
/// show. Mirrors the backend guards in BookingsService.cancelBooking and
/// BookingsService.workerCancelBooking exactly.
extension BookingCancellationX on BookingEntity {
  /// Client can cancel only before the worker is on the way — PENDING (no
  /// worker hired yet) or ACCEPTED (worker hired but hasn't started moving).
  bool get canClientCancel =>
      status == BookingStatus.pending || status == BookingStatus.accepted;

  /// Worker can cancel any time before starting the job — ACCEPTED, EN_ROUTE,
  /// or ARRIVED. Once IN_PROGRESS (work/inspection actually started) — and
  /// therefore also once a report has been submitted, a decision has been
  /// made, or the job is completed — cancelling is no longer allowed.
  /// Applies to all lanes.
  bool get canWorkerCancel =>
      status == BookingStatus.accepted ||
      status == BookingStatus.enRoute ||
      status == BookingStatus.arrived;

  /// INSPECTION-lane-specific alias for [canWorkerCancel] — identical rule,
  /// kept as a distinct getter for call sites that want to assert the lane
  /// explicitly (e.g. inspection-only UI branches).
  bool get canWorkerCancelInspection =>
      lane == BookingLane.inspection && canWorkerCancel;
}

/// Decision recorded on an INSPECTION-lane booking's report once the worker
/// has submitted it — drives both the worker's next action and the client's
/// report card/decision buttons.
enum InspectionDecisionStatus { pendingClientDecision, acceptedRepair, closedAfterInspection }

extension InspectionDecisionStatusX on InspectionDecisionStatus {
  String get raw => switch (this) {
        InspectionDecisionStatus.pendingClientDecision => 'PENDING_CLIENT_DECISION',
        InspectionDecisionStatus.acceptedRepair => 'ACCEPTED_REPAIR',
        InspectionDecisionStatus.closedAfterInspection => 'CLOSED_AFTER_INSPECTION',
      };

  static InspectionDecisionStatus? fromRaw(String? raw) {
    return switch (raw?.toUpperCase()) {
      'PENDING_CLIENT_DECISION' => InspectionDecisionStatus.pendingClientDecision,
      'ACCEPTED_REPAIR' => InspectionDecisionStatus.acceptedRepair,
      'CLOSED_AFTER_INSPECTION' => InspectionDecisionStatus.closedAfterInspection,
      _ => null,
    };
  }
}

/// Worker-facing lifecycle action for an INSPECTION-lane assigned job.
/// Mirrors [WorkerLifecycleAction] but adds the report-submission and
/// awaiting-decision steps unique to this lane.
enum InspectionWorkerAction {
  onMyWay,
  arrived,
  startInspection,
  fillReport,
  waitingForDecision,
  complete,
}

extension InspectionWorkerActionX on InspectionWorkerAction {
  String get label => switch (this) {
        InspectionWorkerAction.onMyWay => 'On My Way',
        InspectionWorkerAction.arrived => 'Arrived',
        InspectionWorkerAction.startInspection => 'Start Inspection',
        InspectionWorkerAction.fillReport => 'Fill Inspection Report',
        InspectionWorkerAction.waitingForDecision => 'Waiting for Client Decision',
        InspectionWorkerAction.complete => 'Complete Job',
      };

  /// Only [waitingForDecision] is a non-tappable informational state — every
  /// other action opens a confirmation/navigates to a screen.
  bool get isActionable => this != InspectionWorkerAction.waitingForDecision;

  String get successMessage => switch (this) {
        InspectionWorkerAction.onMyWay => 'On the way — client notified.',
        InspectionWorkerAction.arrived => 'Marked as arrived.',
        InspectionWorkerAction.startInspection => 'Inspection started.',
        InspectionWorkerAction.fillReport => '',
        InspectionWorkerAction.waitingForDecision => '',
        InspectionWorkerAction.complete => 'Job marked as completed.',
      };
}

extension BookingInspectionLifecycleX on BookingEntity {
  /// The single next lifecycle action a worker should take for this
  /// INSPECTION-lane assigned job, or null when the lane isn't INSPECTION or
  /// the booking isn't in an active worker-facing status.
  InspectionWorkerAction? get inspectionWorkerNextAction {
    if (lane != BookingLane.inspection) return null;
    return switch (status) {
      BookingStatus.accepted => InspectionWorkerAction.onMyWay,
      BookingStatus.enRoute => InspectionWorkerAction.arrived,
      BookingStatus.arrived => InspectionWorkerAction.startInspection,
      BookingStatus.inProgress => !inspectionReportSubmitted
          ? InspectionWorkerAction.fillReport
          : inspectionDecisionStatus == InspectionDecisionStatus.acceptedRepair
              ? InspectionWorkerAction.complete
              : InspectionWorkerAction.waitingForDecision,
      _ => null,
    };
  }
}

extension BookingStatusX on BookingStatus {
  /// Maps internal status → client-facing display label
  String get displayLabel {
    return switch (this) {
      BookingStatus.pending => 'Live',
      BookingStatus.accepted => 'Assigned',
      BookingStatus.enRoute => 'Assigned',
      BookingStatus.arrived => 'Assigned',
      BookingStatus.inProgress => 'Live',
      BookingStatus.completed => 'Completed',
      BookingStatus.rejected => 'Cancelled',
      BookingStatus.cancelled => 'Cancelled',
      BookingStatus.expired => 'Expired',
    };
  }

  /// Worker-facing label for job status
  String get workerLabel {
    return switch (this) {
      BookingStatus.pending => 'Pending',
      BookingStatus.accepted => 'Assigned',
      BookingStatus.enRoute => 'En Route',
      BookingStatus.arrived => 'Arrived',
      BookingStatus.inProgress => 'In Progress',
      BookingStatus.completed => 'Completed',
      BookingStatus.rejected => 'Rejected',
      BookingStatus.cancelled => 'Cancelled',
      BookingStatus.expired => 'Expired',
    };
  }

  /// True when the worker can still act on this job (not yet terminal)
  bool get isWorkerActive =>
      this == BookingStatus.accepted ||
      this == BookingStatus.enRoute ||
      this == BookingStatus.arrived ||
      this == BookingStatus.inProgress;

  /// Client-facing tab category
  BookingTab get tab {
    return switch (this) {
      BookingStatus.pending => BookingTab.live,
      BookingStatus.accepted => BookingTab.assigned,
      BookingStatus.enRoute => BookingTab.assigned,
      BookingStatus.arrived => BookingTab.assigned,
      BookingStatus.inProgress => BookingTab.live,
      BookingStatus.completed => BookingTab.completed,
      BookingStatus.rejected => BookingTab.cancelled,
      BookingStatus.cancelled => BookingTab.cancelled,
      BookingStatus.expired => BookingTab.cancelled,
    };
  }

  String get raw {
    return switch (this) {
      BookingStatus.pending => 'PENDING',
      BookingStatus.accepted => 'ACCEPTED',
      BookingStatus.enRoute => 'EN_ROUTE',
      BookingStatus.arrived => 'ARRIVED',
      BookingStatus.inProgress => 'IN_PROGRESS',
      BookingStatus.completed => 'COMPLETED',
      BookingStatus.rejected => 'REJECTED',
      BookingStatus.cancelled => 'CANCELLED',
      BookingStatus.expired => 'EXPIRED',
    };
  }

  static BookingStatus fromRaw(String raw) {
    return switch (raw.toUpperCase()) {
      'PENDING' => BookingStatus.pending,
      'ACCEPTED' => BookingStatus.accepted,
      'EN_ROUTE' => BookingStatus.enRoute,
      'ARRIVED' => BookingStatus.arrived,
      'IN_PROGRESS' => BookingStatus.inProgress,
      'COMPLETED' => BookingStatus.completed,
      'REJECTED' => BookingStatus.rejected,
      'CANCELLED' => BookingStatus.cancelled,
      'EXPIRED' => BookingStatus.expired,
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

extension UrgentWindowX on UrgentWindow {
  /// Matches the exact option labels used on the booking form
  /// (post_job_page.dart's `_buildUrgentSchedule` options list).
  String get label {
    return switch (this) {
      UrgentWindow.within1Hour => 'Within 1 hour',
      UrgentWindow.within2Hours => 'Within 2 hours',
      UrgentWindow.within4Hours => 'Within 4 hours',
    };
  }

  String get raw {
    return switch (this) {
      UrgentWindow.within1Hour => 'WITHIN_1_HOUR',
      UrgentWindow.within2Hours => 'WITHIN_2_HOURS',
      UrgentWindow.within4Hours => 'WITHIN_4_HOURS',
    };
  }

  static UrgentWindow? fromRaw(String? raw) {
    if (raw == null) return null;
    return switch (raw.toUpperCase()) {
      'WITHIN_1_HOUR' => UrgentWindow.within1Hour,
      'WITHIN_2_HOURS' => UrgentWindow.within2Hours,
      'WITHIN_4_HOURS' => UrgentWindow.within4Hours,
      _ => null,
    };
  }
}

extension AttachmentTypeX on AttachmentType {
  static AttachmentType fromRaw(String raw) {
    return switch (raw.toUpperCase()) {
      'VIDEO' => AttachmentType.video,
      // Accept AUDIO, VOICE, and VOICE_NOTE so any backend naming works.
      'AUDIO' || 'VOICE' || 'VOICE_NOTE' => AttachmentType.audio,
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
  final String? storageKey;
  final String? fileName;
  final String? mimeType;
  final int? sizeBytes;
  final double? durationSeconds;
  final String? thumbnailUrl;
  final DateTime createdAt;

  const BookingAttachmentEntity({
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
  final String? phone;

  const AssignedWorkerEntity({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.rating,
    this.avatarUrl,
    this.currentLat,
    this.currentLng,
    this.phone,
  });

  String get fullName => '$firstName $lastName';
  String get initials =>
      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
          .toUpperCase();
}

/// One selected STANDARD-lane sub-service (supports multi-select, e.g.
/// "AC General Service" + "AC Dismounting" in the same booking).
class BookingStandardServiceItemEntity {
  final String id;
  final String? standardServiceId;
  final String nameSnapshot;
  final double priceSnapshot;
  final int quantity;

  const BookingStandardServiceItemEntity({
    required this.id,
    this.standardServiceId,
    required this.nameSnapshot,
    required this.priceSnapshot,
    this.quantity = 1,
  });

  double get lineTotal => priceSnapshot * quantity;
}

/// A worker excluded from this booking (e.g. cancelled before arrival) — kept
/// so they are never re-offered/re-listed for this same booking, even after
/// relist.
class BookingWorkerExclusionEntity {
  final String workerProfileId;
  final String? reason;
  final DateTime createdAt;

  const BookingWorkerExclusionEntity({
    required this.workerProfileId,
    this.reason,
    required this.createdAt,
  });
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
  final UrgentWindow? urgentWindow;
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
  final DateTime? completedAt;
  final String? cancellationReason;
  final CancelledByRole? cancelledByRole;
  final DateTime? expiresAt;
  final DateTime? liveStartedAt;
  final DateTime? relistedAt;
  final AssignedWorkerEntity? assignedWorker;
  final int? availableWorkersCount;
  final double? acceptedBidAmount;
  final List<BookingAttachmentEntity> attachments;
  final BookingReviewEntity? review;
  final List<BookingStatusHistoryEntry> statusHistory;
  /// Full name of the client who created the booking.
  /// Populated on worker-facing responses; null on client-facing responses.
  final String? clientName;
  /// Client's phone number — populated on worker-facing responses only,
  /// powers the worker's "Call" button once hired.
  final String? clientPhone;
  final bool inspection;
  final BookingLane lane;
  final String? standardServiceId;
  final String? standardServiceNameSnapshot;
  final double? standardServicePriceSnapshot;
  final List<BookingStandardServiceItemEntity> standardServiceItems;
  final double? inspectionFeeSnapshot;
  final List<BookingWorkerExclusionEntity> workerExclusions;
  final String? lastWorkerCancellationReason;
  /// INSPECTION lane: true once the assigned worker has submitted their report.
  final bool inspectionReportSubmitted;
  /// INSPECTION lane: null until a report exists, then tracks the client's decision.
  final InspectionDecisionStatus? inspectionDecisionStatus;
  final DateTime? inspectionReportSubmittedAt;

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
    this.lane = BookingLane.bidding,
    this.standardServiceId,
    this.standardServiceNameSnapshot,
    this.standardServicePriceSnapshot,
    this.standardServiceItems = const [],
    this.inspectionFeeSnapshot,
    this.workerExclusions = const [],
    this.lastWorkerCancellationReason,
    this.inspectionReportSubmitted = false,
    this.inspectionDecisionStatus,
    this.inspectionReportSubmittedAt,
  });

  /// Sum of all selected STANDARD-lane sub-service prices (× quantity).
  /// Falls back to the legacy singular snapshot when no item rows exist.
  double? get standardServicesTotal {
    if (standardServiceItems.isNotEmpty) {
      return standardServiceItems.fold<double>(
        0,
        (sum, item) => sum + item.lineTotal,
      );
    }
    return standardServicePriceSnapshot;
  }

  BookingEntity copyWith({
    BookingStatus? status,
    double? estimatedPrice,
    double? finalPrice,
    double? acceptedBidAmount,
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
      urgentWindow: urgentWindow,
      scheduledDate: scheduledDate,
      createdAt: createdAt,
      acceptedAt: acceptedAt,
      enRouteAt: enRouteAt,
      arrivedAt: arrivedAt,
      startedAt: startedAt,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      finalPrice: finalPrice ?? this.finalPrice,
      address: address,
      city: city,
      latitude: latitude,
      longitude: longitude,
      completedAt: completedAt ?? this.completedAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledByRole: cancelledByRole,
      expiresAt: expiresAt,
      liveStartedAt: liveStartedAt,
      relistedAt: relistedAt,
      assignedWorker: assignedWorker ?? this.assignedWorker,
      availableWorkersCount: availableWorkersCount ?? this.availableWorkersCount,
      acceptedBidAmount: acceptedBidAmount ?? this.acceptedBidAmount,
      attachments: attachments ?? this.attachments,
      review: review ?? this.review,
      statusHistory: statusHistory ?? this.statusHistory,
      clientName: clientName,
      clientPhone: clientPhone,
      inspection: inspection,
      lane: lane,
      standardServiceId: standardServiceId,
      standardServiceNameSnapshot: standardServiceNameSnapshot,
      standardServicePriceSnapshot: standardServicePriceSnapshot,
      standardServiceItems: standardServiceItems,
      inspectionFeeSnapshot: inspectionFeeSnapshot,
      workerExclusions: workerExclusions,
      lastWorkerCancellationReason: lastWorkerCancellationReason,
      inspectionReportSubmitted: inspectionReportSubmitted,
      inspectionDecisionStatus: inspectionDecisionStatus,
      inspectionReportSubmittedAt: inspectionReportSubmittedAt,
    );
  }
}

/// Handles bookings created before the `inspection` boolean existed, which
/// encoded the inspection choice as a text prefix inside `description`.
/// New bookings never write this prefix — it only needs to be recognized
/// and stripped for older rows still stored with it in the DB.
extension BookingDescriptionX on BookingEntity {
  static const _kLegacyInspectionPrefix =
      '[INSPECTION ONLY] Customer requested inspection first.';
  static const _kLegacySeesLabel = 'What customer sees:';

  bool get hasLegacyInspectionPrefix =>
      (description ?? '').startsWith(_kLegacyInspectionPrefix);

  /// The description with any legacy inspection-prefix encoding stripped, so
  /// older bookings display only the text the client actually typed.
  String? get cleanDescription {
    final raw = description;
    if (raw == null) return null;
    if (!raw.startsWith(_kLegacyInspectionPrefix)) return raw;
    final remainder = raw.substring(_kLegacyInspectionPrefix.length).trim();
    if (remainder.startsWith(_kLegacySeesLabel)) {
      final text = remainder.substring(_kLegacySeesLabel.length).trim();
      return text.isEmpty ? null : text;
    }
    return remainder.isEmpty ? null : remainder;
  }
}
