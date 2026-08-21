import '../../domain/entities/cash_payment_confirmation_entity.dart';

class CashPaymentConfirmationModel {
  final String settlementId;
  final String bookingId;
  final int receivedCashTotal;
  final int expectedTotal;
  final int shortfall;
  final DateTime recordedAt;
  final String confirmationStatus;
  final bool isCurrent;

  const CashPaymentConfirmationModel({
    required this.settlementId,
    required this.bookingId,
    required this.receivedCashTotal,
    required this.expectedTotal,
    required this.shortfall,
    required this.recordedAt,
    required this.confirmationStatus,
    required this.isCurrent,
  });

  factory CashPaymentConfirmationModel.fromJson(Map<String, dynamic> json) {
    return CashPaymentConfirmationModel(
      settlementId: json['settlementId'] as String,
      bookingId: json['bookingId'] as String,
      receivedCashTotal: (json['receivedCashTotal'] as num).toInt(),
      expectedTotal: (json['expectedTotal'] as num).toInt(),
      shortfall: (json['shortfall'] as num).toInt(),
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      confirmationStatus: json['confirmationStatus'] as String,
      isCurrent: json['isCurrent'] as bool,
    );
  }

  CashPaymentConfirmationEntity toEntity() => CashPaymentConfirmationEntity(
        settlementId: settlementId,
        bookingId: bookingId,
        receivedCashTotal: receivedCashTotal,
        expectedTotal: expectedTotal,
        shortfall: shortfall,
        recordedAt: recordedAt,
        confirmationStatus: confirmationStatus,
        isCurrent: isCurrent,
      );
}
