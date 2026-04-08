"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.NOTIFICATION_KEYS = void 0;
exports.getNotificationTemplate = getNotificationTemplate;
exports.NOTIFICATION_KEYS = {
    BOOKING_ASSIGNED: 'booking.assigned',
    BOOKING_STATUS_EN_ROUTE: 'booking.status.en_route',
    BOOKING_STATUS_IN_PROGRESS: 'booking.status.in_progress',
    BOOKING_COMPLETED: 'booking.completed',
    BOOKING_CANCELLED_BY_CLIENT: 'booking.cancelled.by_client',
    BOOKING_CANCELLED_BY_WORKER: 'booking.cancelled.by_worker',
    BOOKING_REVIEW_CREATED: 'booking.review.created',
    WORKER_VERIFIED: 'worker.verified',
};
function getNotificationTemplate(eventKey, params) {
    switch (eventKey) {
        case exports.NOTIFICATION_KEYS.BOOKING_ASSIGNED:
            return {
                title: 'New Job Assigned',
                body: "You've been assigned to a new job. Tap to view details.",
            };
        case exports.NOTIFICATION_KEYS.BOOKING_STATUS_EN_ROUTE:
            return {
                title: 'Worker On the Way',
                body: 'Your worker is on the way to your location.',
            };
        case exports.NOTIFICATION_KEYS.BOOKING_STATUS_IN_PROGRESS:
            return {
                title: 'Job Started',
                body: 'Your worker has started working on your request.',
            };
        case exports.NOTIFICATION_KEYS.BOOKING_COMPLETED:
            return {
                title: 'Job Completed',
                body: 'Your worker has completed the job. Please leave a review.',
            };
        case exports.NOTIFICATION_KEYS.BOOKING_CANCELLED_BY_CLIENT:
            return {
                title: 'Job Cancelled',
                body: 'The client has cancelled the job.',
            };
        case exports.NOTIFICATION_KEYS.BOOKING_CANCELLED_BY_WORKER:
            return {
                title: 'Job Cancelled',
                body: 'The worker has cancelled the job.',
            };
        case exports.NOTIFICATION_KEYS.BOOKING_REVIEW_CREATED:
            return {
                title: 'New Review',
                body: params?.rating
                    ? `Your client left you a ${params.rating}-star review.`
                    : 'Your client left you a review.',
            };
        case exports.NOTIFICATION_KEYS.WORKER_VERIFIED:
            return {
                title: 'Account Verified',
                body: 'Your worker account has been verified. You can now go online and accept jobs.',
            };
        default:
            return { title: 'EasyRepair', body: 'You have a new notification.' };
    }
}
//# sourceMappingURL=notification-templates.js.map