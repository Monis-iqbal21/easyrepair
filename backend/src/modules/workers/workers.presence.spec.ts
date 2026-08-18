import { AvailabilityStatus } from '@prisma/client';
import { WorkersRepository } from './workers.repository';

/**
 * touchWorkerPresence semantics: lastSeenAt is renewed ONLY from genuine,
 * server-observed Worker activity (explicit Go-Online, a live-location ping
 * while already ONLINE) — never from an OFFLINE/BUSY write, and never from
 * anything Client- or admin-driven (those call different repositories
 * entirely, so there is nothing here that could touch a Worker's row).
 */
describe('WorkersRepository — presence lease writes', () => {
  let prisma: any;
  let repository: WorkersRepository;

  beforeEach(() => {
    prisma = {
      workerProfile: {
        update: jest.fn().mockResolvedValue({}),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        findMany: jest.fn().mockResolvedValue([]),
      },
    };
    repository = new WorkersRepository(prisma);
  });

  describe('updateAvailability', () => {
    it('renews lastSeenAt when going ONLINE', async () => {
      await repository.updateAvailability(
        'worker-1',
        AvailabilityStatus.ONLINE,
        24.86,
        67.0,
      );

      const data = prisma.workerProfile.update.mock.calls[0][0].data;
      expect(data.lastSeenAt).toBeInstanceOf(Date);
      expect(data.onlineAt).toBeInstanceOf(Date);
    });

    it('does not touch lastSeenAt when going OFFLINE', async () => {
      await repository.updateAvailability(
        'worker-1',
        AvailabilityStatus.OFFLINE,
      );

      const data = prisma.workerProfile.update.mock.calls[0][0].data;
      expect(data.lastSeenAt).toBeUndefined();
    });

    it('does not touch lastSeenAt on a BUSY transition (set by the booking flow, not Worker activity)', async () => {
      await repository.updateAvailability('worker-1', AvailabilityStatus.BUSY);

      const data = prisma.workerProfile.update.mock.calls[0][0].data;
      expect(data.lastSeenAt).toBeUndefined();
    });
  });

  describe('updateLocationOnly', () => {
    it('renews lastSeenAt alongside the location fields, gated to ONLINE workers', async () => {
      await repository.updateLocationOnly('worker-1', 24.86, 67.0);

      const call = prisma.workerProfile.updateMany.mock.calls[0][0];
      expect(call.where).toEqual({
        id: 'worker-1',
        availabilityStatus: AvailabilityStatus.ONLINE,
      });
      expect(call.data.lastSeenAt).toBeInstanceOf(Date);
    });
  });

  describe('findStaleOnlineWorkers', () => {
    it('queries ONLINE workers whose lastSeenAt is null or before the cutoff', async () => {
      const cutoff = new Date('2026-01-01T00:00:00.000Z');
      await repository.findStaleOnlineWorkers(cutoff);

      expect(prisma.workerProfile.findMany).toHaveBeenCalledWith({
        where: {
          availabilityStatus: AvailabilityStatus.ONLINE,
          OR: [{ lastSeenAt: null }, { lastSeenAt: { lt: cutoff } }],
        },
        select: { id: true, userId: true },
      });
    });
  });

  describe('setOfflineIfStillOnline', () => {
    it('reports true when the row was actually still ONLINE and got flipped', async () => {
      prisma.workerProfile.updateMany.mockResolvedValue({ count: 1 });

      const result = await repository.setOfflineIfStillOnline('worker-1');

      expect(result).toBe(true);
      expect(prisma.workerProfile.updateMany).toHaveBeenCalledWith({
        where: { id: 'worker-1', availabilityStatus: AvailabilityStatus.ONLINE },
        data: expect.objectContaining({
          availabilityStatus: AvailabilityStatus.OFFLINE,
        }),
      });
    });

    it('reports false when a concurrent write already moved the row off ONLINE', async () => {
      prisma.workerProfile.updateMany.mockResolvedValue({ count: 0 });

      const result = await repository.setOfflineIfStillOnline('worker-1');

      expect(result).toBe(false);
    });
  });
});
