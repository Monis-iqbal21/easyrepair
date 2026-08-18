import { ForbiddenException } from '@nestjs/common';
import {
  AvailabilityStatus,
  BookingStatus,
  WorkerOnboardingStatus,
  WorkerStatus,
} from '@prisma/client';
import { haversineKm } from './geo.util';

/**
 * THE single eligibility matcher for "may this Ustaad be offered this job?".
 *
 * Both sides of the system terminate here so they can never drift:
 *   - broadcast / push notification fan-out (JobBroadcastService)
 *   - New Jobs feed visibility (BidsService.getNewJobsForWorker)
 *
 * It is lane-agnostic on purpose. [inspectingWorkerProfileId] is an OPTIONAL
 * extra exclusion layered on top of the universal checks — it can only ever
 * remove a worker, never skip a check. A Direct-Bidding job (no
 * sourceInspectionBookingId, no InspectionReport) therefore passes through
 * exactly the same radius / online / freshness / busy / open-and-unassigned
 * gate as every other lane: `null` means "no inspector to exclude", it does
 * NOT mean "unmatched".
 */

/** Default match radius in km, overridable via config (`matching.radiusKm`). */
export const DEFAULT_JOB_MATCH_RADIUS_KM = 7;

/** GPS freshness rule, mirrored from the nearby-worker SQL query. */
export const LOCATION_FRESHNESS_MS = 30 * 60 * 1000;

/**
 * How stale a Worker's `lastSeenAt` presence signal may get before their
 * ONLINE status is treated as an expired lease rather than genuine
 * availability. Configurable via WORKER_ONLINE_STALE_HOURS (default 6h) —
 * single source of truth, mirrored into the stale-worker cleanup job
 * (workers.processor.ts) and the coarse DB-level candidate filters
 * (matching.repository.ts, bookings.repository.ts findNearbyWorkers).
 *
 * Deliberately independent of LOCATION_FRESHNESS_MS above: presence answers
 * "has this Worker's app been active in HandyGo recently?", location answers
 * "is this Worker's GPS fix recent enough for nearby matching?". Neither
 * check replaces the other.
 */
const WORKER_ONLINE_STALE_HOURS =
  parseFloat(process.env.WORKER_ONLINE_STALE_HOURS ?? '') || 6;
export const WORKER_PRESENCE_STALE_MS =
  WORKER_ONLINE_STALE_HOURS * 60 * 60 * 1000;

/**
 * How long an open job stays in NEW-JOB DISCOVERY (New Jobs feed / broadcast
 * / late-discovery push) after creation, independent of its BookingStatus.
 * Configurable via JOB_DISCOVERY_WINDOW_HOURS (default 48h) — single source
 * of truth, checked centrally in `checkJobEligibility` below so it can never
 * drift between the New Jobs feed, the broadcast fan-out and late discovery.
 *
 * This is discovery FILTERING, not data deletion or the booking's actual
 * expiry: a still-PENDING booking older than this window simply stops being
 * offered to new bidders — it is untouched in the database, and a worker who
 * already bid on it keeps that bid/history regardless of this window. The
 * booking's own auto-expiry (72h, see BookingsProcessor) is a separate,
 * longer-running mechanism that eventually flips it to EXPIRED.
 */
const JOB_DISCOVERY_WINDOW_HOURS =
  parseFloat(process.env.JOB_DISCOVERY_WINDOW_HOURS ?? '') || 48;
export const JOB_DISCOVERY_WINDOW_MS =
  JOB_DISCOVERY_WINDOW_HOURS * 60 * 60 * 1000;

export interface JobEligibilityWorker {
  id: string;
  status: WorkerStatus;
  onboardingStatus: WorkerOnboardingStatus;
  profileCompleted: boolean;
  availabilityStatus: AvailabilityStatus;
  /** A worker already on an active job is never offered more work. */
  currentlyWorking?: boolean;
  currentLat: number | null;
  currentLng: number | null;
  locationUpdatedAt: Date | null;
  /** Server-observed last genuine app-activity timestamp — see touchWorkerPresence. */
  lastSeenAt: Date | null;
  skills: { categoryId: string }[];
}

