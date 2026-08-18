import { BookingLane, BookingStatus } from '@prisma/client';
import { deriveInspectionFeePaid } from '../../common/utils/inspection-fee.util';
import { checkJobEligibility } from '../../common/utils/job-eligibility.util';
import { AvailabilityStatus, WorkerOnboardingStatus, WorkerStatus } from '@prisma/client';

/**
 * The whole justification for adding `attachedInspectionBookingId` instead of
 * reusing `sourceInspectionBookingId` was that the latter carries real
 * business behavior. These tests pin that separation down: a booking carrying
 * ONLY an attached (informational) reference must behave exactly like an
 * ordinary bidding job everywhere that matters.
 *
 * If someone later "simplifies" the two fields into one, these fail.
 */
describe('attached inspection reference — behavioral isolation', () => {
  // ── 1. Inspection-fee-paid derivation ──────────────────────────────────
  describe('inspectionFeePaid derivation', () => {
    it('an ordinary bidding job with an ATTACHED report reports no fee concept', () => {
      // The old inspection's fee belongs to that closed transaction; this new
      // job must never claim it.
      const booking = {
        lane: BookingLane.BIDDING,
        status: BookingStatus.PENDING,
        sourceInspectionBookingId: null,
        // deriveInspectionFeePaid never reads the attached field at all —
        // that is exactly the point.
        attachedInspectionBookingId: 'old-inspection-1',
      } as never;

      expect(deriveInspectionFeePaid(booking)).toBeNull();
    });

    it('the SPAWNED post-inspection repair still derives from its source (unchanged)', () => {
      const booking = {
        lane: BookingLane.BIDDING,
        status: BookingStatus.PENDING,
        sourceInspectionBookingId: 'inspection-1',
        sourceInspectionBooking: { status: BookingStatus.COMPLETED },
      };

      expect(deriveInspectionFeePaid(booking)).toBe(true);
    });
  });

  // ── 2. Original-inspector bidding exclusion ────────────────────────────
  describe('original inspector eligibility', () => {
    const JOB_LAT = 24.86;
    const JOB_LNG = 67.0;
    const INSPECTOR_ID = 'inspector-1';

    const inspector = {
      id: INSPECTOR_ID,
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
    };

    const openJob = {
      categoryId: 'cat-1',
      latitude: JOB_LAT,
      longitude: JOB_LNG,
      status: BookingStatus.PENDING,
      workerProfileId: null,
    };

    it('the original inspector MAY bid on a job that merely attached their old report', () => {
      // The attach flow passes no inspectingWorkerProfileId at all — the
      // closed inspection was already paid, so there is nobody to exclude.
      expect(checkJobEligibility(inspector, openJob)).toBeNull();
    });

    it('Find Other Ustaad still excludes the inspector (unchanged)', () => {
      expect(
        checkJobEligibility(inspector, openJob, {
          inspectingWorkerProfileId: INSPECTOR_ID,
        }),
      ).toBe('IS_INSPECTOR');
    });
  });
});

/**
 * Guards that no production code path silently starts keying off the new
 * field. Each of these modules implements one of the behaviors the attached
 * reference must NOT trigger.
 */
describe('attached inspection reference — no accidental coupling', () => {
  const fs = require('fs') as typeof import('fs');
  const read = (p: string) => fs.readFileSync(p, 'utf-8');

  it('inspection-fee derivation never reads the attached field', () => {
    expect(read('src/common/utils/inspection-fee.util.ts')).not.toContain(
      'attachedInspectionBookingId',
    );
  });

  it('worker earnings (labour-cost override) never reads the attached field', () => {
    expect(read('src/modules/workers/workers.repository.ts')).not.toContain(
      'attachedInspectionBookingId',
    );
  });

  it('the post-inspection bidding context / inspector exclusion never reads it', () => {
    const bids = read('src/modules/bids/bids.service.ts');
    // The field appears in this file exactly once — passed through to the
    // New Jobs DTO so the app can show the report link. The helper that
    // decides "is this a post-inspection job, and which inspector must be
    // excluded" must never consult it, so assert against that method's own
    // body (its declaration onward), not the whole file.
    const helperBody = bids.slice(
      bids.indexOf('private _postInspectionBiddingContext'),
    );
    expect(helperBody).not.toContain('attachedInspectionBookingId');
  });

  it('broadcast/notification copy selection never reads it (no BIDDING_LINKED)', () => {
    expect(read('src/modules/matching/job-broadcast.service.ts')).not.toContain(
      'attachedInspectionBookingId',
    );
  });

  it('Find Other Ustaad idempotency still keys only on sourceInspectionBookingId', () => {
    const repo = read('src/modules/bookings/bookings.repository.ts');
    expect(repo).toContain('where: { sourceInspectionBookingId: params.originalBookingId }');
    // The attached field is written on create and read for validation, but is
    // never used as an idempotency lookup key.
    expect(repo).not.toContain(
      'where: { attachedInspectionBookingId',
    );
  });
});
