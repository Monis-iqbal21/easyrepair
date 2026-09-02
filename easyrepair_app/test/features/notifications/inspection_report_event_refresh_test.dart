import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/features/notifications/presentation/utils/notification_event_refresh.dart';

void main() {
  for (final eventKey in ['payment.short', 'payment.received']) {
    test('$eventKey refreshes worker settlement truth immediately', () {
      final targets = notificationRefreshTargets(
        eventKey,
        isWorker: true,
        hasBookingId: true,
      );

      expect(
        targets,
        containsAll({
          NotificationRefreshTarget.workerJobs,
          NotificationRefreshTarget.workerJobDetail,
        }),
      );
    });
  }

  test(
    'report-ready event refreshes booking and authoritative report state',
    () {
      final targets = notificationRefreshTargets(
        'booking.inspection.report_submitted',
        isWorker: false,
        hasBookingId: true,
      );

      expect(
        targets,
        containsAll({
          NotificationRefreshTarget.bookings,
          NotificationRefreshTarget.bookingDetail,
          NotificationRefreshTarget.inspectionReport,
        }),
      );
    },
  );

  test(
    'report-ready event without a booking id never invalidates a family',
    () {
      final targets = notificationRefreshTargets(
        'booking.inspection.report_submitted',
        isWorker: false,
        hasBookingId: false,
      );

      expect(targets, {NotificationRefreshTarget.bookings});
    },
  );
}
