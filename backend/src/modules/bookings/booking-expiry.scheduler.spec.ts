import {
  BookingExpiryScheduler,
  EXPIRY_SWEEP_CRON,
  SWEEP_EXPIRED_BOOKINGS_REPEAT_JOB_ID,
} from './booking-expiry.scheduler';
import {
  BookingsProcessor,
  SWEEP_EXPIRED_BOOKINGS_JOB,
} from './bookings.processor';

const config = (tz?: string) => ({ get: jest.fn().mockReturnValue(tz) }) as any;

describe('BookingExpiryScheduler', () => {
  it('registers the hourly sweep as a repeatable job on the bookings queue', async () => {
    const queue: any = { add: jest.fn().mockResolvedValue(undefined) };
    new BookingExpiryScheduler(queue, config('Asia/Karachi')).start();
    await Promise.resolve();

    expect(queue.add).toHaveBeenCalledWith(
      SWEEP_EXPIRED_BOOKINGS_JOB,
      {},
      expect.objectContaining({
        // Fixed jobId + fixed cron: re-issuing this on every process start is
        // what makes the safety net survive restarts, deploys and a Redis
        // flush instead of depending on one delayed job existing forever.
        jobId: SWEEP_EXPIRED_BOOKINGS_REPEAT_JOB_ID,
        repeat: { cron: EXPIRY_SWEEP_CRON, tz: 'Asia/Karachi' },
      }),
    );
  });

  it('falls back to the business timezone when none is configured', async () => {
    const queue: any = { add: jest.fn().mockResolvedValue(undefined) };
    new BookingExpiryScheduler(queue, config(undefined)).start();
    await Promise.resolve();

    expect(queue.add.mock.calls[0][2].repeat.tz).toBe('Asia/Karachi');
  });

  it('registers only once even if start() is called again', async () => {
    const queue: any = { add: jest.fn().mockResolvedValue(undefined) };
    const scheduler = new BookingExpiryScheduler(queue, config('Asia/Karachi'));
    scheduler.start();
    scheduler.start();
    await Promise.resolve();

    expect(queue.add).toHaveBeenCalledTimes(1);
  });

  it('does not throw when Redis is unavailable', async () => {
    const queue: any = { add: jest.fn().mockRejectedValue(new Error('ECONNREFUSED')) };
    expect(() =>
      new BookingExpiryScheduler(queue, config('Asia/Karachi')).start(),
    ).not.toThrow();
    await Promise.resolve();
    await Promise.resolve();
  });
});

describe('BookingsProcessor', () => {
  it('routes both the delayed job and the sweep job through the shared expiry service', async () => {
    const expiryService: any = {
      expireBooking: jest.fn().mockResolvedValue('EXPIRED'),
      sweepExpiredBookings: jest
        .fn()
        .mockResolvedValue({ scanned: 0, expired: 0, skipped: 0, failed: 0 }),
    };
    const processor = new BookingsProcessor(expiryService);

    await processor.handleExpireBooking({ data: { bookingId: 'b1' } } as any);
    await processor.handleSweepExpiredBookings();

    expect(expiryService.expireBooking).toHaveBeenCalledWith('b1', 'job');
    expect(expiryService.sweepExpiredBookings).toHaveBeenCalledTimes(1);
  });
});
