class CashPaymentConfirmationEntity {
  final String settlementId;
  final String bookingId;
  final int receivedCashTotal;
  final int expectedTotal;
  final int shortfall;
  final DateTime recordedAt;
  final String confirmationStatus;
  final bool isCurrent;

  const CashPaymentConfirmationEntity({
    required this.settlementId,
    required this.bookingId,
    required this.receivedCashTotal,
    required this.expectedTotal,
    required this.shortfall,
    required this.recordedAt,
    required this.confirmationStatus,
    required this.isCurrent,
  });
}
