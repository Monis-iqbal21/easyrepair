import { Injectable, Logger, Inject, forwardRef } from '@nestjs/common';
import { Notification, Prisma } from '@prisma/client';
import { FirebaseService } from '../../firebase/firebase.service';
import { ChatGateway } from '../chat/chat.gateway';
import {
  CreateNotificationData,
  NotificationsRepository,
} from './notifications.repository';
import {
  getNotificationTemplate,
  hasLocalizedNotificationTemplate,
} from './notification-templates';

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
  /** Dynamic values interpolated by the centralized localized template. */
  templateParams?: Record<string, string | number>;
  /** Unique lifecycle event that caused this notification. */
  complaintEventId?: string;
  /**
   * Set to false to suppress the in-app top-banner for this event (push +
   * DB persistence still happen). Defaults to true — most booking lifecycle
   * events should show the banner.
   */
  inAppBanner?: boolean;
}

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private readonly notificationsRepository: NotificationsRepository,
    private readonly firebase: FirebaseService,
    @Inject(forwardRef(() => ChatGateway))
    private readonly chatGateway: ChatGateway,
  ) {}

  /**
   * Persist a notification to the DB, then fire-and-forget an FCM push.
   * Never throws — failures are logged and swallowed so callers never break.
   */
  async notify(options: NotifyOptions): Promise<void> {
    const {
      userId,
      title: fallbackTitle,
      body: fallbackBody,
      eventKey,
      bookingId,
      route,
      actorUserId,
      actorRole,
      entityType,
      entityId,
      payload,
      complaintEventId,
      templateParams,
    } = options;

    let title = fallbackTitle;
    let body = fallbackBody;
    if (hasLocalizedNotificationTemplate(eventKey)) {
      try {
        const locale =
          await this.notificationsRepository.findUserNotificationLocale(userId);
        ({ title, body } = getNotificationTemplate(
          eventKey,
          templateParams,
          locale,
        ));
      } catch (err) {
        // Locale lookup is an enhancement, never a reason to lose a booking
        // notification. Keep the caller's legacy copy on lookup failure.
        this.logger.warn(
          `Failed to resolve notification locale for userId=${userId}: ${err}`,
        );
      }
    }

    const data: CreateNotificationData = {
      userId,
      title,
      body,
      eventKey,
      entityType: entityType ?? (bookingId ? 'booking' : undefined),
      entityId: entityId ?? bookingId,
      bookingId,
      actorUserId,
      actorRole,
      route,
      payload,
      complaintEventId,
    };

    let notificationId: string | undefined;
    try {
      const saved = await this.notificationsRepository.create(data);
      notificationId = saved.id;
    } catch (err) {
      if (
        complaintEventId &&
        ((err instanceof Prisma.PrismaClientKnownRequestError &&
          err.code === 'P2002') ||
          (err as { code?: string } | null)?.code === 'P2002')
      ) {
        this.logger.debug(
          `Complaint notification already persisted for eventId=${complaintEventId}`,
        );
        return;
      }
      this.logger.warn(
        `Failed to persist notification for userId=${userId}: ${err}`,
      );
    }

    // FCM push — fire and forget, never awaited by caller
    const resolvedEntityType = entityType ?? (bookingId ? 'booking' : '');
    const resolvedEntityId = entityId ?? bookingId ?? '';
    const fcmData: Record<string, string> = {
      eventKey: eventKey ?? '',
      entityType: resolvedEntityType,
      entityId: resolvedEntityId,
      route: route ?? '',
      actorUserId: actorUserId ?? '',
      actorRole: actorRole ?? '',
    };
    // Include the persisted notification id so the client can mark it read on tap.
    if (notificationId) {
      fcmData.notificationId = notificationId;
    }
    // Include role-aware navigation keys so Flutter can route without parsing entityType.
    if (resolvedEntityType === 'conversation' && resolvedEntityId) {
      fcmData.conversationId = resolvedEntityId;
    } else if (resolvedEntityType === 'booking' && resolvedEntityId) {
      fcmData.bookingId = resolvedEntityId;
    } else if (bookingId) {
      fcmData.bookingId = bookingId;
    }
    void this._sendPush(userId, title, body, fcmData);

    // In-app top-banner — reuses the already-authenticated chat socket
    // connection/room rather than a dedicated gateway. Additive to push,
    // never a replacement; never throws.
    if (options.inAppBanner !== false) {
      this.chatGateway.emitAppBanner(userId, {
        eventKey,
        title,
        body,
        bookingId,
        route,
      });
    }
  }

  private async _sendPush(
    userId: string,
    title: string,
    body: string,
    data: Record<string, string>,
  ): Promise<void> {
    let fcmToken: string | null = null;
    try {
      fcmToken = await this.notificationsRepository.findUserFcmToken(userId);
      if (!fcmToken) {
        this.logger.debug(`No FCM token for userId=${userId}`);
        return;
      }
      await this.firebase.sendPush(fcmToken, title, body, data);
      this.logger.debug(
        `Push sent to userId=${userId} eventKey=${data.eventKey}`,
      );
    } catch (err) {
      this.logger.warn(`FCM push failed for userId=${userId}: ${err}`);
      if (fcmToken && this._isPermanentlyInvalidToken(err)) {
        // App was uninstalled / token otherwise permanently revoked —
        // Firebase itself confirmed it, so stop retrying it forever. Cleanup
        // only: never used to infer Worker availability (see
        // WORKER_PRESENCE_STALE_MS, the sole presence mechanism).
        await this.notificationsRepository
          .clearFcmTokenByValue(fcmToken)
          .catch(() => undefined);
        this.logger.log(
          `Cleared permanently-invalid FCM token for userId=${userId}`,
        );
      }
    }
  }

  /**
   * Firebase Admin's messaging.send() rejects with a FirebaseMessagingError
   * whose `.code` identifies a permanently unregistered/invalid token —
   * distinct from a transient send failure (network, quota, malformed
   * payload, etc.), which must never trigger token cleanup. Deliberately
   * narrow to the two codes the SDK documents as token-specific; a broader
   * code like `messaging/invalid-argument` can also mean an unrelated
   * malformed payload, so it is NOT treated as a token problem here.
   */
  private _isPermanentlyInvalidToken(err: unknown): boolean {
    const code = (err as { code?: string } | null)?.code;
    return (
      code === 'messaging/registration-token-not-registered' ||
      code === 'messaging/invalid-registration-token'
    );
  }

  /** See NotificationsRepository.existsForBookingAndUser. */
  async wasAlreadyNotified(
    userId: string,
    bookingId: string,
    eventKey: string,
  ): Promise<boolean> {
    return this.notificationsRepository.existsForBookingAndUser(
      userId,
      bookingId,
      eventKey,
    );
  }

  /**
   * Per-live-cycle dedup for broadcasts — see
   * NotificationsRepository.existsForBookingAndUserSince. Pass the booking's
   * `liveStartedAt`; a null one falls back to the unbounded check so
   * historical rows never regress into repeat notifications.
   */
  async wasAlreadyNotifiedThisCycle(
    userId: string,
    bookingId: string,
    eventKey: string,
    liveStartedAt: Date | null,
  ): Promise<boolean> {
    if (!liveStartedAt) {
      return this.wasAlreadyNotified(userId, bookingId, eventKey);
    }
    return this.notificationsRepository.existsForBookingAndUserSince(
      userId,
      bookingId,
      eventKey,
      liveStartedAt,
    );
  }

  /**
   * Batched counterpart of wasAlreadyNotifiedThisCycle — see
   * NotificationsRepository.findNotifiedUserIds. Returns the userIds that
   * have already been notified, so a fan-out can skip them without one dedup
   * query per recipient.
   */
  async findAlreadyNotifiedThisCycle(
    userIds: string[],
    bookingId: string,
    eventKey: string,
    liveStartedAt: Date | null,
  ): Promise<Set<string>> {
    return this.notificationsRepository.findNotifiedUserIds(
      userIds,
      bookingId,
      eventKey,
      liveStartedAt,
    );
  }

  /**
   * Batched counterpart of wasAlreadyNotifiedThisCycle for the one-worker /
   * many-jobs fan-out. Returns the bookingIds that must be SKIPPED, applying
   * each booking's own liveStartedAt cycle boundary — see
   * NotificationsRepository.findLatestNotifiedAtByBooking.
   */
  async findAlreadyNotifiedBookingIds(
    userId: string,
    bookings: { id: string; liveStartedAt: Date | null }[],
    eventKey: string,
  ): Promise<Set<string>> {
    const latest =
      await this.notificationsRepository.findLatestNotifiedAtByBooking(
        userId,
        bookings.map((b) => b.id),
        eventKey,
      );
    const skip = new Set<string>();
    for (const booking of bookings) {
      const notifiedAt = latest.get(booking.id);
      if (!notifiedAt) continue;
      // liveStartedAt === null reproduces the unbounded wasAlreadyNotified
      // check; otherwise only notifications from the current cycle count.
      if (!booking.liveStartedAt || notifiedAt >= booking.liveStartedAt) {
        skip.add(booking.id);
      }
    }
    return skip;
  }

  /** See NotificationsRepository.existsRecentForEntity. */
  async wasRecentlyNotifiedForEntity(
    userId: string,
    entityType: string,
    entityId: string,
    eventKey: string,
    sinceMs: number,
  ): Promise<boolean> {
    return this.notificationsRepository.existsRecentForEntity(
      userId,
      entityType,
      entityId,
      eventKey,
      sinceMs,
    );
  }

  async getNotifications(userId: string): Promise<Notification[]> {
    return this.notificationsRepository.findByUserId(userId);
  }

  async markRead(id: string): Promise<Notification> {
    return this.notificationsRepository.markRead(id);
  }

  async markAllRead(userId: string) {
    return this.notificationsRepository.markAllRead(userId);
  }

  async getUnreadCount(userId: string): Promise<number> {
    return this.notificationsRepository.countUnread(userId);
  }
}
