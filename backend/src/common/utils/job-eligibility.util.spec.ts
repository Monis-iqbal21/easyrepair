import { ForbiddenException } from '@nestjs/common';
import {
  AvailabilityStatus,
  BookingStatus,
  WorkerOnboardingStatus,
  WorkerStatus,
} from '@prisma/client';
import {
  DEFAULT_JOB_MATCH_RADIUS_KM,
  JobEligibilityWorker,
  assertEligibleForJob,
  checkJobEligibility,
  isEligibleForJob,
} from './job-eligibility.util';

/** Karachi. All fixtures are measured from here. */
const JOB_LAT = 24.86;
const JOB_LNG = 67.0;

/** A live, unassigned Direct-Bidding job: no InspectionReport, no link. */
const OPEN_BOOKING = {
  categoryId: 'cat-1',
  latitude: JOB_LAT,
  longitude: JOB_LNG,
  status: BookingStatus.PENDING,
  workerProfileId: null,
};

const INSPECTOR_ID = 'inspector-worker-id';

/** ~1 degree of latitude ≈ 111 km, so this offsets by roughly [km]. */
function latOffsetFor(km: number): number {
  return JOB_LAT + km / 111;
}

function eligibleWorker(
  overrides: Partial<JobEligibilityWorker> = {},
): JobEligibilityWorker {
  return {
    id: 'bidder-worker-id',
    status: WorkerStatus.ACTIVE,
    onboardingStatus: WorkerOnboardingStatus.APPROVED,
    profileCompleted: true,
    availabilityStatus: AvailabilityStatus.ONLINE,
    currentlyWorking: false,
    currentLat: JOB_LAT,
    currentLng: JOB_LNG,
    locationUpdatedAt: new Date(),
    skills: [{ categoryId: 'cat-1' }],
    ...overrides,
  };
}

