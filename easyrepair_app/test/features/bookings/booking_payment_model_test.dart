import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/features/bookings/data/models/booking_model.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';

Map<String, dynamic> _json({
  String paymentDisplayStatus = 'UNPAID',
  num? receivedAmount,
  num? expectedAmount,
  num? remainingAmount,
}) {
  return {
    'id': 'booking-123456',
    'serviceCategory': 'AC Technician',
    'description': 'AC issue',
    'status': 'COMPLETED',
    'urgency': 'NORMAL',
    'createdAt': '2026-08-26T00:00:00.000Z',
    'paymentDisplayStatus': paymentDisplayStatus,
    'receivedAmount': receivedAmount,
    'expectedAmount': expectedAmount,
    'remainingAmount': remainingAmount,
  };
}

void main() {
  test('maps the server-derived payment summary without recalculation', () {
    final entity = BookingModel.fromJson(
      _json(
        paymentDisplayStatus: 'PARTIAL',
        receivedAmount: 400,
        expectedAmount: 1000,
        remainingAmount: 600,
      ),
    ).toEntity();

    expect(entity.paymentDisplayStatus, PaymentDisplayStatus.partial);
    expect(entity.receivedAmount, 400);
    expect(entity.expectedAmount, 1000);
    expect(entity.remainingAmount, 600);
  });

  test('legacy payloads safely default to UNPAID with no invented amounts', () {
    final json = _json()..remove('paymentDisplayStatus');
    final entity = BookingModel.fromJson(json).toEntity();

    expect(entity.paymentDisplayStatus, PaymentDisplayStatus.unpaid);
    expect(entity.receivedAmount, isNull);
    expect(entity.expectedAmount, isNull);
    expect(entity.remainingAmount, isNull);
  });
}
