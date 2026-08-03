import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { BookingLane, BookingStatus } from '@prisma/client';
import { NotificationsService } from '../notifications/notifications.service';
import { RedisService } from '../../redis/redis.service';
import {
  DEFAULT_JOB_MATCH_RADIUS_KM,
  isEligibleForJob,
} from '../../common/utils/job-eligibility.util';
import {
  MatchingBooking,
  MatchingRepository,
  MatchingWorker,
} from './matching.repository';

/** Per-lane broadcast copy. All Roman Urdu. */
const LANE_COPY: Record<
  string,
  { eventKey: string; title: string; body: string }
> = {
  STANDARD: {
    eventKey: 'booking.standard.worker_listed',
    title: 'Naya Standard Kaam Aapke Qareeb Hai',
    body: 'App khol kar job ki tafseel dekhein.',
  },
  INSPECTION: {
    eventKey: 'booking.inspection.available',
    title: 'Nayi Inspection Job Aapke Qareeb Hai',
    body: 'Inspection ki tafseel dekhne ke liye New Jobs kholen.',
  },
  BIDDING: {
    eventKey: 'booking.bidding.available',
    title: 'Naya Bidding Kaam Aapke Qareeb Hai',
    body: 'Apni offer bhejne ke liye New Jobs kholen.',
  },
  BIDDING_LINKED: {
    eventKey: 'booking.inspection.find_other_ustaad_available',
    title: 'Naya Bidding Kaam Aapke Qareeb Hai',
    body: 'Apni offer bhejne ke liye New Jobs kholen.',
  },
};

/**
 * The single fan-out path for "an open job should reach nearby Ustaads".
 *
 * Two entry points, one pipeline:
 *   - broadcastJob()            — a job just became live/open
 *   - matchOpenJobsForWorker()  — a worker just became eligible (late discovery)
 *
 * Both terminate in the same `isEligibleForJob` call that New Jobs visibility
 * uses, so notification reach and feed visibility cannot drift.
 */
@Injectable()
export class JobBroadcastService {
  private readonly logger = new Logger(JobBroadcastService.name);
  private readonly radiusKm: number;
  private readonly locationCooldownSeconds: number;

  constructor(
    private readonly matchingRepository: MatchingRepository,
    private readonly notificationsService: NotificationsService,
    private readonly redisService: RedisService,
    private readonly config: ConfigService,
  ) {
    this.radiusKm =
      this.config.get<number>('matching.radiusKm') ??
      DEFAULT_JOB_MATCH_RADIUS_KM;
    this.locationCooldownSeconds =
      this.config.get<number>('matching.locationCooldownSeconds') ?? 60;
  }

  /** The configured match radius, so consumers share one source of truth. */
  get matchRadiusKm(): number {
    return this.radiusKm;
  }

  // ── Entry point 1: a job became live/open ─────────────────────────────────

  /**
   * Notify every currently-eligible nearby Ustaad about this job, once per
   * live cycle. Safe to call fire-and-forget: it never throws.
   */
  async broadcastJob(bookingId: string): Promise<void> {
    try {
      const booking =
        await this.matchingRepository.findBookingForMatching(bookingId);
      if (!booking || !this._isOpen(booking)) return;

      const candidates = await this.matchingRepository.findCandidateWorkers({
        categoryId: booking.categoryId,
        excludedWorkerIds: booking.workerExclusions.map(
          (e) => e.workerProfileId,
        ),
      });
      if (candidates.length === 0) return;

      for (const candidate of candidates) {
        await this._notifyIfStillEligible(bookingId, candidate.id);
      }
    } catch (err) {
      this.logger.warn(
        `[broadcast] failed for bookingId=${bookingId}: ${(err as Error)?.message}`,
      );
    }
  }

  // ── Entry point 2: a worker became eligible (late discovery) ──────────────

  /**
   * A worker just went online / moved / became free / refreshed New Jobs —
   * notify them about any still-open job they are now eligible for. Never
   * throws; safe to call fire-and-forget.
   *
   * [bypassCooldown] skips the per-worker Redis throttle for genuine state
   * transitions (online, became free, stale→fresh) as opposed to routine
   * location heartbeats.
   */
  async matchOpenJobsForWorker(
    workerProfileId: string,
    options: { bypassCooldown?: boolean } = {},
  ): Promise<void> {
    try {
      if (!options.bypassCooldown) {
        const acquired = await this.redisService.tryAcquire(
          `worker:jobmatch:${workerProfileId}`,
          this.locationCooldownSeconds,
        );
        if (!acquired) return;
      }

      const worker =
        await this.matchingRepository.findWorkerForMatching(workerProfileId);
      if (!worker) return;

      const categoryIds = worker.skills.map((s) => s.categoryId);
      if (categoryIds.length === 0) return;

      const bookings =
        await this.matchingRepository.findOpenBookingsForCategories(
          categoryIds,
          workerProfileId,
        );

      for (const booking of bookings) {
        await this._notifyIfStillEligible(booking.id, workerProfileId);
      }
    } catch (err) {
      this.logger.warn(
        `[late-match] failed for workerProfileId=${workerProfileId}: ${(err as Error)?.message}`,
      );
    }
  }

