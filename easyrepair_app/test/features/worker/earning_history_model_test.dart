import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/features/worker/data/models/earning_history_model.dart';

void main() {
  const baseJson = {
    'bookingId': 'job-X',
    'lane': 'STANDARD',
    'serviceCategory': 'AC Repair',
    'grossEarning': 2000,
    'commissionStatus': 'PENDING',
    'completedAt': '2026-08-01T09:00:00.000Z',
    'isInspectionOnly': false,
  };

  group('EarningHistoryJobModel.fromJson', () {
    test('missing commission remains unknown', () {
      final model = EarningHistoryJobModel.fromJson(baseJson);
      expect(model.commissionAmount, isNull);
      expect(model.commissionAmount, isNot(360.0));
    });

    test('missing profit remains unknown', () {
      final model = EarningHistoryJobModel.fromJson({
        ...baseJson,
        'commissionAmount': 360,
      });
      expect(model.ustaadEarning, isNull);
      expect(model.ustaadEarning, isNot(1640.0));
    });

    test('real zero values are preserved', () {
      final model = EarningHistoryJobModel.fromJson({
        ...baseJson,
        'commissionAmount': 0,
        'ustaadEarning': 2000,
        'isInspectionOnly': true,
      });
      expect(model.commissionAmount, 0.0);
      expect(model.ustaadEarning, 2000.0);
    });

    test('server values are used exactly as sent', () {
      final model = EarningHistoryJobModel.fromJson({
        ...baseJson,
        'commissionAmount': 360,
        'ustaadEarning': 1640,
      });
      expect(model.commissionAmount, 360.0);
      expect(model.ustaadEarning, 1640.0);
    });

    test('entity preserves missing financial values', () {
      final entity = EarningHistoryJobModel.fromJson(baseJson).toEntity();
      expect(entity.commissionAmount, isNull);
      expect(entity.ustaadEarning, isNull);
    });
  });
}
