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
}

export interface JobEligibilityOptions {
  /** Defaults to DEFAULT_JOB_MATCH_RADIUS_KM when omitted. */
  radiusKm?: number;
  /** Post-inspection jobs only: the Ustaad who performed the inspection. */
  inspectingWorkerProfileId?: string | null;
}

/** Reason codes, used by the throwing assert to pick a user-facing message. */
export type JobIneligibilityReason =
  | 'NOT_APPROVED'
  | 'IS_INSPECTOR'
  | 'EXCLUDED'
  | 'CATEGORY_MISMATCH'
  | 'OFFLINE'
  | 'BUSY'
  | 'STALE_LOCATION'
  | 'OUT_OF_RADIUS'
  | 'NOT_OPEN'
  | 'ALREADY_ASSIGNED'
  | null;

export function checkJobEligibility(
  worker: JobEligibilityWorker,
  booking: JobEligibilityBooking,
  options: JobEligibilityOptions = {},
): JobIneligibilityReason {
  const radiusKm = options.radiusKm ?? DEFAULT_JOB_MATCH_RADIUS_KM;
  const inspectingWorkerProfileId = options.inspectingWorkerProfileId ?? null;

  // ── Job must still be open ────────────────────────────────────────────────
  // Only enforced when the caller supplied the field, so partial projections
  // (e.g. report-access checks) keep working.
  if (booking.status != null && booking.status !== BookingStatus.PENDING) {
    return 'NOT_OPEN';
  }
  if (booking.workerProfileId != null) {
    return 'ALREADY_ASSIGNED';
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
  if (worker.availabilityStatus !== AvailabilityStatus.ONLINE) {
    return 'OFFLINE';
  }
  if (worker.currentlyWorking === true) {
    return 'BUSY';
  }

  // ── Location ──────────────────────────────────────────────────────────────
  if (
    !worker.locationUpdatedAt ||
    Date.now() - worker.locationUpdatedAt.getTime() > LOCATION_FRESHNESS_MS
  ) {
    return 'STALE_LOCATION';
  }
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
    case 'STALE_LOCATION':
      throw new ForbiddenException(
        'Update your location to view or bid on this job.',
      );
    case 'OUT_OF_RADIUS':
      throw new ForbiddenException('This job is outside your service area.');
    case 'NOT_OPEN':
    case 'ALREADY_ASSIGNED':
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
): void {
  assertEligibleForJob(worker, booking, {
    inspectingWorkerProfileId,
    radiusKm,
  });
}

export function isEligibleForInspectionBidding(
  worker: JobEligibilityWorker,
  booking: JobEligibilityBooking,
  inspectingWorkerProfileId: string | null,
  radiusKm?: number,
): boolean {
  return isEligibleForJob(worker, booking, {
    inspectingWorkerProfileId,
    radiusKm,
  });
}
