/// The server's answer to "kam paisa mila" — every field computed by
/// `settleBooking` on the backend.
///
/// The Ustaad app sends one fact (the cash actually received) and renders what
/// comes back. It never derives a commission, an earning or a shortfall of its
/// own: HandyGo's 18% applies to the labour ACTUALLY received, and getting that
/// waterfall subtly wrong on a device would show an Ustaad the wrong money.
class WorkerPaymentReportEntity {
  /// The whole payable total: parts + labour + inspection fee.
  final double expectedTotal;

  /// The cash the Ustaad declared.
  final double receivedCashTotal;

  /// Server allocation of that cash, paid in waterfall order.
  final double partsPaid;
  final double labourPaid;
  final double feePaid;

  /// HandyGo's 18% of [labourPaid] — never of parts, never of the fee.
  final double commission;

  /// What the Ustaad keeps.
  final double munafa;

  /// Still owed by the client; 0 when the job was paid in full.
  final double shortfall;

  const WorkerPaymentReportEntity({
    required this.expectedTotal,
    required this.receivedCashTotal,
    required this.partsPaid,
    required this.labourPaid,
    required this.feePaid,
    required this.commission,
    required this.munafa,
    required this.shortfall,
  });

  bool get isShort => shortfall > 0;
}
