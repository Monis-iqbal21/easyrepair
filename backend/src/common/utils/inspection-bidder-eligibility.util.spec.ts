import { ForbiddenException } from '@nestjs/common';
import {
  AvailabilityStatus,
  WorkerOnboardingStatus,
  WorkerStatus,
} from '@prisma/client';
import {
  InspectionBidderWorkerProfile,
  assertEligibleForInspectionBidding,
  isEligibleForInspectionBidding,
} from './inspection-bidder-eligibility.util';

const BOOKING = { categoryId: 'cat-1', latitude: 24.86, longitude: 67.0 };
const INSPECTOR_ID = 'inspector-worker-id';

function eligibleWorker(
  overrides: Partial<InspectionBidderWorkerProfile> = {},
): InspectionBidderWorkerProfile {
  return {
    id: 'bidder-worker-id',
    status: WorkerStatus.ACTIVE,
    onboardingStatus: WorkerOnboardingStatus.APPROVED,
    profileCompleted: true,
    availabilityStatus: AvailabilityStatus.ONLINE,
    currentLat: 24.86,
    currentLng: 67.0,
    locationUpdatedAt: new Date(),
    skills: [{ categoryId: 'cat-1' }],
    ...overrides,
  };
}

describe('inspection-bidder-eligibility.util', () => {
  it('allows a fully eligible, nearby, online worker to bid', () => {
    expect(() =>
      assertEligibleForInspectionBidding(
        eligibleWorker(),
        BOOKING,
        INSPECTOR_ID,
      ),
    ).not.toThrow();
    expect(
      isEligibleForInspectionBidding(eligibleWorker(), BOOKING, INSPECTOR_ID),
    ).toBe(true);
  });

  it('rejects the original inspecting worker from bidding on their own reopened job', () => {
    const worker = eligibleWorker({ id: INSPECTOR_ID });
    expect(() =>
      assertEligibleForInspectionBidding(worker, BOOKING, INSPECTOR_ID),
    ).toThrow(ForbiddenException);
  });

  it('rejects an offline worker', () => {
    const worker = eligibleWorker({
      availabilityStatus: AvailabilityStatus.OFFLINE,
    });
    expect(() =>
      assertEligibleForInspectionBidding(worker, BOOKING, INSPECTOR_ID),
    ).toThrow(ForbiddenException);
    expect(isEligibleForInspectionBidding(worker, BOOKING, INSPECTOR_ID)).toBe(
      false,
    );
  });

  it('rejects a worker more than 20km away', () => {
    // Roughly 40km north of the booking's latitude.
    const worker = eligibleWorker({ currentLat: 25.22, currentLng: 67.0 });
    expect(() =>
      assertEligibleForInspectionBidding(worker, BOOKING, INSPECTOR_ID),
    ).toThrow(ForbiddenException);
  });

  it('rejects a worker with stale (>30min old) GPS even if coordinates are nearby', () => {
    const worker = eligibleWorker({
      locationUpdatedAt: new Date(Date.now() - 31 * 60 * 1000),
    });
    expect(() =>
      assertEligibleForInspectionBidding(worker, BOOKING, INSPECTOR_ID),
    ).toThrow(ForbiddenException);
  });

  it('rejects a worker whose category/skills do not match the booking', () => {
    const worker = eligibleWorker({ skills: [{ categoryId: 'cat-other' }] });
    expect(() =>
      assertEligibleForInspectionBidding(worker, BOOKING, INSPECTOR_ID),
    ).toThrow(ForbiddenException);
  });

  it('rejects a worker not yet approved/active/profile-completed', () => {
    expect(() =>
      assertEligibleForInspectionBidding(
        eligibleWorker({ status: WorkerStatus.SUSPENDED }),
        BOOKING,
        INSPECTOR_ID,
      ),
    ).toThrow(ForbiddenException);
    expect(() =>
      assertEligibleForInspectionBidding(
        eligibleWorker({
          onboardingStatus: WorkerOnboardingStatus.SUBMITTED_FOR_REVIEW,
        }),
        BOOKING,
        INSPECTOR_ID,
      ),
    ).toThrow(ForbiddenException);
    expect(() =>
      assertEligibleForInspectionBidding(
        eligibleWorker({ profileCompleted: false }),
        BOOKING,
        INSPECTOR_ID,
      ),
    ).toThrow(ForbiddenException);
  });

  it('rejects a worker excluded from this specific booking (e.g. cancelled after being hired)', () => {
    const worker = eligibleWorker();
    const bookingWithExclusion = {
      ...BOOKING,
      workerExclusions: [{ workerProfileId: worker.id }],
    };
    expect(() =>
      assertEligibleForInspectionBidding(
        worker,
        bookingWithExclusion,
        INSPECTOR_ID,
      ),
    ).toThrow(ForbiddenException);
    expect(
      isEligibleForInspectionBidding(
        worker,
        bookingWithExclusion,
        INSPECTOR_ID,
      ),
    ).toBe(false);
  });

  it('does not reject a worker excluded from a DIFFERENT booking', () => {
    const worker = eligibleWorker();
    const bookingWithOtherExclusion = {
      ...BOOKING,
      workerExclusions: [{ workerProfileId: 'someone-else' }],
    };
    expect(() =>
      assertEligibleForInspectionBidding(
        worker,
        bookingWithOtherExclusion,
        INSPECTOR_ID,
      ),
    ).not.toThrow();
  });
});
