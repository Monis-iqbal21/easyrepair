import { Injectable, Logger } from '@nestjs/common';
import { NotificationsService } from '../notifications/notifications.service';
import { MatchingRepository } from './matching.repository';

/**
 * Which Roman Urdu copy a completion notification uses. The event key is
 * always `booking.completed` regardless of variant — see below.
 */
export type CompletionVariant = 'NORMAL' | 'INSPECTION_BEFORE_SWITCH';

const COMPLETION_EVENT_KEY = 'booking.completed';

const COPY: Record<CompletionVariant, { title: string; body: string }> = {
  NORMAL: {
    title: 'Kaam Mukammal Ho Gaya',
    body: 'Apne Ustaad ko review dein.',
  },
  INSPECTION_BEFORE_SWITCH: {
    title: 'Inspection Mukammal Ho Gayi',
    body: 'Inspection Ustaad ko review dein, phir doosre Ustaads ki offers dekhein.',
  },
};

/**
 * The single place a client is told their work unit is complete.
 *
 * Completion is reachable from four call sites (BookingsService.completeJob,
 * WorkersService.completeJob, completeAfterInspectionClose, and Find Other
 * Ustaad). Routing them all through here guarantees:
 *
 *   - ONE event key — `booking.completed` — so the app's foreground review
 *     prompt, notification-tap navigation and pending-review refresh all key
 *     off the same signal and cannot diverge;
 *   - `bookingId` is always the EXACT completed work unit. For Find Other
 *     Ustaad that is the ORIGINAL INSPECTION booking, never the child repair
 *     booking, so the review is always attributed to the Ustaad who did the
 *     work;
 *   - dedup lives INSIDE this helper, so overlapping call sites can only ever
 *     produce one notification per work unit.
 *
 * Lives in MatchingModule (a leaf) rather than BookingsService so that
 * WorkersService can call it without the two services importing each other.
 */
@Injectable()
export class JobCompletionNotifierService {
  private readonly logger = new Logger(JobCompletionNotifierService.name);

  constructor(
    private readonly matchingRepository: MatchingRepository,
    private readonly notificationsService: NotificationsService,
  ) {}

  /**
   * Tell the client their booking is complete and a review is due. Never
   * throws — safe to call fire-and-forget from any completion path.
   */
  async notifyClientJobCompleted(
    bookingId: string,
    variant: CompletionVariant = 'NORMAL',
    actor?: { userId?: string; role?: 'CLIENT' | 'WORKER' },
  ): Promise<void> {
    try {
      const booking =
        await this.matchingRepository.findBookingForCompletionNotice(bookingId);
      const clientUserId = booking?.clientProfile?.userId;
      if (!clientUserId) return;

      // Unbounded dedup is correct here: a work unit completes exactly once,
      // so a second send is always a duplicate from an overlapping call site.
      const alreadyNotified = await this.notificationsService.wasAlreadyNotified(
        clientUserId,
        bookingId,
        COMPLETION_EVENT_KEY,
      );
      if (alreadyNotified) return;

      const copy = COPY[variant];
      await this.notificationsService.notify({
        userId: clientUserId,
        eventKey: COMPLETION_EVENT_KEY,
        title: copy.title,
        body: copy.body,
        bookingId,
        route: `/client/booking/${bookingId}`,
        actorUserId: actor?.userId,
        actorRole: actor?.role,
        entityType: 'booking',
        entityId: bookingId,
      });
    } catch (err) {
      this.logger.warn(
        `[completion-notify] failed for bookingId=${bookingId}: ${(err as Error)?.message}`,
      );
    }
  }
}
