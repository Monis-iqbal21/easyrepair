import { BidStatus, BookingLane, BookingStatus } from '@prisma/client';

import {
  BookingExpiryService,
  EXPIRY_SWEEP_BATCH_SIZE,
} from './booking-expiry.service';

/**
 * Minimal Prisma double whose `booking` table is authoritative the way
 * Postgres is: `updateMany` only writes rows that still match its `where`, so
 * a second concurrent expiry genuinely gets count 0.
 */
function makePrisma(rows: any[]) {
  const store = new Map<string, any>(rows.map((r) => [r.id, { ...r }]));
  const historyRows: any[] = [];
  const bids: any[] = [];

  const prisma: any = {
    _store: store,
    _history: historyRows,
    _bids: bids,
    booking: {
      findUnique: jest.fn(async ({ where }: any) => {
        const row = store.get(where.id);
        if (!row) return null;
        return {
          id: row.id,
          status: row.status,
          lane: row.lane,
          clientProfile: { userId: row.clientUserId ?? null },
        };
      }),
      findMany: jest.fn(async ({ where, take }: any) => {
        const now = where.expiresAt.lte as Date;
        return [...store.values()]
          .filter(
            (r) =>
              r.status === where.status &&
              r.expiresAt != null &&
              r.expiresAt.getTime() <= now.getTime(),
          )
          .sort((a, b) => a.expiresAt.getTime() - b.expiresAt.getTime())
          .slice(0, take)
          .map((r) => ({ id: r.id }));
      }),
      updateMany: jest.fn(async ({ where, data }: any) => {
        const row = store.get(where.id);
        if (!row || row.status !== where.status) return { count: 0 };
        row.status = data.status;
        return { count: 1 };
      }),
    },
    bid: {
      findFirst: jest.fn(
        async ({ where }: any) =>
          bids.find(
            (b) => b.bookingId === where.bookingId && b.status === where.status,
          ) ?? null,
      ),
    },
    bookingStatusHistory: {
      create: jest.fn(async ({ data }: any) => {
        historyRows.push(data);
        return data;
      }),
    },
    $transaction: jest.fn(async (fn: any) => fn(prisma)),
  };
  return prisma;
}

const HOUR = 60 * 60 * 1000;
const overdue = () => new Date(Date.now() - 2 * HOUR);
const future = () => new Date(Date.now() + 2 * HOUR);

