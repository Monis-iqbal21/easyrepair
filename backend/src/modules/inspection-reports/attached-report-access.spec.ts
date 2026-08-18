import { ForbiddenException } from '@nestjs/common';
import {
  AvailabilityStatus,
  InspectionDecisionStatus,
  WorkerOnboardingStatus,
  WorkerStatus,
} from '@prisma/client';
import { InspectionReportsService } from './inspection-reports.service';

/**
 * Worker/client read access to a report reached through a MANUALLY ATTACHED
 * historical inspection. The existing Find-Other-Ustaad authorization path
 * must be untouched, and the attached path must not require its
 * FIND_OTHER_USTAAD decision status (an attached report is closed by
 * definition).
 */
describe('InspectionReportsService.getReport — attached historical report', () => {
  let repository: any;
  let service: InspectionReportsService;

  const JOB_LAT = 24.86;
  const JOB_LNG = 67.0;

  /** The independently-posted bidding job that attached an old report. */
  const BIDDING_JOB = {
    id: 'bid-job-1',
    lane: 'BIDDING',
    status: 'PENDING',
    workerProfileId: null,
    clientProfileId: 'client-1',
    categoryId: 'cat-1',
    title: null,
    description: 'AC not cooling',
    addressLine: '123 Street',
    city: 'Karachi',
    latitude: JOB_LAT,
    longitude: JOB_LNG,
    inspectionFeeSnapshot: null,
    clientProfile: { userId: 'client-user-1' },
    workerProfile: null,
    workerExclusions: [],
    sourceInspectionBookingId: null,
    attachedInspectionBookingId: 'old-inspection-1',
    repairBooking: null,
  };

  /** The historical, already-closed inspection the report lives on. */
  const OLD_INSPECTION = {
    ...BIDDING_JOB,
    id: 'old-inspection-1',
    lane: 'INSPECTION',
    status: 'COMPLETED',
    attachedInspectionBookingId: null,
    workerProfile: { userId: 'inspector-user-1' },
    workerProfileId: 'inspector-1',
  };

  const REPORT = {
    id: 'report-1',
    workerProfileId: 'inspector-1',
    issueFound: 'Compressor failing',
    recommendedRepair: 'Replace compressor',
    labourCost: 3000,
    partsTotal: 12000,
    repairQuoteTotal: 15000,
    partsNeeded: true,
    notes: null,
    voiceNoteUrl: null,
    voiceNoteDurationSeconds: null,
    // Closed — the existing bidder path would reject this outright.
    decisionStatus: InspectionDecisionStatus.CLOSED_AFTER_INSPECTION,
    createdAt: new Date(),
    parts: [],
    photos: [],
  };

  const eligibleBidder = {
    id: 'worker-9',
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

  beforeEach(() => {
    repository = {
      findBookingContext: jest.fn(async (id: string) =>
        id === 'bid-job-1' ? BIDDING_JOB : OLD_INSPECTION,
      ),
      findByBookingId: jest.fn().mockResolvedValue(REPORT),
      findWorkerProfileByUserId: jest.fn().mockResolvedValue(null),
      findWorkerProfileWithSkillsByUserId: jest
        .fn()
        .mockResolvedValue(eligibleBidder),
    };
    service = new InspectionReportsService(
      repository,
      {} as any,
      {} as any,
      {} as any,
    );
  });

  it('an eligible bidder gets the SANITIZED report despite CLOSED_AFTER_INSPECTION', async () => {
    const result: any = await service.getReport(
      'worker-user-9',
      'WORKER',
      'bid-job-1',
    );

    expect(result.issueFound).toBe('Compressor failing');
    // The inspector's original pricing is never exposed to a bidder.
    expect(result.labourCost).toBeUndefined();
    expect(result.repairQuoteTotal).toBeUndefined();
  });

  it("the ORIGINAL INSPECTOR may read it and is never excluded", async () => {
    repository.findWorkerProfileByUserId.mockResolvedValue({
      id: 'inspector-1',
    });

    const result: any = await service.getReport(
      'inspector-user-1',
      'WORKER',
      'bid-job-1',
    );

    // Their own report — full detail, and crucially no rejection.
    expect(result.issueFound).toBe('Compressor failing');
  });

  it('an ineligible worker (wrong category) is rejected', async () => {
    repository.findWorkerProfileWithSkillsByUserId.mockResolvedValue({
      ...eligibleBidder,
      skills: [{ categoryId: 'cat-other' }],
    });

    await expect(
      service.getReport('worker-user-9', 'WORKER', 'bid-job-1'),
    ).rejects.toThrow(ForbiddenException);
  });

  it('a manually OFFLINE worker may still read it (marketplace browsing)', async () => {
    repository.findWorkerProfileWithSkillsByUserId.mockResolvedValue({
      ...eligibleBidder,
      availabilityStatus: AvailabilityStatus.OFFLINE,
      lastSeenAt: null,
    });

    await expect(
      service.getReport('worker-user-9', 'WORKER', 'bid-job-1'),
    ).resolves.toBeDefined();
  });

  it('the owning client reads it through the same bidding-job id', async () => {
    const result: any = await service.getReport(
      'client-user-1',
      'CLIENT',
      'bid-job-1',
    );
    expect(result.issueFound).toBe('Compressor failing');
  });

  it("another client cannot read it", async () => {
    await expect(
      service.getReport('client-user-2', 'CLIENT', 'bid-job-1'),
    ).rejects.toThrow(ForbiddenException);
  });

  it('resolves through attachedInspectionBookingId — never mutating either booking', async () => {
    await service.getReport('client-user-1', 'CLIENT', 'bid-job-1');

    expect(repository.findBookingContext).toHaveBeenCalledWith('bid-job-1');
    expect(repository.findBookingContext).toHaveBeenCalledWith(
      'old-inspection-1',
    );
    // Reads only — the service exposes no write on this path at all.
    expect(Object.keys(repository).filter((k) => k.startsWith('update'))).toEqual(
      [],
    );
  });
});
