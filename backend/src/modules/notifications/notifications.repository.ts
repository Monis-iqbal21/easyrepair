import { Injectable } from '@nestjs/common';
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

@Injectable()
export class NotificationsRepository {
  constructor(private readonly prisma: PrismaService) {}

  async create(data: CreateNotificationData) {
    return this.prisma.notification.create({
      data: {
        userId: data.userId,
        title: data.title,
        body: data.body,
        eventKey: data.eventKey,
        entityType: data.entityType,
        entityId: data.entityId,
        bookingId: data.bookingId,
        actorUserId: data.actorUserId,
        actorRole: data.actorRole,
        route: data.route,
        payload: data.payload
          ? (data.payload as Prisma.InputJsonValue)
          : undefined,
      },
    });
  }

  async findByUserId(userId: string, limit = 50) {
    return this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
  }

  async markRead(id: string) {
    return this.prisma.notification.update({
      where: { id },
      data: { isRead: true, readAt: new Date() },
    });
  }

  async markAllRead(userId: string) {
    return this.prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true, readAt: new Date() },
    });
  }

  async countUnread(userId: string): Promise<number> {
    return this.prisma.notification.count({
      where: { userId, isRead: false },
    });
  }

  async findUserFcmToken(userId: string): Promise<string | null> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { fcmToken: true },
    });
    return user?.fcmToken ?? null;
  }
}
