import { BidsRepository } from './bids.repository';

/**
 * Chunk 3 launch-hardening: focused tests for the atomic guards backing
 * "one active bid per worker/job" and "only one hire wins".
 */
describe('BidsRepository idempotency guards', () => {
  let tx: any;
  let prisma: any;
  let repo: BidsRepository;

  function p2002() {
    const err = Object.assign(new Error('Unique constraint failed'), {
      code: 'P2002',
      name: 'PrismaClientKnownRequestError',
    });
    Object.setPrototypeOf(
      err,
      require('@prisma/client').Prisma.PrismaClientKnownRequestError.prototype,
    );
    return err;
  }

  beforeEach(() => {
    tx = {
      bid: {
        update: jest.fn().mockResolvedValue({}),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      booking: {
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        findUniqueOrThrow: jest.fn().mockResolvedValue({
          id: 'booking-1',
          workerProfileId: 'worker-1',
        }),
      },
      bookingStatusHistory: { create: jest.fn().mockResolvedValue({}) },
      workerProfile: { updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
    };
    prisma = {
      $transaction: jest.fn(async (cb: any) => cb(tx)),
      bid: {
        create: jest.fn().mockResolvedValue({ id: 'bid-1' }),
        findUnique: jest.fn(),
        findUniqueOrThrow: jest.fn().mockResolvedValue({ id: 'bid-1' }),
      },
    };
    repo = new BidsRepository(prisma);
  });

  describe('createBid', () => {
    it('a genuine concurrent double-submit (P2002) returns the winning bid instead of throwing', async () => {
      prisma.bid.create.mockRejectedValue(p2002());
      prisma.bid.findUnique.mockResolvedValue({ id: 'existing-bid' });

      const result = await repo.createBid({
        bookingId: 'booking-1',
        workerProfileId: 'worker-1',
        amount: 1500,
      });

      expect(result).toEqual({ id: 'existing-bid' });
      expect(prisma.bid.findUnique).toHaveBeenCalledWith({
        where: {
          bookingId_workerProfileId: {
            bookingId: 'booking-1',
            workerProfileId: 'worker-1',
          },
        },
        include: expect.anything(),
      });
    });
  });

  describe('acceptBid', () => {
    it('never touches bid rows when the booking gate already lost the race (changed: false)', async () => {
      tx.booking.updateMany.mockResolvedValue({ count: 0 });

      const result = await repo.acceptBid(
        'bid-1',
        'booking-1',
        'worker-1',
        1500,
        270,
      );

      expect(result.changed).toBe(false);
      expect(tx.bid.update).not.toHaveBeenCalled();
      expect(tx.bid.updateMany).not.toHaveBeenCalled();
      expect(tx.workerProfile.updateMany).not.toHaveBeenCalled();
    });

    it('accepts the bid and rejects the others when the booking gate wins (changed: true)', async () => {
      const result = await repo.acceptBid(
        'bid-1',
        'booking-1',
        'worker-1',
        1500,
        270,
      );

      expect(result.changed).toBe(true);
      expect(tx.bid.update).toHaveBeenCalledWith({
        where: { id: 'bid-1' },
        data: { status: 'ACCEPTED' },
      });
      expect(tx.bid.updateMany).toHaveBeenCalledWith({
        where: { bookingId: 'booking-1', id: { not: 'bid-1' } },
        data: { status: 'REJECTED' },
      });
    });
  });
});
