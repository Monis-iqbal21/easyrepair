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
  complaintEventId?: string;
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
        complaintEventId: data.complaintEventId,
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

  /**
   * Removes a permanently-invalid FCM token (Firebase reported it
   * unregistered/invalid — e.g. after app uninstall) from whichever User row
   * currently holds it. Cleanup only — never the Worker-availability
   * mechanism, which is driven exclusively by the presence lease
   * (WORKER_PRESENCE_STALE_MS), not by push delivery failures.
   */
  async clearFcmTokenByValue(token: string): Promise<void> {
    await this.prisma.user.updateMany({
      where: { fcmToken: token },
      data: { fcmToken: null },
    });
  }

  /**
   * Check whether a notification with this exact eventKey/bookingId/userId
   * combination was already sent — used to dedupe repeated-poll notifications
   * (e.g. "worker listed for STANDARD job" firing on every nearby-workers
   * refresh instead of once per booking/worker pair).
   */
  async existsForBookingAndUser(
    userId: string,
    bookingId: string,
    eventKey: string,
  ): Promise<boolean> {
    const found = await this.prisma.notification.findFirst({
      where: { userId, bookingId, eventKey },
      select: { id: true },
    });
    return found !== null;
  }

  /**
   * Same triple as existsForBookingAndUser, but scoped to the booking's
   * CURRENT live cycle via [since] (its `liveStartedAt`).
   *
   * The unbounded variant above permanently silences a worker for a booking,
   * which is wrong for broadcasts: a booking that is later reopened (worker
   * cancelled) or relisted ("Make Live Again") starts a genuinely new live
   * window and its previously-notified eligible workers must be reachable
   * again. Scoping to `createdAt >= liveStartedAt` gives exactly one
   * notification per worker per booking PER CYCLE — so leaving and re-entering
   * the radius within one cycle still never re-notifies.
   */
  async existsForBookingAndUserSince(
    userId: string,
    bookingId: string,
    eventKey: string,
    since: Date,
  ): Promise<boolean> {
    const found = await this.prisma.notification.findFirst({
      where: { userId, bookingId, eventKey, createdAt: { gte: since } },
      select: { id: true },
    });
    return found !== null;
  }

  /**
   * BATCHED form of the two checks above: given a chunk of recipient userIds,
   * returns the subset that has ALREADY been notified about this
   * booking/eventKey (optionally scoped to the booking's current live cycle
   * via [since]).
   *
   * Semantically identical to calling existsForBookingAndUser(Since) once per
   * user — same predicate, same cycle scoping — but the broadcast fan-out
   * needs it for every eligible worker, and one query per worker does not
   * scale. Persistence semantics are untouched; this is a read-side batch
   * only.
   */
  async findNotifiedUserIds(
    userIds: string[],
    bookingId: string,
    eventKey: string,
    since: Date | null,
  ): Promise<Set<string>> {
    if (userIds.length === 0) return new Set();
    const rows = await this.prisma.notification.findMany({
      where: {
        bookingId,
        eventKey,
        userId: { in: userIds },
        ...(since ? { createdAt: { gte: since } } : {}),
      },
      select: { userId: true },
      distinct: ['userId'],
    });
    return new Set(rows.map((r) => r.userId));
  }

  /**
   * Mirror of findNotifiedUserIds for the other fan-out shape: ONE recipient,
   * MANY bookings sharing an eventKey (late discovery / reconcile).
   *
   * Returns bookingId → most recent notification time, so the caller can apply
   * each booking's own `liveStartedAt` cycle boundary in memory. That yields
   * exactly the same answer as one existsForBookingAndUser(Since) call per
   * booking, in a single query.
   */
  async findLatestNotifiedAtByBooking(
    userId: string,
    bookingIds: string[],
    eventKey: string,
  ): Promise<Map<string, Date>> {
    if (bookingIds.length === 0) return new Map();
    const rows = await this.prisma.notification.groupBy({
      by: ['bookingId'],
      where: { userId, eventKey, bookingId: { in: bookingIds } },
      _max: { createdAt: true },
    });
    const result = new Map<string, Date>();
    for (const row of rows) {
      if (row.bookingId && row._max.createdAt) {
        result.set(row.bookingId, row._max.createdAt);
      }
    }
    return result;
  }

  /**
   * Check whether this exact eventKey/entityId/userId notification was sent
   * within the last [sinceMs] — used to guard non-booking events (e.g. admin
   * onboarding actions) against accidental duplicates from a rapid
   * double-click, without permanently blocking a legitimate future repeat of
   * the same event (unlike existsForBookingAndUser, which is an unbounded
   * check appropriate only for one-time-per-booking events).
   */
  async existsRecentForEntity(
    userId: string,
    entityType: string,
    entityId: string,
    eventKey: string,
    sinceMs: number,
  ): Promise<boolean> {
    const found = await this.prisma.notification.findFirst({
      where: {
        userId,
        entityType,
        entityId,
        eventKey,
        createdAt: { gte: new Date(Date.now() - sinceMs) },
      },
      select: { id: true },
    });
    return found !== null;
  }
}
