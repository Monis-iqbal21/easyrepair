import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { InspectionReportsService } from './inspection-reports.service';

describe('InspectionReportsService', () => {
  let repository: any;
  let storageService: any;
  let notificationsService: any;
  let bookingsService: any;
  let service: InspectionReportsService;

  const BASE_REPORT = {
    id: 'report-1',
    bookingId: 'booking-1',
    workerProfileId: 'inspector-1',
    issueFound: 'Leaky pipe',
    recommendedRepair: 'Replace pipe',
    labourCost: 1000,
    partsNeeded: false,
    partsTotal: 0,
    repairQuoteTotal: 1000,
    notes: null,
    voiceNoteUrl: null,
    voiceNoteMimeType: null,
    voiceNoteDurationSeconds: null,
    decisionStatus: 'PENDING_CLIENT_DECISION',
    parts: [],
    photos: [],
    createdAt: new Date(),
    acceptedAt: null,
    closedAt: null,
  };

  const BASE_BOOKING = {
    id: 'booking-1',
    lane: 'INSPECTION',
    status: 'IN_PROGRESS',
    workerProfileId: 'inspector-1',
    categoryId: 'cat-1',
    latitude: 24.86,
    longitude: 67.0,
    inspectionFeeSnapshot: 500,
    clientProfile: { userId: 'client-user-1' },
    workerProfile: { userId: 'inspector-user-1' },
    workerExclusions: [],
  };

  beforeEach(() => {
    repository = {
      findBookingContext: jest.fn().mockResolvedValue(BASE_BOOKING),
      findByBookingId: jest.fn().mockResolvedValue(BASE_REPORT),
      findWorkerProfileByUserId: jest.fn(),
      findWorkerProfileWithSkillsByUserId: jest.fn(),
      markFindOtherUstaad: jest.fn().mockResolvedValue(undefined),
      markAccepted: jest.fn().mockResolvedValue({
        ...BASE_REPORT,
        decisionStatus: 'ACCEPTED_REPAIR',
      }),
      markClosed: jest.fn().mockResolvedValue({
        ...BASE_REPORT,
        decisionStatus: 'CLOSED_AFTER_INSPECTION',
      }),
    };
    storageService = {};
    notificationsService = { notify: jest.fn().mockResolvedValue(undefined) };
    bookingsService = {
      reopenInspectionForBidding: jest.fn().mockResolvedValue(undefined),
      rehireInspectingWorker: jest.fn().mockResolvedValue(undefined),
      setInspectionRepairPrice: jest.fn().mockResolvedValue(undefined),
      completeAfterInspectionClose: jest.fn().mockResolvedValue(undefined),
    };
    service = new InspectionReportsService(
      repository,
      storageService,
      notificationsService,
      bookingsService,
    );
  });

  // ── #1 Find Other Ustaad transition ─────────────────────────────────────
  it('transitions decisionStatus to FIND_OTHER_USTAAD and reopens the booking for bidding', async () => {
    repository.findBookingContext
      .mockResolvedValueOnce(BASE_BOOKING) // _authorizeClientDecision
      .mockResolvedValueOnce(BASE_BOOKING); // fresh re-fetch after mutation
    repository.findByBookingId
      .mockResolvedValueOnce(BASE_REPORT) // _authorizeClientDecision
      .mockResolvedValueOnce({
        ...BASE_REPORT,
        decisionStatus: 'FIND_OTHER_USTAAD',
      }); // fresh re-fetch

    const result = await service.findOtherUstaad('client-user-1', 'booking-1');

    expect(repository.markFindOtherUstaad).toHaveBeenCalledWith('report-1');
    expect(bookingsService.reopenInspectionForBidding).toHaveBeenCalledWith(
      'booking-1',
      'inspector-1',
      'cat-1',
      24.86,
      67.0,
    );
    expect(result.decisionStatus).toBe('FIND_OTHER_USTAAD');
  });

  it('rejects find-other-ustaad from a non-owning client', async () => {
    await expect(
      service.findOtherUstaad('someone-else-user-id', 'booking-1'),
    ).rejects.toThrow(ForbiddenException);
    expect(repository.markFindOtherUstaad).not.toHaveBeenCalled();
  });

  // ── #2 Duplicate transition request ─────────────────────────────────────
  it('rejects a second Find Other Ustaad request once the decision is no longer pending', async () => {
    repository.findByBookingId.mockResolvedValue({
      ...BASE_REPORT,
      decisionStatus: 'FIND_OTHER_USTAAD',
    });
    await expect(
      service.findOtherUstaad('client-user-1', 'booking-1'),
    ).rejects.toThrow(BadRequestException);
    expect(repository.markFindOtherUstaad).not.toHaveBeenCalled();
    expect(bookingsService.reopenInspectionForBidding).not.toHaveBeenCalled();
  });

  it('rejects a repeat "Accept Quote" request the same way (decision already made)', async () => {
    repository.findByBookingId.mockResolvedValue({
      ...BASE_REPORT,
      decisionStatus: 'ACCEPTED_REPAIR',
    });
    await expect(
      service.acceptQuote('client-user-1', 'booking-1'),
    ).rejects.toThrow(BadRequestException);
  });

  // ── #10 Inspector rehired ────────────────────────────────────────────────
  it('rehiring the original inspector reverts decisionStatus to ACCEPTED_REPAIR and uses the original quote as the work price', async () => {
    const reopenedBooking = {
      ...BASE_BOOKING,
      workerProfileId: null,
      workerProfile: null,
    };
    repository.findBookingContext.mockResolvedValue(reopenedBooking);
    repository.findByBookingId.mockResolvedValue({
      ...BASE_REPORT,
      decisionStatus: 'FIND_OTHER_USTAAD',
    });

    const result = await service.hireInspectingWorker(
      'client-user-1',
      'booking-1',
    );

    expect(bookingsService.rehireInspectingWorker).toHaveBeenCalledWith(
      'client-user-1',
      'booking-1',
      'inspector-1',
      1000, // repairQuoteTotal
      1000, // labourCost
    );
    expect(repository.markAccepted).toHaveBeenCalledWith('report-1');
    expect(result.decisionStatus).toBe('ACCEPTED_REPAIR');
  });

  it('rejects hiring the inspector when the booking is not in the FIND_OTHER_USTAAD state', async () => {
    repository.findByBookingId.mockResolvedValue({
      ...BASE_REPORT,
      decisionStatus: 'PENDING_CLIENT_DECISION',
    });
    await expect(
      service.hireInspectingWorker('client-user-1', 'booking-1'),
    ).rejects.toThrow(BadRequestException);
    expect(bookingsService.rehireInspectingWorker).not.toHaveBeenCalled();
  });

  // ── #15 Existing Inspection outcomes regression ─────────────────────────
  it('accept-quote (same inspecting worker continues) sets ACCEPTED_REPAIR and waives the fee via setInspectionRepairPrice', async () => {
    const result = await service.acceptQuote('client-user-1', 'booking-1');
    expect(repository.markAccepted).toHaveBeenCalledWith('report-1');
    expect(bookingsService.setInspectionRepairPrice).toHaveBeenCalledWith(
      'booking-1',
      1000,
      1000,
    );
    expect(result.decisionStatus).toBe('ACCEPTED_REPAIR');
  });

  it('close-after-inspection sets CLOSED_AFTER_INSPECTION and completes the booking', async () => {
    const result = await service.closeAfterInspection(
      'client-user-1',
      'booking-1',
    );
    expect(repository.markClosed).toHaveBeenCalledWith('report-1');
    expect(bookingsService.completeAfterInspectionClose).toHaveBeenCalledWith(
      'booking-1',
    );
    expect(result.decisionStatus).toBe('CLOSED_AFTER_INSPECTION');
  });

  // ── #6 Sanitized report hides all prices ────────────────────────────────
  describe('sanitized report for an eligible bidder', () => {
    const REOPENED_BOOKING = {
      ...BASE_BOOKING,
      workerProfileId: null,
      workerProfile: null,
    };
    const ELIGIBLE_BIDDER_PROFILE = {
      id: 'bidder-1',
      status: 'ACTIVE',
      onboardingStatus: 'APPROVED',
      profileCompleted: true,
      availabilityStatus: 'ONLINE',
      currentLat: 24.86,
      currentLng: 67.0,
      locationUpdatedAt: new Date(),
      skills: [{ categoryId: 'cat-1' }],
    };

    beforeEach(() => {
      repository.findBookingContext.mockResolvedValue(REOPENED_BOOKING);
      repository.findByBookingId.mockResolvedValue({
        ...BASE_REPORT,
        decisionStatus: 'FIND_OTHER_USTAAD',
      });
      repository.findWorkerProfileWithSkillsByUserId.mockResolvedValue(
        ELIGIBLE_BIDDER_PROFILE,
      );
    });

    it('omits every price field for a not-yet-hired eligible bidder', async () => {
      const dto: any = await service.getReport(
        'bidder-user-1',
        'WORKER',
        'booking-1',
      );
      expect(dto).not.toHaveProperty('labourCost');
      expect(dto).not.toHaveProperty('partsTotal');
      expect(dto).not.toHaveProperty('repairQuoteTotal');
      expect(dto).not.toHaveProperty('inspectionFeeSnapshot');
      expect(dto.issueFound).toBe('Leaky pipe');
      expect(dto.decisionStatus).toBe('FIND_OTHER_USTAAD');
    });

    it('still lets the original inspector see their own full report with pricing, even after reassignment', async () => {
      repository.findWorkerProfileByUserId.mockResolvedValue({
        id: 'inspector-1',
      });
      const dto: any = await service.getReport(
        'inspector-user-1',
        'WORKER',
        'booking-1',
      );
      expect(dto.labourCost).toBe(1000);
      expect(dto.repairQuoteTotal).toBe(1000);
    });

    it('rejects a worker whose category does not match', async () => {
      repository.findWorkerProfileWithSkillsByUserId.mockResolvedValue({
        ...ELIGIBLE_BIDDER_PROFILE,
        skills: [{ categoryId: 'cat-other' }],
      });
      await expect(
        service.getReport('bidder-user-1', 'WORKER', 'booking-1'),
      ).rejects.toThrow(ForbiddenException);
    });
  });
});
