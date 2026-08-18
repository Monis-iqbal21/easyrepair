import { BadRequestException } from '@nestjs/common';
import { BookingLane, BookingStatus, InspectionDecisionStatus } from '@prisma/client';
import { BookingsService } from './bookings.service';

/**
 * "Attach a previous inspection report" — an OPTIONAL, read-only reference a
 * client may add while independently posting a new BIDDING job.
 *
 * The whole point of these tests is the separation from
 * `sourceInspectionBookingId`: the attached reference must never behave like
 * the post-inspection "Find Other Ustaad" relationship, and the historical
 * inspection must never be touched.
 */
describe('BookingsService.createBooking — attached inspection report', () => {
  let bookingsRepository: any;
  let service: BookingsService;

  const CLIENT_PROFILE = { id: 'client-1' };
  const CATEGORY = { id: 'cat-1', name: 'AC Technician', inspectionFee: 500 };

  /** An eligible historical inspection owned by CLIENT_PROFILE. */
  function eligibleInspection(overrides: Partial<any> = {}) {
    return {
      id: 'old-inspection-1',
      lane: BookingLane.INSPECTION,
      status: BookingStatus.COMPLETED,
      categoryId: 'cat-1',
      clientProfileId: 'client-1',
      inspectionReport: {
        id: 'report-1',
        decisionStatus: InspectionDecisionStatus.CLOSED_AFTER_INSPECTION,
      },
      ...overrides,
    };
  }

  const CREATE_DTO = {
    serviceCategory: 'AC Technician',
    urgency: 'NORMAL',
    timeSlot: 'MORNING',
    addressLine: '123 Street',
    city: 'Karachi',
    latitude: 24.86,
    longitude: 67.0,
    lane: BookingLane.BIDDING,
  } as any;

  function createdBooking(overrides: Partial<any> = {}) {
    return {
      id: 'new-booking-1',
      clientProfileId: 'client-1',
      workerProfileId: null,
      status: BookingStatus.PENDING,
      category: { name: 'AC Technician' },
      title: null,
      description: '',
      urgency: 'NORMAL',
      timeSlot: 'MORNING',
      urgentWindow: null,
      scheduledAt: null,
      createdAt: new Date(),
      inspection: false,
      lane: BookingLane.BIDDING,
      standardServiceId: null,
      standardServiceNameSnapshot: null,
      standardServicePriceSnapshot: null,
      standardServiceItems: [],
      inspectionFeeSnapshot: null,
      estimatedPrice: null,
      finalPrice: null,
      addressLine: '123 Street',
      city: 'Karachi',
      latitude: 24.86,
      longitude: 67.0,
      acceptedAt: null,
      enRouteAt: null,
      arrivedAt: null,
      startedAt: null,
      completedAt: null,
      cancellationReason: null,
      cancelledByRole: null,
      expiresAt: null,
      liveStartedAt: new Date(),
      relistedAt: null,
      idempotencyKey: null,
      sourceInspectionBookingId: null,
      attachedInspectionBookingId: null,
      clientProfile: { id: 'client-1', userId: 'client-user-1' },
      workerProfile: null,
      inspectionReport: null,
      review: null,
      attachments: [],
      bids: [],
      workerExclusions: [],
      ...overrides,
    };
  }

  beforeEach(() => {
    bookingsRepository = {
      findClientProfileByUserId: jest.fn().mockResolvedValue(CLIENT_PROFILE),
      findBookingByIdempotencyKey: jest.fn().mockResolvedValue(null),
      findCategoryByName: jest.fn().mockResolvedValue(CATEGORY),
      findInspectionForAttachment: jest.fn(),
      createBooking: jest.fn().mockResolvedValue(createdBooking()),
    };
    service = new BookingsService(
      bookingsRepository,
      {} as any,
      { notify: jest.fn().mockResolvedValue(undefined) } as any,
      { ensureConversationForBooking: jest.fn() } as any,
      { getJob: jest.fn(), add: jest.fn() } as any,
      {
        matchRadiusKm: 7,
        broadcastJob: jest.fn().mockResolvedValue(undefined),
        reconcileVisibleJobs: jest.fn(),
      } as any,
      { notifyClientJobCompleted: jest.fn() } as any,
    );
  });

  // ── The unchanged, no-report path ────────────────────────────────────────
  it('creates a normal bidding job with no attachment exactly as before', async () => {
    await service.createBooking('client-user-1', CREATE_DTO);

    expect(bookingsRepository.findInspectionForAttachment).not.toHaveBeenCalled();
    const written = bookingsRepository.createBooking.mock.calls[0][0];
    expect(written.attachedInspectionBookingId).toBeUndefined();
  });

  // ── The happy path ───────────────────────────────────────────────────────
  it('attaches an owned, completed, same-category inspection', async () => {
    bookingsRepository.findInspectionForAttachment.mockResolvedValue(
      eligibleInspection(),
    );

    await service.createBooking('client-user-1', {
      ...CREATE_DTO,
      attachedInspectionBookingId: 'old-inspection-1',
    });

    const written = bookingsRepository.createBooking.mock.calls[0][0];
    expect(written.attachedInspectionBookingId).toBe('old-inspection-1');
    // The dedicated post-inspection field must stay untouched.
    expect(written.sourceInspectionBookingId).toBeUndefined();
  });

  it('accepts an ACCEPTED_REPAIR report too (finished repair, still useful context)', async () => {
    bookingsRepository.findInspectionForAttachment.mockResolvedValue(
      eligibleInspection({
        inspectionReport: {
          id: 'report-1',
          decisionStatus: InspectionDecisionStatus.ACCEPTED_REPAIR,
        },
      }),
    );

    await service.createBooking('client-user-1', {
      ...CREATE_DTO,
      attachedInspectionBookingId: 'old-inspection-1',
    });

    expect(
      bookingsRepository.createBooking.mock.calls[0][0]
        .attachedInspectionBookingId,
    ).toBe('old-inspection-1');
  });

  it('lets the SAME historical inspection be attached to more than one job', async () => {
    bookingsRepository.findInspectionForAttachment.mockResolvedValue(
      eligibleInspection(),
    );

    await service.createBooking('client-user-1', {
      ...CREATE_DTO,
      attachedInspectionBookingId: 'old-inspection-1',
    });
    await service.createBooking('client-user-1', {
      ...CREATE_DTO,
      attachedInspectionBookingId: 'old-inspection-1',
    });

    expect(bookingsRepository.createBooking).toHaveBeenCalledTimes(2);
    for (const call of bookingsRepository.createBooking.mock.calls) {
      expect(call[0].attachedInspectionBookingId).toBe('old-inspection-1');
    }
  });

  // ── Security / eligibility rejections ────────────────────────────────────
  it("rejects another client's inspection", async () => {
    bookingsRepository.findInspectionForAttachment.mockResolvedValue(
      eligibleInspection({ clientProfileId: 'someone-else' }),
    );

    await expect(
      service.createBooking('client-user-1', {
        ...CREATE_DTO,
        attachedInspectionBookingId: 'old-inspection-1',
      }),
    ).rejects.toThrow(BadRequestException);
    expect(bookingsRepository.createBooking).not.toHaveBeenCalled();
  });

  it('rejects a nonexistent id with the SAME error as a foreign one (no id probing)', async () => {
    bookingsRepository.findInspectionForAttachment.mockResolvedValue(null);
    const missing = await service
      .createBooking('client-user-1', {
        ...CREATE_DTO,
        attachedInspectionBookingId: 'nope',
      })
      .catch((e) => e);

    bookingsRepository.findInspectionForAttachment.mockResolvedValue(
      eligibleInspection({ clientProfileId: 'someone-else' }),
    );
    const foreign = await service
      .createBooking('client-user-1', {
        ...CREATE_DTO,
        attachedInspectionBookingId: 'old-inspection-1',
      })
      .catch((e) => e);

    expect(missing.message).toBe(foreign.message);
  });

  it('rejects an inspection with no submitted report (draft/never filled)', async () => {
    bookingsRepository.findInspectionForAttachment.mockResolvedValue(
      eligibleInspection({ inspectionReport: null }),
    );

    await expect(
      service.createBooking('client-user-1', {
        ...CREATE_DTO,
        attachedInspectionBookingId: 'old-inspection-1',
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('rejects a report still awaiting the client decision', async () => {
    bookingsRepository.findInspectionForAttachment.mockResolvedValue(
      eligibleInspection({
        inspectionReport: {
          id: 'report-1',
          decisionStatus: InspectionDecisionStatus.PENDING_CLIENT_DECISION,
        },
      }),
    );

    await expect(
      service.createBooking('client-user-1', {
        ...CREATE_DTO,
        attachedInspectionBookingId: 'old-inspection-1',
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('rejects a FIND_OTHER_USTAAD report (owned by the existing post-inspection flow)', async () => {
    bookingsRepository.findInspectionForAttachment.mockResolvedValue(
      eligibleInspection({
        inspectionReport: {
          id: 'report-1',
          decisionStatus: InspectionDecisionStatus.FIND_OTHER_USTAAD,
        },
      }),
    );

    await expect(
      service.createBooking('client-user-1', {
        ...CREATE_DTO,
        attachedInspectionBookingId: 'old-inspection-1',
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('rejects a non-INSPECTION source booking', async () => {
    bookingsRepository.findInspectionForAttachment.mockResolvedValue(
      eligibleInspection({ lane: BookingLane.STANDARD }),
    );

    await expect(
      service.createBooking('client-user-1', {
        ...CREATE_DTO,
        attachedInspectionBookingId: 'old-inspection-1',
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('rejects an inspection that has not COMPLETED yet', async () => {
    bookingsRepository.findInspectionForAttachment.mockResolvedValue(
      eligibleInspection({ status: BookingStatus.IN_PROGRESS }),
    );

    await expect(
      service.createBooking('client-user-1', {
        ...CREATE_DTO,
        attachedInspectionBookingId: 'old-inspection-1',
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('rejects a category mismatch with a distinct, explanatory message', async () => {
    bookingsRepository.findInspectionForAttachment.mockResolvedValue(
      eligibleInspection({ categoryId: 'cat-other' }),
    );

    await expect(
      service.createBooking('client-user-1', {
        ...CREATE_DTO,
        attachedInspectionBookingId: 'old-inspection-1',
      }),
    ).rejects.toThrow('The attached inspection report is for a different service.');
  });

  // Attaching context only makes sense for an open marketplace job — the
  // direct-assign lanes have no bidders to inform. (INSPECTION is used here
  // because STANDARD fails its own service-selection validation first.)
  it('rejects attaching to a non-BIDDING lane', async () => {
    await expect(
      service.createBooking('client-user-1', {
        ...CREATE_DTO,
        lane: BookingLane.INSPECTION,
        attachedInspectionBookingId: 'old-inspection-1',
      }),
    ).rejects.toThrow(
      'An inspection report can only be attached to a bidding job.',
    );
    expect(bookingsRepository.createBooking).not.toHaveBeenCalled();
  });

  // ── Immutability of the historical inspection ────────────────────────────
  it('never writes to the historical inspection booking or its report', async () => {
    bookingsRepository.findInspectionForAttachment.mockResolvedValue(
      eligibleInspection(),
    );

    await service.createBooking('client-user-1', {
      ...CREATE_DTO,
      attachedInspectionBookingId: 'old-inspection-1',
    });

    // The ONLY repository calls the attach path makes are reads plus the one
    // create for the NEW booking — no update/cancel/reopen of the old one.
    const called = Object.keys(bookingsRepository).filter(
      (k) => bookingsRepository[k].mock?.calls?.length > 0,
    );
    expect(called.sort()).toEqual(
      [
        'createBooking',
        'findCategoryByName',
        'findClientProfileByUserId',
        'findInspectionForAttachment',
      ].sort(),
    );
    // And the create targeted the new booking, never the source id.
    expect(bookingsRepository.createBooking.mock.calls[0][0].clientProfileId).toBe(
      'client-1',
    );
  });
});
