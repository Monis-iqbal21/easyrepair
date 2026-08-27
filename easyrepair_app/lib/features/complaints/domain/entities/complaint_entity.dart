enum ComplaintIssueType {
  workQuality('WORK_QUALITY'),
  pricePayment('PRICE_PAYMENT'),
  ustaadBehaviour('USTAAD_BEHAVIOUR'),
  damage('DAMAGE'),
  partMaterial('PART_MATERIAL'),
  warrantyRework('WARRANTY_REWORK'),
  other('OTHER');

  const ComplaintIssueType(this.apiValue);

  final String apiValue;

  static ComplaintIssueType? fromApi(String value) {
    for (final issue in values) {
      if (issue.apiValue == value.toUpperCase()) return issue;
    }
    return null;
  }
}

enum ComplaintStatus {
  open,
  inProgress,
  waitingOnCustomer,
  resolved,
  closed;

  static ComplaintStatus fromApi(String? value) => switch (value?.toUpperCase()) {
        'IN_PROGRESS' => ComplaintStatus.inProgress,
        'WAITING_ON_CUSTOMER' => ComplaintStatus.waitingOnCustomer,
        'RESOLVED' => ComplaintStatus.resolved,
        'CLOSED' => ComplaintStatus.closed,
        _ => ComplaintStatus.open,
      };
}

class ComplaintEntity {
  const ComplaintEntity({
    required this.id,
    required this.bookingId,
    required this.issueTypes,
    required this.status,
    required this.source,
    required this.humanRequested,
    required this.createdAt,
    required this.updatedAt,
    this.reporterUserId,
    this.reportedWorkerProfileId,
    this.otherText,
    this.humanRequestedAt,
    this.resolvedAt,
  });

  final String id;
  final String? bookingId;
  final String? reporterUserId;
  final String? reportedWorkerProfileId;
  final List<ComplaintIssueType> issueTypes;
  final String? otherText;
  final String source;
  final ComplaintStatus status;
  final bool humanRequested;
  final DateTime? humanRequestedAt;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  ComplaintEntity copyWith({
    bool? humanRequested,
    DateTime? humanRequestedAt,
    ComplaintStatus? status,
  }) {
    return ComplaintEntity(
      id: id,
      bookingId: bookingId,
      reporterUserId: reporterUserId,
      reportedWorkerProfileId: reportedWorkerProfileId,
      issueTypes: issueTypes,
      otherText: otherText,
      source: source,
      status: status ?? this.status,
      humanRequested: humanRequested ?? this.humanRequested,
      humanRequestedAt: humanRequestedAt ?? this.humanRequestedAt,
      resolvedAt: resolvedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
