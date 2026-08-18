import { NotificationsService } from './notifications.service';

/**
 * The broadcast fan-out no longer asks "was this one worker already notified
 * about this one job?" once per recipient. These tests pin that the BATCHED
 * replacements answer exactly what the per-row checks answered — in
 * particular the per-live-cycle scoping, which is what stops a relisted
 * booking from being permanently silent and stops a same-cycle refresh from
 * re-notifying.
 */

function makeService(repository: any): NotificationsService {
  return new NotificationsService(
    repository,
    {} as any, // FirebaseService — never reached by these read-only lookups
    {} as any, // ChatGateway     — same
  );
}

describe('NotificationsService.findAlreadyNotifiedThisCycle', () => {
  it('scopes the batched lookup to the booking’s current live cycle', async () => {
    const since = new Date('2026-08-01T10:00:00Z');
    const repository = {
      findNotifiedUserIds: jest.fn().mockResolvedValue(new Set(['user-a'])),
    };

    const result = await makeService(repository).findAlreadyNotifiedThisCycle(
      ['user-a', 'user-b'],
      'booking-1',
      'booking.bidding.available',
      since,
    );

    expect(repository.findNotifiedUserIds).toHaveBeenCalledWith(
      ['user-a', 'user-b'],
      'booking-1',
      'booking.bidding.available',
      since,
    );
    expect([...result]).toEqual(['user-a']);
  });

  it('passes a null cycle straight through as the unbounded check', async () => {
    const repository = {
      findNotifiedUserIds: jest.fn().mockResolvedValue(new Set()),
    };

    await makeService(repository).findAlreadyNotifiedThisCycle(
      ['user-a'],
      'booking-1',
      'evt',
      null,
    );

    expect(repository.findNotifiedUserIds.mock.calls[0][3]).toBeNull();
  });
});

describe('NotificationsService.findAlreadyNotifiedBookingIds', () => {
  const NOTIFIED_AT = new Date('2026-08-01T12:00:00Z');

  function repositoryReturning(map: Map<string, Date>) {
    return {
      findLatestNotifiedAtByBooking: jest.fn().mockResolvedValue(map),
    };
  }

  it('skips a booking already notified inside its current cycle', async () => {
    const repository = repositoryReturning(
      new Map([['booking-1', NOTIFIED_AT]]),
    );

    const skip = await makeService(repository).findAlreadyNotifiedBookingIds(
      'user-a',
      [{ id: 'booking-1', liveStartedAt: new Date('2026-08-01T10:00:00Z') }],
      'evt',
    );

    expect(skip.has('booking-1')).toBe(true);
  });

  it('re-permits a booking whose relist opened a NEW cycle after the last push', async () => {
    const repository = repositoryReturning(
      new Map([['booking-1', NOTIFIED_AT]]),
    );

    const skip = await makeService(repository).findAlreadyNotifiedBookingIds(
      'user-a',
      // liveStartedAt moved AFTER the previous notification — new cycle.
      [{ id: 'booking-1', liveStartedAt: new Date('2026-08-02T09:00:00Z') }],
      'evt',
    );

    expect(skip.has('booking-1')).toBe(false);
  });

  it('treats a null liveStartedAt as the unbounded once-ever check', async () => {
    const repository = repositoryReturning(
      new Map([['booking-1', NOTIFIED_AT]]),
    );

    const skip = await makeService(repository).findAlreadyNotifiedBookingIds(
      'user-a',
      [{ id: 'booking-1', liveStartedAt: null }],
      'evt',
    );

    expect(skip.has('booking-1')).toBe(true);
  });

  it('never skips a booking with no notification history', async () => {
    const repository = repositoryReturning(new Map());

    const skip = await makeService(repository).findAlreadyNotifiedBookingIds(
      'user-a',
      [{ id: 'booking-1', liveStartedAt: null }],
      'evt',
    );

    expect(skip.size).toBe(0);
  });

  it('resolves the whole chunk in a single repository round trip', async () => {
    const repository = repositoryReturning(new Map());

    await makeService(repository).findAlreadyNotifiedBookingIds(
      'user-a',
      [
        { id: 'b1', liveStartedAt: null },
        { id: 'b2', liveStartedAt: null },
        { id: 'b3', liveStartedAt: null },
      ],
      'evt',
    );

    expect(repository.findLatestNotifiedAtByBooking).toHaveBeenCalledTimes(1);
    expect(repository.findLatestNotifiedAtByBooking).toHaveBeenCalledWith(
      'user-a',
      ['b1', 'b2', 'b3'],
      'evt',
    );
  });
});
