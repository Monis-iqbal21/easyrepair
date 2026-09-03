/// Provider groups that must be invalidated for a notification event.
///
/// This mapping is deliberately pure so the socket and FCM delivery paths
/// cannot drift, and so event-to-refresh behaviour can be tested without
/// booting Firebase or a Socket.IO connection.
enum NotificationRefreshTarget {
  conversations,
  bookings,
  bookingDetail,
  inspectionReport,
  complaint,
  workerJobs,
  workerJobDetail,
  newJobs,
  workerProfile,
}

const _newJobEventKeys = {
  'new_job',
  'booking.standard.worker_listed',
  'booking.inspection.available',
  'booking.bidding.available',
  'booking.inspection.find_other_ustaad_available',
};

const _assignedJobEventKeys = {'booking.assigned', 'bid.accepted'};

const _clientLiveSyncEventKeys = {
  'booking.status.en_route',
  'booking.status.arrived',
  'booking.status.in_progress',
  'booking.inspection.report_submitted',
  'booking.completed',
  'booking.cancelled.by_worker',
};

const _complaintStatusEventKeys = {
  'complaint.status.in_progress',
  'complaint.status.resolved',
  'complaint.status.closed',
};

const _workerLiveSyncEventKeys = {
  'booking.cancelled.by_client',
  'booking.inspection.quote_accepted',
  'booking.inspection.closed',
  'booking.review.created',
  'payment.received',
  'payment.short',
};

Set<NotificationRefreshTarget> notificationRefreshTargets(
  String? eventKey, {
  required bool isWorker,
  required bool hasBookingId,
}) {
  if (eventKey == 'chat.message') {
    return const {NotificationRefreshTarget.conversations};
  }
  if (isWorker) {
    if (_newJobEventKeys.contains(eventKey)) {
      return const {NotificationRefreshTarget.newJobs};
    }
    if (_assignedJobEventKeys.contains(eventKey)) {
      return {
        NotificationRefreshTarget.workerJobs,
        NotificationRefreshTarget.newJobs,
        NotificationRefreshTarget.workerProfile,
        if (hasBookingId) NotificationRefreshTarget.workerJobDetail,
      };
    }
    if (_workerLiveSyncEventKeys.contains(eventKey)) {
      return {
        NotificationRefreshTarget.workerJobs,
        if (hasBookingId) NotificationRefreshTarget.workerJobDetail,
        if (eventKey == 'booking.review.created')
          NotificationRefreshTarget.workerProfile,
      };
    }
    return const {};
  }

  if (_complaintStatusEventKeys.contains(eventKey)) {
    return {
      if (hasBookingId) NotificationRefreshTarget.complaint,
      if (hasBookingId) NotificationRefreshTarget.bookingDetail,
    };
  }
  if (_clientLiveSyncEventKeys.contains(eventKey)) {
    return {
      NotificationRefreshTarget.bookings,
      if (hasBookingId) NotificationRefreshTarget.bookingDetail,
      if (hasBookingId && eventKey == 'booking.inspection.report_submitted')
        NotificationRefreshTarget.inspectionReport,
    };
  }
  return const {};
}