export interface JobEligibilityBooking {
  categoryId: string;
  latitude: number;
  longitude: number;
  /** When present, the job must still be PENDING to be offered. */
  status?: BookingStatus | string | null;
  /** When present, the job must still be unassigned to be offered. */
  workerProfileId?: string | null;
  /** Workers excluded from this specific booking (e.g. cancelled after being
   *  hired) — never re-offered/re-listed for it, even after a relist. */
  workerExclusions?: { workerProfileId: string }[];
  /** When present, gates the JOB_DISCOVERY_WINDOW_MS check below. */
  createdAt?: Date;
}

export interface JobEligibilityOptions {
  /** Defaults to DEFAULT_JOB_MATCH_RADIUS_KM when omitted. */
  radiusKm?: number;
  /** Post-inspection jobs only: the Ustaad who performed the inspection. */
  inspectingWorkerProfileId?: string | null;
  /**
   * Defaults to true — the existing, stricter behavior: the Worker must be
   * genuinely ONLINE with a fresh presence lease and fresh GPS. Live/instant
   * paths (broadcast fan-out, late-discovery push, direct-hire nearby-worker
   * search) must always leave this at its default.
   *
   * Pass false ONLY for Worker-facing marketplace browsing/bidding (New Jobs
   * feed, bid submission) — manual OFFLINE means "exclude me from live
   * matching," not "hide the marketplace from me" (see job-visibility task).
   * Account state, category match, exclusions, BUSY, and radius (using
   * whatever location is on file, however stale) still apply either way.
   */
  requireLivePresence?: boolean;
}

/** Reason codes, used by the throwing assert to pick a user-facing message. */
export type JobIneligibilityReason =
  | 'NOT_APPROVED'
  | 'IS_INSPECTOR'
  | 'EXCLUDED'
  | 'CATEGORY_MISMATCH'
  | 'OFFLINE'
  | 'BUSY'
  | 'STALE_PRESENCE'
  | 'STALE_LOCATION'
  | 'OUT_OF_RADIUS'
  | 'NOT_OPEN'
  | 'ALREADY_ASSIGNED'
  | 'DISCOVERY_WINDOW_EXPIRED'
  | null;

export function checkJobEligibility(
  worker: JobEligibilityWorker,
  booking: JobEligibilityBooking,
  options: JobEligibilityOptions = {},
): JobIneligibilityReason {
  const radiusKm = options.radiusKm ?? DEFAULT_JOB_MATCH_RADIUS_KM;
  const inspectingWorkerProfileId = options.inspectingWorkerProfileId ?? null;
  const requireLivePresence = options.requireLivePresence ?? true;

  // ── Job must still be open ────────────────────────────────────────────────
  // Only enforced when the caller supplied the field, so partial projections
  // (e.g. report-access checks) keep working.
  if (booking.status != null && booking.status !== BookingStatus.PENDING) {
    return 'NOT_OPEN';
  }
  if (booking.workerProfileId != null) {
    return 'ALREADY_ASSIGNED';
  }
  // Discovery filtering, not deletion — see JOB_DISCOVERY_WINDOW_MS. Only
  // enforced when the caller supplied createdAt, same partial-projection
  // convention as status/workerProfileId above.
  if (
    booking.createdAt != null &&
    Date.now() - booking.createdAt.getTime() > JOB_DISCOVERY_WINDOW_MS
  ) {
    return 'DISCOVERY_WINDOW_EXPIRED';
  }

  // ── Worker account ────────────────────────────────────────────────────────
  if (
    worker.status !== WorkerStatus.ACTIVE ||
    worker.onboardingStatus !== WorkerOnboardingStatus.APPROVED ||
    !worker.profileCompleted
  ) {
    return 'NOT_APPROVED';
  }
  if (inspectingWorkerProfileId && worker.id === inspectingWorkerProfileId) {
    return 'IS_INSPECTOR';
  }
  if (booking.workerExclusions?.some((e) => e.workerProfileId === worker.id)) {
    return 'EXCLUDED';
  }
  if (!worker.skills.some((s) => s.categoryId === booking.categoryId)) {
    return 'CATEGORY_MISMATCH';
  }
  if (requireLivePresence && worker.availabilityStatus !== AvailabilityStatus.ONLINE) {
    return 'OFFLINE';
  }
  if (worker.currentlyWorking === true) {
    return 'BUSY';
  }

  // ── Presence lease ───────────────────────────────────────────────────────
  // ONLINE is a renewable server-side lease, not a permanent flag: a Worker
  // who hasn't shown genuine app activity (touchWorkerPresence) within the
  // stale window is excluded from new-job matching immediately, independent
  // of whether the periodic cleanup job has flipped them to OFFLINE yet.
  // Skipped in marketplace-browse mode (requireLivePresence: false) — a
  // manually OFFLINE Worker has no live presence lease at all by design, but
  // may still browse/bid; see JobEligibilityOptions.requireLivePresence.
  if (requireLivePresence) {
    if (
      !worker.lastSeenAt ||
      Date.now() - worker.lastSeenAt.getTime() > WORKER_PRESENCE_STALE_MS
    ) {
      return 'STALE_PRESENCE';
    }

    // ── Location freshness ────────────────────────────────────────────────
    if (
      !worker.locationUpdatedAt ||
      Date.now() - worker.locationUpdatedAt.getTime() > LOCATION_FRESHNESS_MS
    ) {
      return 'STALE_LOCATION';
    }
  }

  // ── Radius — always enforced, live or marketplace, using whatever
  // location is on file (may be stale in marketplace mode; that's fine, it
  // still keeps genuinely-out-of-area workers from seeing the job). ────────
  const distanceKm = haversineKm(
    booking.latitude,
    booking.longitude,
    worker.currentLat,
    worker.currentLng,
  );
  if (distanceKm == null || distanceKm > radiusKm) {
    return 'OUT_OF_RADIUS';
  }

  return null;
}

