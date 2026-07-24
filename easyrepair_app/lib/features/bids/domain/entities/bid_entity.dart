enum BidStatus { pending, accepted, rejected }

extension BidStatusX on BidStatus {
  String get raw => switch (this) {
        BidStatus.pending => 'PENDING',
        BidStatus.accepted => 'ACCEPTED',
        BidStatus.rejected => 'REJECTED',
      };

  static BidStatus fromRaw(String raw) => switch (raw.toUpperCase()) {
        'ACCEPTED' => BidStatus.accepted,
        'REJECTED' => BidStatus.rejected,
        _ => BidStatus.pending,
      };
}

class BidEntity {
  final String id;
  final String bookingId;
  final String workerProfileId;
  final double amount;
  final String? message;
  final BidStatus status;
  final int editCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  /// Server-authoritative seconds remaining before this bid can be
  /// resubmitted/updated — only populated by the "my bid" lookup; 0 elsewhere.
  final int cooldownRemainingSeconds;

  const BidEntity({
    required this.id,
    required this.bookingId,
    required this.workerProfileId,
    required this.amount,
    this.message,
    required this.status,
    required this.editCount,
    required this.createdAt,
    required this.updatedAt,
    this.cooldownRemainingSeconds = 0,
  });

  /// True when the worker can still edit (only one edit allowed after submit).
  bool get canEdit => editCount == 0;
}
