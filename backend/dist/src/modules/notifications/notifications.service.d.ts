import { FirebaseService } from '../../firebase/firebase.service';
import { NotificationsRepository } from './notifications.repository';
export interface NotifyOptions {
    userId: string;
    eventKey: string;
    title: string;
    body: string;
    bookingId?: string;
    route?: string;
    actorUserId?: string;
    actorRole?: string;
    entityType?: string;
    entityId?: string;
    payload?: Record<string, unknown>;
}
export declare class NotificationsService {
    private readonly notificationsRepository;
    private readonly firebase;
    private readonly logger;
    constructor(notificationsRepository: NotificationsRepository, firebase: FirebaseService);
    notify(options: NotifyOptions): Promise<void>;
    private _sendPush;
    getNotifications(userId: string): Promise<{
        id: string;
        createdAt: Date;
        title: string;
        body: string;
        data: import("@prisma/client/runtime/library").JsonValue | null;
        userId: string;
        bookingId: string | null;
        isRead: boolean;
        readAt: Date | null;
        eventKey: string | null;
        entityType: string | null;
        entityId: string | null;
        actorUserId: string | null;
        actorRole: string | null;
        route: string | null;
        payload: import("@prisma/client/runtime/library").JsonValue | null;
    }[]>;
    markRead(id: string): Promise<{
        id: string;
        createdAt: Date;
        title: string;
        body: string;
        data: import("@prisma/client/runtime/library").JsonValue | null;
        userId: string;
        bookingId: string | null;
        isRead: boolean;
        readAt: Date | null;
        eventKey: string | null;
        entityType: string | null;
        entityId: string | null;
        actorUserId: string | null;
        actorRole: string | null;
        route: string | null;
        payload: import("@prisma/client/runtime/library").JsonValue | null;
    }>;
    markAllRead(userId: string): Promise<import(".prisma/client").Prisma.BatchPayload>;
    getUnreadCount(userId: string): Promise<number>;
}