describe('job-eligibility.util', () => {
  it('defaults to a 7 km match radius', () => {
    expect(DEFAULT_JOB_MATCH_RADIUS_KM).toBe(7);
  });

  it('allows a fully eligible, nearby, online, free worker', () => {
    expect(checkJobEligibility(eligibleWorker(), OPEN_BOOKING)).toBeNull();
    expect(isEligibleForJob(eligibleWorker(), OPEN_BOOKING)).toBe(true);
    expect(() =>
      assertEligibleForJob(eligibleWorker(), OPEN_BOOKING),
    ).not.toThrow();
  });

  // ── Radius boundary ───────────────────────────────────────────────────────
  describe('7 km radius boundary', () => {
    it('accepts a worker just inside the radius', () => {
      const worker = eligibleWorker({ currentLat: latOffsetFor(6.5) });
      expect(checkJobEligibility(worker, OPEN_BOOKING)).toBeNull();
    });

    it('rejects a worker just outside the radius', () => {
      const worker = eligibleWorker({ currentLat: latOffsetFor(7.5) });
      expect(checkJobEligibility(worker, OPEN_BOOKING)).toBe('OUT_OF_RADIUS');
    });

    it('rejects a worker with no coordinates at all', () => {
      const worker = eligibleWorker({ currentLat: null, currentLng: null });
      expect(checkJobEligibility(worker, OPEN_BOOKING)).toBe('OUT_OF_RADIUS');
    });

    it('honours a caller-supplied radius override', () => {
      const worker = eligibleWorker({ currentLat: latOffsetFor(12) });
      expect(checkJobEligibility(worker, OPEN_BOOKING)).toBe('OUT_OF_RADIUS');
      expect(
        checkJobEligibility(worker, OPEN_BOOKING, { radiusKm: 20 }),
      ).toBeNull();
    });
  });

  // ── Worker state ──────────────────────────────────────────────────────────
  it.each([
    ['OFFLINE', { availabilityStatus: AvailabilityStatus.OFFLINE }],
    ['OFFLINE', { availabilityStatus: AvailabilityStatus.BUSY }],
    ['BUSY', { currentlyWorking: true }],
    [
      'STALE_LOCATION',
      { locationUpdatedAt: new Date(Date.now() - 31 * 60 * 1000) },
    ],
    ['STALE_LOCATION', { locationUpdatedAt: null }],
    ['CATEGORY_MISMATCH', { skills: [{ categoryId: 'cat-other' }] }],
    ['NOT_APPROVED', { status: WorkerStatus.SUSPENDED }],
    [
      'NOT_APPROVED',
      { onboardingStatus: WorkerOnboardingStatus.SUBMITTED_FOR_REVIEW },
    ],
    ['NOT_APPROVED', { profileCompleted: false }],
  ])('rejects with %s', (reason, override) => {
    const worker = eligibleWorker(override as Partial<JobEligibilityWorker>);
    expect(checkJobEligibility(worker, OPEN_BOOKING)).toBe(reason);
    expect(isEligibleForJob(worker, OPEN_BOOKING)).toBe(false);
    expect(() => assertEligibleForJob(worker, OPEN_BOOKING)).toThrow(
      ForbiddenException,
    );
  });

  // ── Job state ─────────────────────────────────────────────────────────────
  it('rejects a job that is no longer PENDING', () => {
    const closed = { ...OPEN_BOOKING, status: BookingStatus.COMPLETED };
    expect(checkJobEligibility(eligibleWorker(), closed)).toBe('NOT_OPEN');
  });

  it('rejects a job that already has an assigned worker', () => {
    const assigned = { ...OPEN_BOOKING, workerProfileId: 'someone-else' };
    expect(checkJobEligibility(eligibleWorker(), assigned)).toBe(
      'ALREADY_ASSIGNED',
    );
  });

  it('skips the open/unassigned checks when the caller omits those fields', () => {
    // Partial projections (e.g. report-access checks) must still work.
    const partial = {
      categoryId: 'cat-1',
      latitude: JOB_LAT,
      longitude: JOB_LNG,
    };
    expect(checkJobEligibility(eligibleWorker(), partial)).toBeNull();
  });

  // ── Exclusions ────────────────────────────────────────────────────────────
  it('rejects a worker excluded from this specific booking', () => {
    const worker = eligibleWorker();
    const booking = {
      ...OPEN_BOOKING,
      workerExclusions: [{ workerProfileId: worker.id }],
    };
    expect(checkJobEligibility(worker, booking)).toBe('EXCLUDED');
  });

  it('does not reject a worker excluded from a DIFFERENT booking', () => {
    const booking = {
      ...OPEN_BOOKING,
      workerExclusions: [{ workerProfileId: 'someone-else' }],
    };
    expect(checkJobEligibility(eligibleWorker(), booking)).toBeNull();
  });

  it('rejects the original inspector on their own post-inspection repair job', () => {
    const worker = eligibleWorker({ id: INSPECTOR_ID });
    expect(
      checkJobEligibility(worker, OPEN_BOOKING, {
        inspectingWorkerProfileId: INSPECTOR_ID,
      }),
    ).toBe('IS_INSPECTOR');
  });

  // ── The critical lane-independence guarantee ──────────────────────────────
  //
  // A Direct-Bidding job has no InspectionReport and therefore a null
  // inspector id. That must mean ONLY "nobody to exclude" — it must never
  // short-circuit the universal checks, which is exactly the hole the old
  // `if (!postInspection.isOpen) return true` filter left open.
  describe('Direct Bidding (sourceInspectionBookingId == null, no report)', () => {
    it('is still ACCEPTED when the worker is genuinely eligible', () => {
      expect(
        checkJobEligibility(eligibleWorker(), OPEN_BOOKING, {
          inspectingWorkerProfileId: null,
        }),
      ).toBeNull();
    });

    it.each([
      ['OUT_OF_RADIUS', { currentLat: latOffsetFor(25) }],
      ['OFFLINE', { availabilityStatus: AvailabilityStatus.OFFLINE }],
      ['BUSY', { currentlyWorking: true }],
      [
        'STALE_LOCATION',
        { locationUpdatedAt: new Date(Date.now() - 45 * 60 * 1000) },
      ],
    ])(
      'is still REJECTED with %s even though there is no inspector to exclude',
      (reason, override) => {
        const worker = eligibleWorker(
          override as Partial<JobEligibilityWorker>,
        );
        expect(
          checkJobEligibility(worker, OPEN_BOOKING, {
            inspectingWorkerProfileId: null,
          }),
        ).toBe(reason);
      },
    );

    it('is still REJECTED once assigned, with a null inspector id', () => {
      expect(
        checkJobEligibility(
          eligibleWorker(),
          { ...OPEN_BOOKING, workerProfileId: 'hired-worker' },
          { inspectingWorkerProfileId: null },
        ),
      ).toBe('ALREADY_ASSIGNED');
    });
  });

  // ── Every user-facing message is Roman Urdu or plain English, never a code ─
  it('surfaces a Roman Urdu message for the busy case', () => {
    expect(() =>
      assertEligibleForJob(
        eligibleWorker({ currentlyWorking: true }),
        OPEN_BOOKING,
      ),
    ).toThrow(
      'Aap pehle se ek kaam par hain. Mukammal karne ke baad naya kaam lein.',
    );
  });
});