/** Throwing variant — gates viewing/bidding with a user-facing message. */
export function assertEligibleForJob(
  worker: JobEligibilityWorker,
  booking: JobEligibilityBooking,
  options: JobEligibilityOptions = {},
): void {
  switch (checkJobEligibility(worker, booking, options)) {
    case 'NOT_APPROVED':
      throw new ForbiddenException(
        'Profile complete karein taake jobs apply kar saken.',
      );
    case 'IS_INSPECTOR':
      throw new ForbiddenException(
        'You already submitted your inspection quote for this job.',
      );
    case 'EXCLUDED':
      throw new ForbiddenException('You are not eligible to bid on this job.');
    case 'CATEGORY_MISMATCH':
      throw new ForbiddenException(
        'You are not allowed to view or bid on this job',
      );
    case 'OFFLINE':
      throw new ForbiddenException('Go online to view or bid on this job.');
    case 'BUSY':
      throw new ForbiddenException(
        'Aap pehle se ek kaam par hain. Mukammal karne ke baad naya kaam lein.',
      );
    case 'STALE_PRESENCE':
      throw new ForbiddenException('Go online to view or bid on this job.');
    case 'STALE_LOCATION':
      throw new ForbiddenException(
        'Update your location to view or bid on this job.',
      );
    case 'OUT_OF_RADIUS':
      throw new ForbiddenException('This job is outside your service area.');
    case 'NOT_OPEN':
    case 'ALREADY_ASSIGNED':
    case 'DISCOVERY_WINDOW_EXPIRED':
      throw new ForbiddenException('This job is no longer open.');
    default:
      return;
  }
}

/** Non-throwing variant — used by the feed and the broadcast fan-out. */
export function isEligibleForJob(
  worker: JobEligibilityWorker,
  booking: JobEligibilityBooking,
  options: JobEligibilityOptions = {},
): boolean {
  return checkJobEligibility(worker, booking, options) === null;
}

// ── Back-compat aliases ─────────────────────────────────────────────────────
// Kept so the inspection-report and bid call sites read naturally; both
// delegate to the single matcher above, so there is nothing to drift.

export type InspectionBidderWorkerProfile = JobEligibilityWorker;
export type InspectionBidderBooking = JobEligibilityBooking;

export function assertEligibleForInspectionBidding(
  worker: JobEligibilityWorker,
  booking: JobEligibilityBooking,
  inspectingWorkerProfileId: string | null,
  radiusKm?: number,
  requireLivePresence?: boolean,
): void {
  assertEligibleForJob(worker, booking, {
    inspectingWorkerProfileId,
    radiusKm,
    requireLivePresence,
  });
}

export function isEligibleForInspectionBidding(
  worker: JobEligibilityWorker,
  booking: JobEligibilityBooking,
  inspectingWorkerProfileId: string | null,
  radiusKm?: number,
  requireLivePresence?: boolean,
): boolean {
  return isEligibleForJob(worker, booking, {
    inspectingWorkerProfileId,
    radiusKm,
    requireLivePresence,
  });
}
