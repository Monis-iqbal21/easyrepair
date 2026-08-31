/// Mirrors backend `CommissionStatus` — belongs to the individual job, not
/// to the whole Worker account (see WorkersRepository.getEarningsHistory).
enum CommissionStatus { pending, paid }

class EarningHistoryJobEntity {
  final String bookingId;
  final String lane;
  final String serviceCategory;
  final double grossEarning;

  /// HandyGo commission computed backend-side. Null means it was not sent.
  final double? commissionAmount;

  /// What the Ustaad keeps, computed backend-side. Null means it was not sent.
  final double? ustaadEarning;
  /// Cash the client actually handed over, per the job's settlement. Null
  /// until a settlement exists — deliberately not 0, since "not settled yet"
  /// and "paid nothing" are different answers.
  ///
  /// [commissionAmount] and [ustaadEarning] follow the same record once it
  /// exists, so a short-paid job never shows the earning it was quoted at.
  final double? receivedAmount;

  /// Still owed by the client. Null until settled, 0 when paid in full.
  final double? shortfall;
  final CommissionStatus commissionStatus;
  final DateTime completedAt;
  final bool isInspectionOnly;

  const EarningHistoryJobEntity({
    required this.bookingId,
    required this.lane,
    required this.serviceCategory,
    required this.grossEarning,
    required this.commissionAmount,
    required this.ustaadEarning,
    required this.commissionStatus,
    required this.completedAt,
    required this.isInspectionOnly,
    this.receivedAmount,
    this.shortfall,
  });

  /// The client paid less than this job was worth. Straight off the server's
  /// own shortfall — never `grossEarning - receivedAmount` computed here.
  bool get isShortPaid => (shortfall ?? 0) > 0;
}

class EarningHistoryDayEntity {
  final DateTime date;
  final double grossTotal;
  final int jobsCount;
  final List<EarningHistoryJobEntity> jobs;

  const EarningHistoryDayEntity({
    required this.date,
    required this.grossTotal,
    required this.jobsCount,
    required this.jobs,
  });
}
