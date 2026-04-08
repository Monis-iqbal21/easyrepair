export declare const NOTIFICATION_KEYS: {
    readonly BOOKING_ASSIGNED: "booking.assigned";
    readonly BOOKING_STATUS_EN_ROUTE: "booking.status.en_route";
    readonly BOOKING_STATUS_IN_PROGRESS: "booking.status.in_progress";
    readonly BOOKING_COMPLETED: "booking.completed";
    readonly BOOKING_CANCELLED_BY_CLIENT: "booking.cancelled.by_client";
    readonly BOOKING_CANCELLED_BY_WORKER: "booking.cancelled.by_worker";
    readonly BOOKING_REVIEW_CREATED: "booking.review.created";
    readonly WORKER_VERIFIED: "worker.verified";
};
export type NotificationKey = (typeof NOTIFICATION_KEYS)[keyof typeof NOTIFICATION_KEYS];
export declare function getNotificationTemplate(eventKey: NotificationKey, params?: Record<string, string | number>): {
    title: string;
    body: string;
};
