import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
export interface CreateNotificationData {
    userId: string;
    title: string;
    body: string;
    eventKey?: string;
    entityType?: string;
    entityId?: string;
    bookingId?: string;
    actorUserId?: string;
    actorRole?: string;
    route?: string;
    payload?: Record<string, unknown>;
}
export declare class NotificationsRepository {
    private readonly prisma;
    constructor(prisma: PrismaService);
    create(data: CreateNotificationData): Promise<{
        id: string;
        createdAt: Date;
        title: string;
        body: string;
        data: Prisma.JsonValue | null;
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
        payload: Prisma.JsonValue | null;
    }>;
    findByUserId(userId: string, limit?: number): Promise<{
        id: string;
        createdAt: Date;
        title: string;
        body: string;
        data: Prisma.JsonValue | null;
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
        payload: Prisma.JsonValue | null;
    }[]>;
    markRead(id: string): Promise<{
        id: string;
        createdAt: Date;
        title: string;
        body: string;
        data: Prisma.JsonValue | null;
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
        payload: Prisma.JsonValue | null;
    }>;
    markAllRead(userId: string): Promise<Prisma.BatchPayload>;
    countUnread(userId: string): Promise<number>;
    findUserFcmToken(userId: string): Promise<string | null>;
}
