import '../../../bookings/domain/entities/booking_entity.dart';

class OngoingJobEntity {
  final String id;
  final String? title;
  final String categoryName;
  final String clientArea;
  final String addressLine;
  final String status;
  final String lane;
  final double? finalPrice;
  final double? acceptedBidAmount;
  final double? inspectionFeeSnapshot;
  final double? standardServicesTotal;
  final String? inspectionDecisionStatusRaw;

  const OngoingJobEntity({
    required this.id,
    this.title,
    required this.categoryName,
    required this.clientArea,
    required this.addressLine,
    required this.status,
    this.lane = 'STANDARD',
    this.finalPrice,
    this.acceptedBidAmount,
    this.inspectionFeeSnapshot,
    this.standardServicesTotal,
    this.inspectionDecisionStatusRaw,
  });

  // The visible label is built by ongoingJobStatusLabel() in
  // presentation/utils/worker_labels.dart; `status` stays the backend token.

  /// The exact price this worker was hired for — same canonicalWorkPrice
  /// rule BookingEntity.canonicalPrice uses, so the Home dashboard's Active
  /// Job card can never disagree with My Jobs or Track Worker for the same
  /// work unit. Null only for a still-open BIDDING job, which cannot
  /// actually reach this card (it only lists jobs already assigned to this
  /// worker) — handled defensively rather than assumed unreachable.
  double? get displayPrice => canonicalWorkPrice(
        lane: BookingLaneX.fromRaw(lane),
        inspectionDecisionStatus:
            InspectionDecisionStatusX.fromRaw(inspectionDecisionStatusRaw),
        standardServicesTotal: standardServicesTotal,
        inspectionFeeSnapshot: inspectionFeeSnapshot,
        acceptedBidAmount: acceptedBidAmount,
        finalPrice: finalPrice,
      );
}
