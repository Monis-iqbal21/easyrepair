import { ForbiddenException } from '@nestjs/common';
import {
  AvailabilityStatus,
  WorkerOnboardingStatus,
  WorkerStatus,
} from '@prisma/client';
import { haversineKm } from './geo.util';

/**
 * Reopened "Find Other Ustaad" jobs use the same widest ring the legacy
 * nearby-worker search ladder ever reaches for INSPECTION lane (see
 * BookingsRepository's legacyLadderKm) — a worker further away than this was
 * never going to be notified either, so bidding/viewing should match.
 */
const MAX_INSPECTION_BID_RADIUS_KM = 20;

/** Same 30-minute GPS freshness rule enforced by the nearby-worker query. */
const LOCATION_FRESHNESS_MS = 30 * 60 * 1000;

export interface InspectionBidderWorkerProfile {
  id: string;
  status: WorkerStatus;
  onboardingStatus: WorkerOnboardingStatus;
  profileCompleted: boolean;
  availabilityStatus: AvailabilityStatus;
  currentLat: number | null;
  currentLng: number | null;
  locationUpdatedAt: Date | null;
  skills: { categoryId: string }[];
}

export interface InspectionBidderBooking {
  categoryId: string;
  latitude: number;
  longitude: number;
  /** Workers excluded from this specific booking (e.g. cancelled after being
   * hired) — must never be re-offered/re-listed for it, even after relist. */
  workerExclusions?: { workerProfileId: string }[];
}

/** Reason codes, used by the throwing assert to pick a user-facing message. */
type IneligibilityReason =
  | 'NOT_APPROVED'
  | 'IS_INSPECTOR'
  | 'EXCLUDED'
  | 'CATEGORY_MISMATCH'
  | 'OFFLINE'
  | 'STALE_LOCATION'
  | 'OUT_OF_RADIUS'
  | null;

function _checkEligibility(
  workerProfile: InspectionBidderWorkerProfile,
  booking: InspectionBidderBooking,
  inspectingWorkerProfileId: string | null,
): IneligibilityReason {
  if (
    workerProfile.status !== WorkerStatus.ACTIVE ||
    workerProfile.onboardingStatus !== WorkerOnboardingStatus.APPROVED ||
    !workerProfile.profileCompleted
  ) {
    return 'NOT_APPROVED';
  }
  if (workerProfile.id === inspectingWorkerProfileId) {
    return 'IS_INSPECTOR';
  }
  if (
    booking.workerExclusions?.some(
      (e) => e.workerProfileId === workerProfile.id,
    )
  ) {
    return 'EXCLUDED';
  }
  const categoryMatches = workerProfile.skills.some(
    (s) => s.categoryId === booking.categoryId,
  );
  if (!categoryMatches) {
    return 'CATEGORY_MISMATCH';
  }
  if (workerProfile.availabilityStatus !== AvailabilityStatus.ONLINE) {
    return 'OFFLINE';
  }
  if (
    !workerProfile.locationUpdatedAt ||
    Date.now() - workerProfile.locationUpdatedAt.getTime() >
      LOCATION_FRESHNESS_MS
  ) {
    return 'STALE_LOCATION';
  }
  const distanceKm = haversineKm(
    booking.latitude,
    booking.longitude,
    workerProfile.currentLat,
    workerProfile.currentLng,
  );
  if (distanceKm == null || distanceKm > MAX_INSPECTION_BID_RADIUS_KM) {
    return 'OUT_OF_RADIUS';
  }
  return null;
}

/**
 * Backend-enforced gate for browsing/viewing/bidding on a reopened
 * (INSPECTION + FIND_OTHER_USTAAD) booking as an eligible bidder — mirrors
 * the same approved/active/profile-completed/online/category/radius/fresh-
 * GPS criteria used by the nearby-worker notification pipeline, plus an
 * explicit exclusion of the original inspecting Ustaad. Intentionally NOT
 * applied to normal BIDDING lane, which deliberately allows offline/distant
 * browsing — scope this only to the reopened-inspection case.
 */
export function assertEligibleForInspectionBidding(
  workerProfile: InspectionBidderWorkerProfile,
  booking: InspectionBidderBooking,
  inspectingWorkerProfileId: string | null,
): void {
  const reason = _checkEligibility(
    workerProfile,
    booking,
    inspectingWorkerProfileId,
  );
  switch (reason) {
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
    case 'STALE_LOCATION':
      throw new ForbiddenException(
        'Update your location to view or bid on this job.',
      );
    case 'OUT_OF_RADIUS':
      throw new ForbiddenException('This job is outside your service area.');
    default:
      return;
  }
}

/**
 * Non-throwing variant for filtering lists (e.g. the worker New Jobs feed) —
 * same criteria as assertEligibleForInspectionBidding, without the inspector
 * exclusion (a job the caller inspected should simply be excluded by the
 * caller using its own workerProfileId check, not hidden as "ineligible").
 */
export function isEligibleForInspectionBidding(
  workerProfile: InspectionBidderWorkerProfile,
  booking: InspectionBidderBooking,
  inspectingWorkerProfileId: string | null,
): boolean {
  return (
    _checkEligibility(workerProfile, booking, inspectingWorkerProfileId) ===
    null
  );
}
