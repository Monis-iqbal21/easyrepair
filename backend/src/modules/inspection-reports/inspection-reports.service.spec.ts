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
    clientProfileId: 'client-1',
    categoryId: 'cat-1',
    title: null,
    description: 'AC thanda nahi kar raha',
    addressLine: '123 Street',
    city: 'Karachi',
    latitude: 24.86,
    longitude: 67.0,
    inspectionFeeSnapshot: 500,
    clientProfile: { userId: 'client-user-1' },
    workerProfile: { userId: 'inspector-user-1' },
    workerExclusions: [],
    sourceInspectionBookingId: null,
    repairBooking: null,
  };

  /** The completed inspection booking once the linked child repair exists. */
  const CLOSED_BOOKING_WITH_CHILD = {
    ...BASE_BOOKING,
    status: 'COMPLETED',
    repairBooking: {
      id: 'child-1',
      status: 'PENDING',
      categoryId: 'cat-1',
      latitude: 24.86,
      longitude: 67.0,
      workerExclusions: [],
      workerProfile: null,
    },
  };

  beforeEach(() => {
    repository = {
      findBookingContext: jest.fn().mockResolvedValue(BASE_BOOKING),
      findByBookingId: jest.fn().mockResolvedValue(BASE_REPORT),
      findWorkerProfileByUserId: jest.fn(),
      findWorkerProfileWithSkillsByUserId: jest.fn(),
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
      closeInspectionAndOpenRepairBidding: jest
        .fn()
        .mockResolvedValue('child-1'),
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

  // ── #1 Find Other Ustaad closes the inspection + spawns the linked child ──
  it('delegates to the atomic close-and-spawn with the report-derived description and returns linkedRepairBookingId', async () => {
    repository.findBookingContext
      .mockResolvedValueOnce(BASE_BOOKING) // pre-check
      .mockResolvedValueOnce(CLOSED_BOOKING_WITH_CHILD); // fresh re-fetch
    repository.findByBookingId
      .mockResolvedValueOnce(BASE_REPORT) // pre-check
      .mockResolvedValueOnce({
        ...BASE_REPORT,
        decisionStatus: 'FIND_OTHER_USTAAD',
      }); // fresh re-fetch

    const result = await service.findOtherUstaad('client-user-1', 'booking-1');

    expect(
      bookingsService.closeInspectionAndOpenRepairBidding,
    ).toHaveBeenCalledTimes(1);
    expect(
      bookingsService.closeInspectionAndOpenRepairBidding,
    ).toHaveBeenCalledWith({
      reportId: 'report-1',
      originalBookingId: 'booking-1',
      inspectingWorkerProfileId: 'inspector-1',
      clientProfileId: 'client-1',
      categoryId: 'cat-1',
      title: null,
      // #7 — problem description auto-built from the report's findings, the
      // client never re-enters it.
      description: 'Leaky pipe\n\nReplace pipe',
      addressLine: '123 Street',
      city: 'Karachi',
      latitude: 24.86,
      longitude: 67.0,
    });
    expect(result.decisionStatus).toBe('FIND_OTHER_USTAAD');
    expect(result.linkedRepairBookingId).toBe('child-1');
  });

  it('falls back to the original booking description when the report has no findings text', async () => {
    repository.findByBookingId
      .mockResolvedValueOnce({
        ...BASE_REPORT,
        issueFound: null,
        recommendedRepair: '   ',
      })
      .mockResolvedValueOnce({
        ...BASE_REPORT,
        decisionStatus: 'FIND_OTHER_USTAAD',
      });
    repository.findBookingContext
      .mockResolvedValueOnce(BASE_BOOKING)
      .mockResolvedValueOnce(CLOSED_BOOKING_WITH_CHILD);

    await service.findOtherUstaad('client-user-1', 'booking-1');

    expect(
      bookingsService.closeInspectionAndOpenRepairBidding,
    ).toHaveBeenCalledWith(
      expect.objectContaining({ description: 'AC thanda nahi kar raha' }),
    );
  });

  it('rejects find-other-ustaad from a non-owning client', async () => {
    await expect(
      service.findOtherUstaad('someone-else-user-id', 'booking-1'),
    ).rejects.toThrow(ForbiddenException);
    expect(
      bookingsService.closeInspectionAndOpenRepairBidding,
    ).not.toHaveBeenCalled();
  });

  // ── #6 Retry / double-tap is an idempotent success, not an error ────────
  it('treats a repeat Find Other Ustaad as an idempotent replay returning the same linkedRepairBookingId', async () => {
    repository.findBookingContext.mockResolvedValue(CLOSED_BOOKING_WITH_CHILD);
    repository.findByBookingId.mockResolvedValue({
      ...BASE_REPORT,
      decisionStatus: 'FIND_OTHER_USTAAD',
    });

    const result = await service.findOtherUstaad('client-user-1', 'booking-1');

    // Still routed through the same atomic method — its transactional guard
    // (not this pre-check) is the authoritative idempotency arbiter.
    expect(
      bookingsService.closeInspectionAndOpenRepairBidding,
    ).toHaveBeenCalledTimes(1);
    expect(result.linkedRepairBookingId).toBe('child-1');
    expect(result.decisionStatus).toBe('FIND_OTHER_USTAAD');
  });

  it('still rejects Find Other Ustaad when the report was decided differently (ACCEPTED_REPAIR)', async () => {
    repository.findByBookingId.mockResolvedValue({
      ...BASE_REPORT,
      decisionStatus: 'ACCEPTED_REPAIR',
    });
    await expect(
      service.findOtherUstaad('client-user-1', 'booking-1'),
    ).rejects.toThrow(BadRequestException);
    expect(
      bookingsService.closeInspectionAndOpenRepairBidding,
    ).not.toHaveBeenCalled();
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

  // ── #10 Inspector rehired (old-style same-row records) ──────────────────
  it('old-style rehire (no linked child) reverts decisionStatus to ACCEPTED_REPAIR and targets the same booking', async () => {
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

  // ── #10 Inspector rehired (new linked-child flow) ───────────────────────
  it('new-style rehire targets the linked CHILD booking and never flips the report off FIND_OTHER_USTAAD', async () => {
    // Called with the child id — the page the client is actually on.
    const childCtx = {
      ...BASE_BOOKING,
      id: 'child-1',
      lane: 'BIDDING',
      status: 'PENDING',
      workerProfileId: null,
      workerProfile: null,
      sourceInspectionBookingId: 'booking-1',
      repairBooking: null,
    };
    repository.findBookingContext.mockImplementation((id: string) =>
      Promise.resolve(id === 'child-1' ? childCtx : CLOSED_BOOKING_WITH_CHILD),
    );
    repository.findByBookingId.mockResolvedValue({
      ...BASE_REPORT,
      decisionStatus: 'FIND_OTHER_USTAAD',
    });

    const result = await service.hireInspectingWorker(
      'client-user-1',
      'child-1',
    );

    expect(bookingsService.rehireInspectingWorker).toHaveBeenCalledWith(
      'client-user-1',
      'child-1', // the linked repair booking, not the completed inspection
      'inspector-1',
      1000,
      1000,
    );
    // #7 — the completed inspection's fee-based earning derives from the
    // report staying FIND_OTHER_USTAAD; rehire must never rewrite it.
    expect(repository.markAccepted).not.toHaveBeenCalled();
    expect(result.decisionStatus).toBe('FIND_OTHER_USTAAD');
    expect(result.linkedRepairBookingId).toBe('child-1');
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

  // ── New repair worker (hired via Find Other Ustaad bidding, after the
  // original inspector already submitted a report) must never be able to
  // submit a second report through the API — regardless of role, a report
  // already existing for this booking is an unconditional Conflict.
  it('rejects a second inspection report submission by the new repair worker', async () => {
    repository.findWorkerProfileByUserId.mockResolvedValue({ id: 'worker-2' });
    repository.findBookingContext.mockResolvedValue({
      ...BASE_BOOKING,
      workerProfileId: 'worker-2', // repair worker now assigned/hired
    });
    repository.findByBookingId.mockResolvedValue(BASE_REPORT); // already exists (from inspector-1)
    repository.createReport = jest.fn();

    await expect(
      service.submitReport('worker-2-user', 'booking-1', {} as any, []),
    ).rejects.toThrow(
      'An inspection report has already been submitted for this booking.',
    );
    expect(repository.createReport).not.toHaveBeenCalled();
  });

  // ── Optional fields (images, voice note, parts, note) must never block a
  // submission — only issueFound+recommendedRepair (or a voice note),
  // labourCost, and partsNeeded are genuinely required.
  describe('submitReport with optional fields absent', () => {
    const NO_EXISTING_REPORT_BOOKING = {
      ...BASE_BOOKING,
      workerProfileId: 'inspector-1',
    };

    beforeEach(() => {
      repository.findWorkerProfileByUserId.mockResolvedValue({
        id: 'inspector-1',
      });
      repository.findBookingContext.mockResolvedValue(
        NO_EXISTING_REPORT_BOOKING,
      );
      repository.findByBookingId.mockResolvedValue(null); // no report yet
      repository.createReport = jest.fn().mockResolvedValue(BASE_REPORT);
    });

    const baseDto = {
      issueFound: 'Leaky pipe',
      recommendedRepair: 'Replace pipe',
      labourCost: 1000,
      partsNeeded: false,
    };

    it('submits successfully with no photos and no voice note', async () => {
      await expect(
        service.submitReport('inspector-user-1', 'booking-1', {
          ...baseDto,
          parts: [],
        } as any, [], undefined),
      ).resolves.toBeDefined();
      expect(repository.createReport).toHaveBeenCalledTimes(1);
    });

    it('submits successfully with parts omitted (partsNeeded false)', async () => {
      await expect(
        service.submitReport(
          'inspector-user-1',
          'booking-1',
          { ...baseDto } as any, // dto.parts is undefined
          [],
          undefined,
        ),
      ).resolves.toBeDefined();
      const created = repository.createReport.mock.calls[0][0];
      expect(created.parts).toEqual([]);
      expect(created.partsTotal).toBe(0);
    });

    it('submits successfully with no optional Ustaad note (notes omitted)', async () => {
      await service.submitReport(
        'inspector-user-1',
        'booking-1',
        { ...baseDto, parts: [] } as any,
        [],
        undefined,
      );
      const created = repository.createReport.mock.calls[0][0];
      expect(created.notes).toBeUndefined();
    });

    it('submits successfully with every optional field absent together', async () => {
      const result = await service.submitReport(
        'inspector-user-1',
        'booking-1',
        { ...baseDto, parts: [] } as any,
        [], // no photos
        undefined, // no voice note
      );
      expect(repository.createReport).toHaveBeenCalledTimes(1);
      const created = repository.createReport.mock.calls[0][0];
      expect(created.photos).toEqual([]);
      expect(created.voiceNoteUrl).toBeNull();
      expect(created.voiceNoteDurationSeconds).toBeNull();
      expect(created.parts).toEqual([]);
      expect(created.notes).toBeUndefined();
      expect(result).toBeDefined();
    });

    it('still requires at least one part when partsNeeded is true and parts is empty', async () => {
      await expect(
        service.submitReport(
          'inspector-user-1',
          'booking-1',
          { ...baseDto, partsNeeded: true, parts: [] } as any,
          [],
          undefined,
        ),
      ).rejects.toThrow('Add at least one part when parts are needed.');
      expect(repository.createReport).not.toHaveBeenCalled();
    });
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

  // ── New linked-child flow: report access via the CHILD booking id ────────
  describe('sanitized report for a bidder on the linked repair booking', () => {
    const CHILD_CTX = {
      id: 'child-1',
      lane: 'BIDDING',
      status: 'PENDING',
      workerProfileId: null,
      clientProfileId: 'client-1',
      categoryId: 'cat-1',
      title: null,
      description: 'Leaky pipe\n\nReplace pipe',
      addressLine: '123 Street',
      city: 'Karachi',
      latitude: 24.86,
      longitude: 67.0,
      inspectionFeeSnapshot: null,
      clientProfile: { userId: 'client-user-1' },
      workerProfile: null,
      workerExclusions: [],
      sourceInspectionBookingId: 'booking-1',
      repairBooking: null,
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
      repository.findBookingContext.mockImplementation((id: string) =>
        Promise.resolve(
          id === 'child-1'
            ? CHILD_CTX
            : { ...CLOSED_BOOKING_WITH_CHILD, workerProfile: null },
        ),
      );
      repository.findByBookingId.mockResolvedValue({
        ...BASE_REPORT,
        decisionStatus: 'FIND_OTHER_USTAAD',
      });
      repository.findWorkerProfileWithSkillsByUserId.mockResolvedValue(
        ELIGIBLE_BIDDER_PROFILE,
      );
    });

    // #8 — same price stripping when the report is opened via the child id.
    it('re-anchors to the source inspection booking and omits every price field', async () => {
      const dto: any = await service.getReport(
        'bidder-user-1',
        'WORKER',
        'child-1',
      );
      expect(repository.findByBookingId).toHaveBeenCalledWith('booking-1');
      expect(dto).not.toHaveProperty('labourCost');
      expect(dto).not.toHaveProperty('partsTotal');
      expect(dto).not.toHaveProperty('repairQuoteTotal');
      expect(dto).not.toHaveProperty('inspectionFeeSnapshot');
      expect(dto.issueFound).toBe('Leaky pipe');
    });

    // #10 — the original inspector cannot use the bidder path on their own
    // linked repair job (IS_INSPECTOR exclusion).
    it('rejects the original inspector trying to view/bid via the bidder path', async () => {
      repository.findWorkerProfileWithSkillsByUserId.mockResolvedValue({
        ...ELIGIBLE_BIDDER_PROFILE,
        id: 'inspector-1',
      });
      // Not matched as the inspector's own-report path (different userId
      // lookup), so it falls through to the bidder eligibility gate.
      repository.findWorkerProfileByUserId.mockResolvedValue(null);
      await expect(
        service.getReport('inspector-user-1', 'WORKER', 'child-1'),
      ).rejects.toThrow(ForbiddenException);
    });

    // #15 — a worker outside the 20km radius may not read the report either.
    it('rejects a worker with a fresh location outside the bidding radius', async () => {
      repository.findWorkerProfileWithSkillsByUserId.mockResolvedValue({
        ...ELIGIBLE_BIDDER_PROFILE,
        currentLat: 31.5204, // Lahore vs Karachi job — far out of radius
        currentLng: 74.3587,
      });
      await expect(
        service.getReport('bidder-user-1', 'WORKER', 'child-1'),
      ).rejects.toThrow(ForbiddenException);
    });

    // The client sees the full report (with prices) through the child id too.
    it('returns the full report with prices and linkedRepairBookingId for the owning client via the child id', async () => {
      const dto: any = await service.getReport(
        'client-user-1',
        'CLIENT',
        'child-1',
      );
      expect(dto.labourCost).toBe(1000);
      expect(dto.repairQuoteTotal).toBe(1000);
      expect(dto.linkedRepairBookingId).toBe('child-1');
    });
  });
});
