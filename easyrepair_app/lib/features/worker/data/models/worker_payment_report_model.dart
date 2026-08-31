import '../../domain/entities/worker_payment_report_entity.dart';

/// Wire shape of `POST /workers/jobs/:bookingId/report-payment`.
/// Mirrors UstaadPaymentReportDto — see backend
/// `modules/workers/dto/report-received-payment.dto.ts`.
class WorkerPaymentReportModel {
  final String settlementId;
  final String bookingId;
  final double expectedTotal;
  final double receivedCashTotal;
  final double partsPaid;
  final double labourPaid;
  final double feePaid;
  final double commission;
  final double munafa;
  final double shortfall;

  const WorkerPaymentReportModel({
    required this.settlementId,
    required this.bookingId,
    required this.expectedTotal,
    required this.receivedCashTotal,
    required this.partsPaid,
    required this.labourPaid,
    required this.feePaid,
    required this.commission,
    required this.munafa,
    required this.shortfall,
  });

  factory WorkerPaymentReportModel.fromJson(Map<String, dynamic> json) {
    double num_(String key) => (json[key] as num?)?.toDouble() ?? 0;
    return WorkerPaymentReportModel(
      settlementId: json['settlementId'] as String? ?? '',
      bookingId: json['bookingId'] as String? ?? '',
      expectedTotal: num_('expectedTotal'),
      receivedCashTotal: num_('receivedCashTotal'),
      partsPaid: num_('partsPaid'),
      labourPaid: num_('labourPaid'),
      feePaid: num_('feePaid'),
      commission: num_('commission'),
      munafa: num_('munafa'),
      shortfall: num_('shortfall'),
    );
  }

  WorkerPaymentReportEntity toEntity() => WorkerPaymentReportEntity(
    expectedTotal: expectedTotal,
    receivedCashTotal: receivedCashTotal,
    partsPaid: partsPaid,
    labourPaid: labourPaid,
    feePaid: feePaid,
    commission: commission,
    munafa: munafa,
    shortfall: shortfall,
  );
}
