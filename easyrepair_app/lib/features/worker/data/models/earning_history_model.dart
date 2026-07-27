import '../../domain/entities/earning_history_entity.dart';

class EarningHistoryJobModel {
  final String bookingId;
  final String lane;
  final String serviceCategory;
  final double grossEarning;
  final DateTime completedAt;
  final bool isInspectionOnly;

  const EarningHistoryJobModel({
    required this.bookingId,
    required this.lane,
    required this.serviceCategory,
    required this.grossEarning,
    required this.completedAt,
    required this.isInspectionOnly,
  });

  factory EarningHistoryJobModel.fromJson(Map<String, dynamic> json) {
    return EarningHistoryJobModel(
      bookingId: json['bookingId'] as String,
      lane: json['lane'] as String? ?? 'STANDARD',
      serviceCategory: json['serviceCategory'] as String? ?? 'Service',
      grossEarning: (json['grossEarning'] as num?)?.toDouble() ?? 0.0,
      completedAt:
          DateTime.tryParse(json['completedAt'] as String? ?? '') ??
              DateTime.now(),
      isInspectionOnly: json['isInspectionOnly'] as bool? ?? false,
    );
  }

  EarningHistoryJobEntity toEntity() => EarningHistoryJobEntity(
        bookingId: bookingId,
        lane: lane,
        serviceCategory: serviceCategory,
        grossEarning: grossEarning,
        completedAt: completedAt,
        isInspectionOnly: isInspectionOnly,
      );
}

class EarningHistoryDayModel {
  final String date;
  final double grossTotal;
  final int jobsCount;
  final List<EarningHistoryJobModel> jobs;

  const EarningHistoryDayModel({
    required this.date,
    required this.grossTotal,
    required this.jobsCount,
    required this.jobs,
  });

  factory EarningHistoryDayModel.fromJson(Map<String, dynamic> json) {
    final rawJobs = (json['jobs'] as List<dynamic>? ?? []);
    return EarningHistoryDayModel(
      date: json['date'] as String,
      grossTotal: (json['grossTotal'] as num?)?.toDouble() ?? 0.0,
      jobsCount: json['jobsCount'] as int? ?? 0,
      jobs: rawJobs
          .map((e) =>
              EarningHistoryJobModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  EarningHistoryDayEntity toEntity() => EarningHistoryDayEntity(
        date: DateTime.tryParse(date) ?? DateTime.now(),
        grossTotal: grossTotal,
        jobsCount: jobsCount,
        jobs: jobs.map((j) => j.toEntity()).toList(),
      );
}
