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
  /// Null before hire — the backend only exposes exact address/coordinates
  /// once a worker is assigned. Use [city] + [distanceKm] instead.
  final String? addressLine;
  final String city;
  final double latitude;
  final double longitude;
  final DateTime? scheduledAt;
  final DateTime createdAt;
  final NewJobCategoryEntity category;
  final NewJobClientEntity client;
  final int bidCount;
  final double? distanceKm;
  final bool hasMyBid;
  /// Null means no worker assigned yet (booking is open / Live).
  final String? workerProfileId;
  final bool inspection;
  final BookingLane lane;
  final List<BookingStandardServiceItemEntity> standardServiceItems;
  /// INSPECTION lane only — the fixed fee from the category's fee schedule,
  /// known before any Ustaad is hired. Null for STANDARD/BIDDING.
  final double? inspectionFeeSnapshot;
  /// Server-computed: true for BIDDING lane, or an INSPECTION job the
  /// customer reopened via "Find Other Ustaad". False for ordinary
  /// Standard/Inspection direct-assign jobs.
  final bool isOpenForBidding;
  /// Server-authoritative seconds remaining before this worker's existing
  /// bid on this job can be resubmitted/updated. 0 when no bid yet or no
  /// cooldown active.
  final int myBidCooldownRemainingSeconds;

  const NewJobEntity({
    required this.id,
    this.title,
    this.description,
    required this.status,
    required this.urgency,
    this.timeSlot,
    this.addressLine,
    required this.city,
    required this.latitude,
    required this.longitude,
    this.scheduledAt,
    required this.createdAt,
    required this.category,
    required this.client,
    required this.bidCount,
    this.distanceKm,
    this.hasMyBid = false,
    this.workerProfileId,
    this.inspection = false,
    this.lane = BookingLane.bidding,
    this.standardServiceItems = const [],
    this.inspectionFeeSnapshot,
    this.isOpenForBidding = false,
    this.myBidCooldownRemainingSeconds = 0,
  });

  bool get isStandardLane => lane == BookingLane.standard;
  bool get isInspectionLane => lane == BookingLane.inspection;
  /// True for a direct-assignment job that ISN'T open for bidding — ordinary
  /// STANDARD, or an INSPECTION job still in its normal (non-reopened) state.
  /// An INSPECTION job the customer reopened via "Find Other Ustaad" is
  /// bid-actionable, so it's deliberately excluded here.
  bool get isDirectAssignLane =>
      isStandardLane || (isInspectionLane && !isOpenForBidding);

  double get standardServicesTotal => standardServiceItems.fold<double>(
        0,
        (sum, item) => sum + item.lineTotal,
      );

  /// The single canonical price for this not-yet-hired job — reuses
  /// [canonicalWorkPrice] (same rule BookingEntity uses) with the hire-time
  /// fields (acceptedBidAmount, finalPrice, inspectionDecisionStatus) left
  /// null, since a New Jobs card is always a PENDING, not-yet-assigned
  /// booking. STANDARD shows the fixed catalog total, INSPECTION shows the
  /// fee, BIDDING is always null (no fixed price before a bid is accepted) —
  /// callers must hide the price UI entirely in that case, never show Rs 0
  /// or "Bid: No".
  double? get displayPrice => canonicalWorkPrice(
        lane: lane,
        inspectionDecisionStatus: null,
        standardServicesTotal: standardServicesTotal,
        inspectionFeeSnapshot: inspectionFeeSnapshot,
      );

  String get displayTitle => title?.isNotEmpty == true ? title! : category.name;


  /// True while the job is still open for bids — nobody has taken it yet.
  /// The user-facing label is built in the presentation layer by
  /// `newJobStatusLabel`, since what it reads depends on the chosen language.
  bool get hasAssignedWorker => workerProfileId != null;
}