describe('BookingExpiryService', () => {
  let notifications: any;

  beforeEach(() => {
    notifications = { notify: jest.fn().mockResolvedValue(undefined) };
  });

  const build = (rows: any[]) => {
    const prisma = makePrisma(rows);
    return { prisma, service: new BookingExpiryService(prisma, notifications) };
  };

  // -- Issue 1: the sweeper reconciles what the delayed job missed ------------

  it('expires an overdue PENDING booking and reproduces the delayed job side effects', async () => {
    const { prisma, service } = build([
      {
        id: 'b1',
        status: BookingStatus.PENDING,
        lane: BookingLane.STANDARD,
        expiresAt: overdue(),
        clientUserId: 'client-1',
      },
    ]);

    const result = await service.sweepExpiredBookings();

    expect(result).toEqual({ scanned: 1, expired: 1, skipped: 0, failed: 0 });
    expect(prisma._store.get('b1').status).toBe(BookingStatus.EXPIRED);
    expect(prisma._history).toEqual([
      {
        bookingId: 'b1',
        status: BookingStatus.EXPIRED,
        note: 'Auto-expired after 72 hours with no worker hired',
      },
    ]);
    expect(notifications.notify).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'client-1',
        eventKey: 'booking.expired',
        bookingId: 'b1',
        route: '/client/booking/b1',
        entityType: 'booking',
        entityId: 'b1',
      }),
    );
  });

  it('does not expire a PENDING booking whose expiresAt is still in the future', async () => {
    const { prisma, service } = build([
      {
        id: 'b1',
        status: BookingStatus.PENDING,
        lane: BookingLane.STANDARD,
        expiresAt: future(),
        clientUserId: 'client-1',
      },
    ]);

    const result = await service.sweepExpiredBookings();

    expect(result).toEqual({ scanned: 0, expired: 0, skipped: 0, failed: 0 });
    expect(prisma._store.get('b1').status).toBe(BookingStatus.PENDING);
    expect(notifications.notify).not.toHaveBeenCalled();
  });

  it.each([
    BookingStatus.ACCEPTED,
    BookingStatus.EN_ROUTE,
    BookingStatus.IN_PROGRESS,
    BookingStatus.COMPLETED,
    BookingStatus.CANCELLED,
    BookingStatus.REJECTED,
    BookingStatus.EXPIRED,
  ])('never expires a %s booking with an old expiresAt', async (status) => {
    const { prisma, service } = build([
      {
        id: 'b1',
        status,
        lane: BookingLane.STANDARD,
        expiresAt: overdue(),
        clientUserId: 'client-1',
      },
    ]);

    // Both entrypoints: the sweeper's candidate query filters it out, and a
    // stale delayed job aimed straight at it is still a no-op.
    const sweep = await service.sweepExpiredBookings();
    const direct = await service.expireBooking('b1');

    expect(sweep.expired).toBe(0);
    expect(direct).toBe('SKIPPED');
    expect(prisma._store.get('b1').status).toBe(status);
    expect(prisma._history).toHaveLength(0);
    expect(notifications.notify).not.toHaveBeenCalled();
  });

  it('re-expiring an already EXPIRED booking is harmless and silent', async () => {
    const { prisma, service } = build([
      {
        id: 'b1',
        status: BookingStatus.EXPIRED,
        lane: BookingLane.STANDARD,
        expiresAt: overdue(),
        clientUserId: 'client-1',
      },
    ]);

    await expect(service.expireBooking('b1')).resolves.toBe('SKIPPED');
    expect(prisma._history).toHaveLength(0);
    expect(notifications.notify).not.toHaveBeenCalled();
  });

  it('does not expire a BIDDING booking that already has an accepted bid', async () => {
    const { prisma, service } = build([
      {
        id: 'b1',
        status: BookingStatus.PENDING,
        lane: BookingLane.BIDDING,
        expiresAt: overdue(),
        clientUserId: 'client-1',
      },
    ]);
    prisma._bids.push({ bookingId: 'b1', status: BidStatus.ACCEPTED });

    await expect(service.expireBooking('b1')).resolves.toBe('SKIPPED');
    expect(prisma._store.get('b1').status).toBe(BookingStatus.PENDING);
    expect(notifications.notify).not.toHaveBeenCalled();
  });

  // -- Concurrency: BullMQ delayed job racing the sweeper --------------------

  it('a delayed job racing the sweeper produces exactly ONE transition', async () => {
    const { prisma, service } = build([
      {
        id: 'b1',
        status: BookingStatus.PENDING,
        lane: BookingLane.STANDARD,
        expiresAt: overdue(),
        clientUserId: 'client-1',
      },
    ]);

    // Both read PENDING before either writes - the exact TOCTOU that the
    // write-time status guard exists to resolve.
    const outcomes = await Promise.all([
      service.expireBooking('b1', 'job'),
      service.expireBooking('b1', 'sweeper'),
    ]);

    expect(outcomes.filter((o) => o === 'EXPIRED')).toHaveLength(1);
    expect(outcomes.filter((o) => o === 'SKIPPED')).toHaveLength(1);
    expect(prisma._history).toHaveLength(1);
    expect(notifications.notify).toHaveBeenCalledTimes(1);
  });

  // -- Isolation: one bad row must not take the sweep down -------------------

  it('keeps sweeping unrelated rows when one row fails', async () => {
    const { prisma, service } = build([
      {
        id: 'bad',
        status: BookingStatus.PENDING,
        lane: BookingLane.STANDARD,
        expiresAt: new Date(Date.now() - 3 * HOUR),
        clientUserId: 'client-1',
      },
      {
        id: 'good',
        status: BookingStatus.PENDING,
        lane: BookingLane.STANDARD,
        expiresAt: overdue(),
        clientUserId: 'client-2',
      },
    ]);

    const realCreate = prisma.bookingStatusHistory.create;
    prisma.bookingStatusHistory.create = jest.fn(async (args: any) => {
      if (args.data.bookingId === 'bad') {
        throw new Error('history write failed');
      }
      return realCreate(args);
    });

    const result = await service.sweepExpiredBookings();

    expect(result).toMatchObject({ scanned: 2, expired: 1, failed: 1 });
    expect(prisma._store.get('good').status).toBe(BookingStatus.EXPIRED);
    expect(notifications.notify).toHaveBeenCalledTimes(1);
    expect(notifications.notify).toHaveBeenCalledWith(
      expect.objectContaining({ bookingId: 'good' }),
    );
  });

  it('scans oldest-first in a bounded batch', async () => {
    const { prisma, service } = build([]);
    await service.sweepExpiredBookings();

    expect(prisma.booking.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          status: BookingStatus.PENDING,
          expiresAt: expect.objectContaining({ not: null }),
        }),
        orderBy: { expiresAt: 'asc' },
        take: EXPIRY_SWEEP_BATCH_SIZE,
      }),
    );
  });
});
