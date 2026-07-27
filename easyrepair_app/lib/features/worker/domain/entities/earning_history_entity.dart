class EarningHistoryJobEntity {
  final String bookingId;
  final String lane;
  final String serviceCategory;
  final double grossEarning;
  final DateTime completedAt;
  final bool isInspectionOnly;

  const EarningHistoryJobEntity({
    required this.bookingId,
    required this.lane,
    required this.serviceCategory,
    required this.grossEarning,
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
