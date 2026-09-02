import { AttachmentType, BookingStatus } from '@prisma/client';
import { WorkersService } from './workers.service';
import { WorkersRepository } from './workers.repository';

/**
 * An Ustaad has to price a job BEFORE they are hired, so everything the
 * customer supplied with it — problem photos/videos/voice notes, and the
 * inspection report when one is linked — has to reach them at bid time and
 * stay there afterwards.
 *
 * The gap this covers: a "Find Other Ustaad" repair job is a FRESH child
 * booking, so the client's attachments live on the inspection booking it was
 * spawned from and were never copied. Bidders on the repair job saw nothing.
 */
describe('WorkersService.getWorkerJobById — customer-provided job context', () => {
  let workersRepository: any;
  let service: WorkersService;

  const PROFILE = {
    id: 'worker-1',
    userId: 'worker-user-1',
    skills: [{ categoryId: 'cat-1' }],
    currentLat: 24.86,
    currentLng: 67.0,
  };

  const CLIENT_PHOTO = {
    id: 'att-1',
    type: AttachmentType.IMAGE,
    url: 'https://cdn.test/leak.jpg',
    fileName: 'leak.jpg',
    mimeType: 'image/jpeg',
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
  };

  const CLIENT_VOICE_NOTE = {
    id: 'att-2',
    type: AttachmentType.AUDIO,
    url: 'https://cdn.test/note.m4a',
    fileName: 'note.m4a',
    mimeType: 'audio/mp4',
    createdAt: new Date('2026-01-01T00:01:00.000Z'),
  };

  function makeBooking(overrides: Partial<any> = {}) {
    return {
      id: 'repair-job-1',
      workerProfileId: null,
      category: { name: 'Plumbing' },
      title: null,
      description: 'Leaking pipe under the sink',
      status: BookingStatus.PENDING,
      urgency: 'NORMAL',
      timeSlot: null,
      urgentWindow: null,
      scheduledAt: null,
      createdAt: new Date(),
      inspection: false,
      lane: 'BIDDING',
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
      clientProfile: null,
      inspectionReport: null,
      sourceInspectionBookingId: null,
      sourceInspectionBooking: null,
      attachedInspectionBookingId: null,
      review: null,
      attachments: [],
      statusHistory: [],
      settlements: [],
      ...overrides,
    };
  }

  beforeEach(() => {
    workersRepository = {
      findByUserId: jest.fn().mockResolvedValue(PROFILE),
      findJobByIdAndWorkerProfileId: jest.fn().mockResolvedValue(null),
      findAvailablePendingJobById: jest.fn().mockResolvedValue(null),
      findInspectionOnlyCompletedJobById: jest.fn().mockResolvedValue(null),
    };
    service = new WorkersService(
      workersRepository,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
    );
  });

  it('gives a not-yet-hired bidder the attachments the client posted on the job', async () => {
    workersRepository.findAvailablePendingJobById.mockResolvedValue(
      makeBooking({ attachments: [CLIENT_PHOTO, CLIENT_VOICE_NOTE] }),
    );

    const job = await service.getWorkerJobById('worker-user-1', 'repair-job-1');

    expect(job.attachments.map((a) => a.id)).toEqual(['att-1', 'att-2']);
    // Still not hired: the privacy gate on exact address/phone is untouched.
    expect(job.address).toBeNull();
    expect(job.clientPhone).toBeNull();
  });

  it('inherits the inspection booking’s attachments on a Find-Other-Ustaad repair job, so the client never re-uploads', async () => {
    workersRepository.findAvailablePendingJobById.mockResolvedValue(
      makeBooking({
        attachments: [],
        sourceInspectionBookingId: 'inspection-1',
        sourceInspectionBooking: {
          status: BookingStatus.COMPLETED,
          attachments: [CLIENT_PHOTO, CLIENT_VOICE_NOTE],
        },
      }),
    );

    const job = await service.getWorkerJobById('worker-user-1', 'repair-job-1');

    expect(job.attachments.map((a) => a.id)).toEqual(['att-1', 'att-2']);
    // The report entry point the app keys off is still carried through.
    expect(job.sourceInspectionBookingId).toBe('inspection-1');
  });

  it("prefers the booking's own attachments over the inherited ones", async () => {
    const ownPhoto = { ...CLIENT_PHOTO, id: 'own-1' };
    workersRepository.findAvailablePendingJobById.mockResolvedValue(
      makeBooking({
        attachments: [ownPhoto],
        sourceInspectionBookingId: 'inspection-1',
        sourceInspectionBooking: {
          status: BookingStatus.COMPLETED,
          attachments: [CLIENT_PHOTO, CLIENT_VOICE_NOTE],
        },
      }),
    );

    const job = await service.getWorkerJobById('worker-user-1', 'repair-job-1');

    expect(job.attachments.map((a) => a.id)).toEqual(['own-1']);
  });

  it('carries attachedInspectionBookingId through so a direct bidding job can open its attached report', async () => {
    workersRepository.findAvailablePendingJobById.mockResolvedValue(
      makeBooking({
        attachments: [CLIENT_PHOTO],
        attachedInspectionBookingId: 'old-inspection-1',
      }),
    );

    const job = await service.getWorkerJobById('worker-user-1', 'repair-job-1');

    expect(job.attachedInspectionBookingId).toBe('old-inspection-1');
    expect(job.attachments).toHaveLength(1);
  });

  it('keeps the attachments visible after hire', async () => {
    workersRepository.findJobByIdAndWorkerProfileId.mockResolvedValue(
      makeBooking({
        status: BookingStatus.ACCEPTED,
        workerProfileId: 'worker-1',
        attachments: [],
        sourceInspectionBookingId: 'inspection-1',
        sourceInspectionBooking: {
          status: BookingStatus.COMPLETED,
          attachments: [CLIENT_PHOTO],
        },
      }),
    );

    const job = await service.getWorkerJobById('worker-user-1', 'repair-job-1');

    expect(job.attachments.map((a) => a.id)).toEqual(['att-1']);
    expect(workersRepository.findAvailablePendingJobById).not.toHaveBeenCalled();
  });
});

/**
 * The inherited attachments must come from the ONE booking the repair job is
 * linked to — never from a broader query — so nothing outside this booking
 * chain can leak in.
 */
describe('WorkersRepository — worker job include scope', () => {
  it('selects the source inspection booking’s attachments through the booking link only', async () => {
    const prisma: any = {
      booking: { findFirst: jest.fn().mockResolvedValue(null) },
    };
    const repo = new WorkersRepository(prisma);

    await repo.findAvailablePendingJobById('booking-1', 'worker-1', ['cat-1']);

    const call = prisma.booking.findFirst.mock.calls[0][0];
    expect(call.where).toEqual({
      id: 'booking-1',
      status: BookingStatus.PENDING,
      workerProfileId: null,
      categoryId: { in: ['cat-1'] },
    });
    expect(call.include.sourceInspectionBooking.select.attachments).toBeDefined();
  });
});
