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
  });
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
