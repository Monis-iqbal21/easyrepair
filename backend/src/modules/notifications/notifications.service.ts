import { Injectable, Logger, Inject, forwardRef } from '@nestjs/common';
import { Notification } from '@prisma/client';
import { FirebaseService } from '../../firebase/firebase.service';
import { ChatGateway } from '../chat/chat.gateway';
import {
  CreateNotificationData,
  NotificationsRepository,
} from './notifications.repository';

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
      title,
      body,
      eventKey,
      bookingId,
      route,
      actorUserId,
      actorRole,
      entityType,
      entityId,
      payload,
    } = options;

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
    };

    let notificationId: string | undefined;
    try {
      const saved = await this.notificationsRepository.create(data);
      notificationId = saved.id;
    } catch (err) {
      this.logger.warn(`Failed to persist notification for userId=${userId}: ${err}`);
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
    try {
      const fcmToken = await this.notificationsRepository.findUserFcmToken(userId);
      if (!fcmToken) {
        this.logger.debug(`No FCM token for userId=${userId}`);
        return;
      }
      await this.firebase.sendPush(fcmToken, title, body, data);
      this.logger.debug(`Push sent to userId=${userId} eventKey=${data.eventKey}`);
    } catch (err) {
      this.logger.warn(`FCM push failed for userId=${userId}: ${err}`);
    }
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
