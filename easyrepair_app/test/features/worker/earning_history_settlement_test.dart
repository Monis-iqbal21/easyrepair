import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/features/worker/data/models/earning_history_model.dart';

/// FIX 1, Earning History side — a short-paid job must not still show the
/// earning it was quoted at. The server sends the settlement's own numbers;
/// this app only has to carry them, and to keep "not settled yet" distinct
/// from "settled at zero".
void main() {
  Map<String, dynamic> job(Map<String, dynamic> extra) => {
    'bookingId': 'job-1',
    'lane': 'INSPECTION',
    'serviceCategory': 'AC Technician',
    'grossEarning': 2700,
    'commissionAmount': 144,
    'ustaadEarning': 656,
    'commissionStatus': 'PENDING',
    'completedAt': '2026-08-30T10:00:00.000Z',
    'isInspectionOnly': false,
    ...extra,
  };

  test('a settled short payment carries received, shortfall and the split', () {
    final entity = EarningHistoryJobModel.fromJson(
      job({'receivedAmount': 2500, 'shortfall': 200}),
    ).toEntity();

    expect(entity.receivedAmount, 2500);
    expect(entity.shortfall, 200);
    expect(entity.isShortPaid, isTrue);
    // The quote stays visible beside the truth, never instead of it.
    expect(entity.grossEarning, 2700);
    // 18% of the 2700 quote would be 486 / 2214 — the old, wrong pair.
    expect(entity.commissionAmount, 144);
    expect(entity.ustaadEarning, 656);
  });

  test('a job paid in full is not flagged short', () {
    final entity = EarningHistoryJobModel.fromJson(
      job({
        'receivedAmount': 2700,
        'shortfall': 0,
        'commissionAmount': 180,
        'ustaadEarning': 820,
      }),
    ).toEntity();

    expect(entity.isShortPaid, isFalse);
    expect(entity.receivedAmount, 2700);
  });

  test('an unsettled job reports null, never a fabricated zero', () {
    final entity = EarningHistoryJobModel.fromJson(job({})).toEntity();

    expect(entity.receivedAmount, isNull);
    expect(entity.shortfall, isNull);
    expect(entity.isShortPaid, isFalse);
  });

  test('a settled zero-cash job is short, not unsettled', () {
    final entity = EarningHistoryJobModel.fromJson(
      job({
        'receivedAmount': 0,
        'shortfall': 2700,
        'commissionAmount': 0,
        'ustaadEarning': 0,
      }),
    ).toEntity();

    expect(entity.receivedAmount, 0);
    expect(entity.isShortPaid, isTrue);
  });
}