  /**
   * Non-blocking reconciliation for the jobs a worker can currently see —
   * called after the New Jobs feed is computed so a push missed while the app
   * was closed is recovered. Per-cycle dedup makes repeated refreshes silent.
   */
  reconcileVisibleJobs(workerProfileId: string, bookingIds: string[]): void {
    if (bookingIds.length === 0) return;
    void (async () => {
      try {
        for (const bookingId of bookingIds) {
          await this._notifyIfStillEligible(bookingId, workerProfileId);
        }
      } catch (err) {
        this.logger.warn(
          `[reconcile] failed for workerProfileId=${workerProfileId}: ${(err as Error)?.message}`,
        );
      }
    })();
  }

  // ── The one per-recipient pipeline ────────────────────────────────────────

  /**
   * Re-reads BOTH sides before deciding, so nothing that changed during a
   * fan-out can leak a push: a job hired mid-loop, or a worker who went
   * offline / got busy / went stale / moved outside the radius, is skipped.
   */
  private async _notifyIfStillEligible(
    bookingId: string,
    workerProfileId: string,
  ): Promise<void> {
    const [booking, worker] = await Promise.all([
      this.matchingRepository.findBookingForMatching(bookingId),
      this.matchingRepository.findWorkerForMatching(workerProfileId),
    ]);
    if (!booking || !worker || !this._isOpen(booking)) return;

    const eligible = isEligibleForJob(worker, booking, {
      radiusKm: this.radiusKm,
      inspectingWorkerProfileId: this._inspectorIdFor(booking),
    });
    if (!eligible) return;

    const copy = this._copyFor(booking);
    if (!copy) return;

    const alreadyNotified =
      await this.notificationsService.wasAlreadyNotifiedThisCycle(
        worker.userId,
        bookingId,
        copy.eventKey,
        booking.liveStartedAt,
      );
    if (alreadyNotified) return;

    await this.notificationsService.notify({
      userId: worker.userId,
      eventKey: copy.eventKey,
      title: copy.title,
      body: copy.body,
      bookingId,
      route: `/worker/job/${bookingId}`,
      entityType: 'booking',
      entityId: bookingId,
    });
  }

  private _isOpen(booking: NonNullable<MatchingBooking>): boolean {
    return (
      booking.status === BookingStatus.PENDING &&
      booking.workerProfileId === null
    );
  }

  /**
   * The Ustaad who inspected, for post-inspection repair jobs — excluded from
   * their own repair job's broadcast and bidding. Null for every other job,
   * which means only "nobody to exclude", never "skip matching".
   */
  private _inspectorIdFor(booking: NonNullable<MatchingBooking>): string | null {
    if (
      booking.lane === BookingLane.INSPECTION &&
      booking.inspectionReport?.decisionStatus === 'FIND_OTHER_USTAAD'
    ) {
      return booking.inspectionReport.workerProfileId;
    }
    if (
      booking.lane === BookingLane.BIDDING &&
      booking.sourceInspectionBookingId != null
    ) {
      return (
        booking.sourceInspectionBooking?.inspectionReport?.workerProfileId ??
        null
      );
    }
    return null;
  }

  private _copyFor(booking: NonNullable<MatchingBooking>) {
    if (booking.lane === BookingLane.STANDARD) return LANE_COPY.STANDARD;
    if (booking.lane === BookingLane.BIDDING) {
      return booking.sourceInspectionBookingId != null
        ? LANE_COPY.BIDDING_LINKED
        : LANE_COPY.BIDDING;
    }
    if (booking.lane === BookingLane.INSPECTION) {
      // An ordinary inspection is direct-assign; once the client chooses
      // "Find Other Ustaad" the legacy same-row shape becomes biddable and
      // keeps its original event key so its dedup history stays valid.
      return booking.inspectionReport?.decisionStatus === 'FIND_OTHER_USTAAD'
        ? LANE_COPY.BIDDING_LINKED
        : LANE_COPY.INSPECTION;
    }
    return null;
  }
}

export type { MatchingWorker };
