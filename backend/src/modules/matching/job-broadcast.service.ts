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
  /**
   * How many recipients (or jobs) are re-read and pushed per batch. Every
   * batch re-reads BOTH sides from the database immediately before pushing,
   * so the pre-push eligibility guarantee is unchanged — this only controls
   * how many of those re-reads share a round trip.
   */
  private readonly fanOutChunkSize: number;

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
    this.fanOutChunkSize =
      this.config.get<number>('matching.fanOutChunkSize') ?? 50;
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

      // Radius is now pre-filtered in SQL (bounding box — a superset of the
      // circle, so the authoritative isEligibleForJob check below still
      // decides). Previously this returned EVERY online, fresh, skilled
      // worker in the country and Node discarded the ones out of radius.
      const candidates = await this.matchingRepository.findCandidateWorkers({
        categoryId: booking.categoryId,
        lat: booking.latitude,
        lng: booking.longitude,
        radiusKm: this.radiusKm,
        excludedWorkerIds: booking.workerExclusions.map(
          (e) => e.workerProfileId,
        ),
      });
      if (candidates.length === 0) return;

      await this._fanOutJobToWorkers(
        bookingId,
        candidates.map((c) => c.id),
      );
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

      // Same bounding-box pre-filter as broadcastJob, applied from the job
      // side: only jobs plausibly within the match radius of where this
      // worker currently stands are loaded, instead of every open job in
      // their categories nationwide.
      const bookings =
        await this.matchingRepository.findOpenBookingsForCategories(
          categoryIds,
          workerProfileId,
          {
            lat: worker.currentLat,
            lng: worker.currentLng,
            radiusKm: this.radiusKm,
          },
        );

      await this._fanOutJobsToWorker(
        workerProfileId,
        bookings.map((b) => b.id),
      );
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
        await this._fanOutJobsToWorker(workerProfileId, bookingIds);
      } catch (err) {
        this.logger.warn(
          `[reconcile] failed for workerProfileId=${workerProfileId}: ${(err as Error)?.message}`,
        );
      }
    })();
  }

  // ── The one per-recipient pipeline ────────────────────────────────────────

  /**
   * ONE job → MANY workers (broadcast).
   *
   * Both sides are still re-read from the database immediately before every
   * push — a job hired mid-fan-out, or a worker who went offline / got busy /
   * went stale / moved outside the radius, is still skipped. What changed is
   * that the re-reads are BATCHED: previously each recipient cost two point
   * reads plus a dedup query (3N round trips for N candidates); now each
   * chunk costs one booking read, one worker read and one dedup read
   * regardless of chunk size.
   */
  private async _fanOutJobToWorkers(
    bookingId: string,
    workerProfileIds: string[],
  ): Promise<void> {
    for (const chunk of this._chunk(workerProfileIds)) {
      // Fresh re-read of the job for THIS chunk — the hire-race guard.
      const [booking, workers] = await Promise.all([
        this.matchingRepository.findBookingForMatching(bookingId),
        this.matchingRepository.findWorkersForMatching(chunk),
      ]);
      if (!booking || !this._isOpen(booking)) return;

      const copy = this._copyFor(booking);
      if (!copy) return;

      const inspectingWorkerProfileId = this._inspectorIdFor(booking);
      const eligible = workers.filter((worker) =>
        isEligibleForJob(worker, booking, {
          radiusKm: this.radiusKm,
          inspectingWorkerProfileId,
        }),
      );
      if (eligible.length === 0) continue;

      const alreadyNotified =
        await this.notificationsService.findAlreadyNotifiedThisCycle(
          eligible.map((w) => w.userId),
          bookingId,
          copy.eventKey,
          booking.liveStartedAt,
        );

      for (const worker of eligible) {
        if (alreadyNotified.has(worker.userId)) continue;
        await this._dispatch(worker.userId, bookingId, copy);
      }
    }
  }

  /**
   * MANY jobs → ONE worker (late discovery / reconcile).
   *
   * Mirror image of the above, with the same guarantee: the worker's state
   * and every job's open/assigned state are re-read per chunk, immediately
   * before the pushes for that chunk go out.
   */
  private async _fanOutJobsToWorker(
    workerProfileId: string,
    bookingIds: string[],
  ): Promise<void> {
    for (const chunk of this._chunk(bookingIds)) {
      // Fresh re-read of the worker for THIS chunk — presence, location,
      // busy and account state may all have changed since discovery.
      const [worker, bookings] = await Promise.all([
        this.matchingRepository.findWorkerForMatching(workerProfileId),
        this.matchingRepository.findBookingsForMatching(chunk),
      ]);
      if (!worker) return;

      /** Eligible bookings grouped by the event key they dedupe against. */
      const byEventKey = new Map<
        string,
        {
          copy: (typeof LANE_COPY)[string];
          bookings: NonNullable<MatchingBooking>[];
        }
      >();

      for (const booking of bookings) {
        if (!this._isOpen(booking)) continue;
        const copy = this._copyFor(booking);
        if (!copy) continue;
        if (
          !isEligibleForJob(worker, booking, {
            radiusKm: this.radiusKm,
            inspectingWorkerProfileId: this._inspectorIdFor(booking),
          })
        ) {
          continue;
        }
        const bucket = byEventKey.get(copy.eventKey) ?? { copy, bookings: [] };
        bucket.bookings.push(booking);
        byEventKey.set(copy.eventKey, bucket);
      }

      for (const { copy, bookings: eligible } of byEventKey.values()) {
        const alreadyNotified =
          await this.notificationsService.findAlreadyNotifiedBookingIds(
            worker.userId,
            eligible.map((b) => ({
              id: b.id,
              liveStartedAt: b.liveStartedAt,
            })),
            copy.eventKey,
          );
        for (const booking of eligible) {
          if (alreadyNotified.has(booking.id)) continue;
          await this._dispatch(worker.userId, booking.id, copy);
        }
      }
    }
  }

  /** The single push call — identical payload for both fan-out shapes. */
  private async _dispatch(
    userId: string,
    bookingId: string,
    copy: { eventKey: string; title: string; body: string },
  ): Promise<void> {
    await this.notificationsService.notify({
      userId,
      eventKey: copy.eventKey,
      title: copy.title,
      body: copy.body,
      bookingId,
      route: `/worker/job/${bookingId}`,
      entityType: 'booking',
      entityId: bookingId,
    });
  }

  private *_chunk<T>(items: T[]): Generator<T[]> {
    const size = Math.max(1, this.fanOutChunkSize);
    for (let i = 0; i < items.length; i += size) {
      yield items.slice(i, i + size);
    }
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
