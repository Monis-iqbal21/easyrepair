import { ForbiddenException } from '@nestjs/common';
import {
  AvailabilityStatus,
  BookingStatus,
  WorkerOnboardingStatus,
  WorkerStatus,
} from '@prisma/client';
import {
  DEFAULT_JOB_MATCH_RADIUS_KM,
  JOB_DISCOVERY_WINDOW_MS,
  JobEligibilityWorker,
  WORKER_PRESENCE_STALE_MS,
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
    lastSeenAt: new Date(),
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
    [
      'STALE_PRESENCE',
      { lastSeenAt: new Date(Date.now() - WORKER_PRESENCE_STALE_MS - 1000) },
    ],
    ['STALE_PRESENCE', { lastSeenAt: null }],
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

  // ── Presence lease (independent of GPS/location freshness) ────────────────
  describe('presence lease', () => {
    it('accepts a worker just inside the stale window', () => {
      const worker = eligibleWorker({
        lastSeenAt: new Date(Date.now() - WORKER_PRESENCE_STALE_MS + 60_000),
      });
      expect(checkJobEligibility(worker, OPEN_BOOKING)).toBeNull();
    });

    it('rejects a worker just past the stale window', () => {
      const worker = eligibleWorker({
        lastSeenAt: new Date(Date.now() - WORKER_PRESENCE_STALE_MS - 60_000),
      });
      expect(checkJobEligibility(worker, OPEN_BOOKING)).toBe(
        'STALE_PRESENCE',
      );
    });

    it('rejects a fresh-location worker whose presence lease is stale', () => {
      // Fresh GPS alone must never substitute for a live presence lease.
      const worker = eligibleWorker({
        locationUpdatedAt: new Date(),
        lastSeenAt: new Date(Date.now() - WORKER_PRESENCE_STALE_MS - 1000),
      });
      expect(checkJobEligibility(worker, OPEN_BOOKING)).toBe(
        'STALE_PRESENCE',
      );
    });

    it('rejects a fresh-presence worker whose GPS is stale (checks are independent)', () => {
      const worker = eligibleWorker({
        locationUpdatedAt: new Date(Date.now() - 31 * 60 * 1000),
        lastSeenAt: new Date(),
      });
      expect(checkJobEligibility(worker, OPEN_BOOKING)).toBe(
        'STALE_LOCATION',
      );
    });
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

  // ── Discovery window (New Jobs marketplace visibility, not deletion) ──────
  describe('48h discovery window', () => {
    it('accepts a job just inside the window when createdAt is supplied', () => {
      const booking = {
        ...OPEN_BOOKING,
        createdAt: new Date(Date.now() - JOB_DISCOVERY_WINDOW_MS + 60_000),
      };
      expect(checkJobEligibility(eligibleWorker(), booking)).toBeNull();
    });

    it('rejects a job just past the window with DISCOVERY_WINDOW_EXPIRED', () => {
      const booking = {
        ...OPEN_BOOKING,
        createdAt: new Date(Date.now() - JOB_DISCOVERY_WINDOW_MS - 60_000),
      };
      expect(checkJobEligibility(eligibleWorker(), booking)).toBe(
        'DISCOVERY_WINDOW_EXPIRED',
      );
    });

    it('skips the check entirely when the caller omits createdAt (partial projections)', () => {
      // OPEN_BOOKING itself has no createdAt — must not be treated as "age
      // zero" or "always expired", just "not checked here".
      expect(checkJobEligibility(eligibleWorker(), OPEN_BOOKING)).toBeNull();
    });

    it('surfaces the same generic "no longer open" message as NOT_OPEN/ALREADY_ASSIGNED', () => {
      const booking = {
        ...OPEN_BOOKING,
        createdAt: new Date(Date.now() - JOB_DISCOVERY_WINDOW_MS - 60_000),
      };
      expect(() => assertEligibleForJob(eligibleWorker(), booking)).toThrow(
        'This job is no longer open.',
      );
    });
  });

  // ── requireLivePresence: marketplace browsing vs. live instant matching ──
  describe('requireLivePresence (marketplace browsing/bidding)', () => {
    it('defaults to true — OFFLINE is still rejected when the option is omitted (live matching unchanged)', () => {
      const worker = eligibleWorker({
        availabilityStatus: AvailabilityStatus.OFFLINE,
      });
      expect(checkJobEligibility(worker, OPEN_BOOKING)).toBe('OFFLINE');
    });

    it('explicit true behaves identically to the default', () => {
      const worker = eligibleWorker({
        availabilityStatus: AvailabilityStatus.OFFLINE,
      });
      expect(
        checkJobEligibility(worker, OPEN_BOOKING, {
          requireLivePresence: true,
        }),
      ).toBe('OFFLINE');
    });

    it('false allows a manually OFFLINE worker through', () => {
      const worker = eligibleWorker({
        availabilityStatus: AvailabilityStatus.OFFLINE,
      });
      expect(
        checkJobEligibility(worker, OPEN_BOOKING, {
          requireLivePresence: false,
        }),
      ).toBeNull();
    });

    it('false also skips the presence-lease and location-freshness checks', () => {
      const worker = eligibleWorker({
        availabilityStatus: AvailabilityStatus.OFFLINE,
        lastSeenAt: null,
        locationUpdatedAt: new Date(Date.now() - 60 * 60 * 1000),
      });
      expect(
        checkJobEligibility(worker, OPEN_BOOKING, {
          requireLivePresence: false,
        }),
      ).toBeNull();
    });

    it('false still enforces BUSY (a worker mid-job is not offered new work)', () => {
      const worker = eligibleWorker({
        availabilityStatus: AvailabilityStatus.OFFLINE,
        currentlyWorking: true,
      });
      expect(
        checkJobEligibility(worker, OPEN_BOOKING, {
          requireLivePresence: false,
        }),
      ).toBe('BUSY');
    });

    it('false still enforces the radius, using whatever location is on file', () => {
      const worker = eligibleWorker({
        availabilityStatus: AvailabilityStatus.OFFLINE,
        currentLat: latOffsetFor(25),
      });
      expect(
        checkJobEligibility(worker, OPEN_BOOKING, {
          requireLivePresence: false,
        }),
      ).toBe('OUT_OF_RADIUS');
    });

    it('false still enforces account/category/exclusion checks', () => {
      const notApproved = eligibleWorker({
        availabilityStatus: AvailabilityStatus.OFFLINE,
        status: WorkerStatus.SUSPENDED,
      });
      expect(
        checkJobEligibility(notApproved, OPEN_BOOKING, {
          requireLivePresence: false,
        }),
      ).toBe('NOT_APPROVED');
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
