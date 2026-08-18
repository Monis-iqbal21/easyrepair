import { BidStatus, BookingStatus } from '@prisma/client';
import { WorkersRepository } from './workers.repository';
import { WorkersService } from './workers.service';

/**
 * My Jobs must remain the Worker's own account history — never filtered by
 * ONLINE/OFFLINE availability, never aged out, and never missing a bid the
 * worker actually placed just because the booking moved on without them.
 * See the job-visibility task.
 */
describe('WorkersRepository — My Jobs status/availability independence', () => {
  let prisma: any;
  let repo: WorkersRepository;

  beforeEach(() => {
    prisma = {
      booking: { findMany: jest.fn().mockResolvedValue([]) },
      bid: { findMany: jest.fn().mockResolvedValue([]) },
    };
    repo = new WorkersRepository(prisma);
  });

  it("'active' filter uses the shared ACTIVE_BOOKING_STATUSES (includes ARRIVED)", async () => {
    await repo.findJobsByWorkerProfileId('worker-1', 'active');

    const call = prisma.booking.findMany.mock.calls[0][0];
    expect(call.where.status.in).toEqual(
      expect.arrayContaining([
        BookingStatus.ACCEPTED,
        BookingStatus.EN_ROUTE,
        BookingStatus.ARRIVED,
        BookingStatus.IN_PROGRESS,
      ]),
    );
    expect(call.where.status.in).toHaveLength(4);
  });

  it.each(['active', 'completed', 'cancelled', undefined] as const)(
    "My Jobs query (%s) never filters on the Worker's own availabilityStatus",
    async (filter) => {
      await repo.findJobsByWorkerProfileId('worker-1', filter);

      const call = prisma.booking.findMany.mock.calls[0][0];
      expect(call.where).not.toHaveProperty('availabilityStatus');
      expect(call.where).not.toHaveProperty('workerProfile');
    },
  );

  it('findAppliedJobsByWorkerProfileId queries every bid this worker placed, newest first, with no status/age filter', async () => {
    await repo.findAppliedJobsByWorkerProfileId('worker-1');

    expect(prisma.bid.findMany).toHaveBeenCalledWith({
      where: { workerProfileId: 'worker-1' },
      orderBy: { updatedAt: 'desc' },
      select: expect.objectContaining({
        status: true,
        amount: true,
        updatedAt: true,
        booking: expect.any(Object),
      }),
    });
  });
});

describe('WorkersService.getWorkerJobs — Applied/Bids grouping', () => {
  let workersRepository: any;
  let service: WorkersService;

  const PROFILE = { id: 'worker-1', userId: 'worker-user-1' };

  function makeBooking(overrides: Partial<any> = {}) {
    return {
      id: 'booking-1',
      workerProfileId: null,
      category: { name: 'Plumbing' },
      title: null,
      description: 'Fix the sink',
      urgency: 'NORMAL',
      timeSlot: null,
      urgentWindow: null,
      scheduledAt: null,
      createdAt: new Date(),
      inspection: false,
      lane: 'BIDDING',
      standardServiceItems: [],
      inspectionFeeSnapshot: null,
      estimatedPrice: 1500,
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
      sourceInspectionBooking: null,
      sourceInspectionBookingId: null,
      review: null,
      attachments: [],
      statusHistory: [],
      ...overrides,
    };
  }

  beforeEach(() => {
    workersRepository = {
      findByUserId: jest.fn().mockResolvedValue(PROFILE),
      findAppliedJobsByWorkerProfileId: jest.fn(),
      findJobsByWorkerProfileId: jest.fn(),
      findInspectionOnlyCompletedJobsByWorkerProfileId: jest
        .fn()
        .mockResolvedValue([]),
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

  it("returns a bid the worker placed, tagged with the bid's own status/amount", async () => {
    workersRepository.findAppliedJobsByWorkerProfileId.mockResolvedValue([
      {
        bidStatus: BidStatus.PENDING,
        bidAmount: 1800,
        bidUpdatedAt: new Date(),
        booking: makeBooking(),
      },
    ]);

    const result = await service.getWorkerJobs('worker-user-1', 'applied');

    expect(result).toHaveLength(1);
    expect(result[0].myBidStatus).toBe(BidStatus.PENDING);
    expect(result[0].myBidAmount).toBe(1800);
    expect(workersRepository.findJobsByWorkerProfileId).not.toHaveBeenCalled();
  });

  it('keeps a bid visible under Applied even after the job was assigned to a different worker (bid auto-REJECTED)', async () => {
    workersRepository.findAppliedJobsByWorkerProfileId.mockResolvedValue([
      {
        bidStatus: BidStatus.REJECTED,
        bidAmount: 1800,
        bidUpdatedAt: new Date(),
        booking: makeBooking({
          status: BookingStatus.ACCEPTED,
          workerProfileId: 'someone-else',
        }),
      },
    ]);

    const result = await service.getWorkerJobs('worker-user-1', 'applied');

    expect(result).toHaveLength(1);
    expect(result[0].myBidStatus).toBe(BidStatus.REJECTED);
    expect(result[0].status).toBe(BookingStatus.ACCEPTED);
  });

  it('other filters never carry bid-specific fields', async () => {
    workersRepository.findJobsByWorkerProfileId.mockResolvedValue([
      makeBooking({ status: BookingStatus.ACCEPTED, workerProfileId: 'worker-1' }),
    ]);

    const result = await service.getWorkerJobs('worker-user-1', 'active');

    expect(result[0].myBidStatus).toBeNull();
    expect(result[0].myBidAmount).toBeNull();
    expect(
      workersRepository.findAppliedJobsByWorkerProfileId,
    ).not.toHaveBeenCalled();
  });
});
