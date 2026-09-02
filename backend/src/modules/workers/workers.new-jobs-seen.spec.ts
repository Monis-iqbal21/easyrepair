import { NotFoundException } from '@nestjs/common';
import { WorkersRepository } from './workers.repository';

/**
 * `newJobsSeenAt` is the read-marker the Ustaad "Naye Kaam" badge counts
 * against: a matching job created after it is unread, one created before it
 * is not. Two properties matter and neither is obvious from the column alone.
 *
 * First, the SERVER owns the clock. If the device supplied the instant, a
 * phone with its date set forward could mark jobs read that it was never
 * shown — silently, and permanently.
 *
 * Second, the write is confined to this one path. It is not presence, it is
 * not GPS, and nothing else may touch it, or it would drift away from what
 * the Ustaad has actually looked at.
 */
describe('newJobsSeenAt — the New Jobs read-marker', () => {
  describe('WorkersRepository.markNewJobsSeen', () => {
    let prisma: any;
    let repository: WorkersRepository;

    beforeEach(() => {
      prisma = {
        workerProfile: {
          update: jest.fn(),
        },
      };
      repository = new WorkersRepository(prisma);
    });

    it('writes the instant it was given, to that worker alone', async () => {
      const seenAt = new Date('2026-09-03T09:00:00.000Z');
      prisma.workerProfile.update.mockResolvedValue({ newJobsSeenAt: seenAt });

      await repository.markNewJobsSeen('worker-1', seenAt);

      const call = prisma.workerProfile.update.mock.calls[0][0];
      expect(call.where).toEqual({ id: 'worker-1' });
      expect(call.data).toEqual({ newJobsSeenAt: seenAt });
    });

    it('touches nothing else on the row', async () => {
      const seenAt = new Date('2026-09-03T09:00:00.000Z');
      prisma.workerProfile.update.mockResolvedValue({ newJobsSeenAt: seenAt });

      await repository.markNewJobsSeen('worker-1', seenAt);

      // Especially not lastSeenAt: presence and "I looked at the job list"
      // are different facts, and conflating them would let a background
      // presence ping mark jobs read.
      expect(
        Object.keys(prisma.workerProfile.update.mock.calls[0][0].data),
      ).toEqual(['newJobsSeenAt']);
    });

    it('returns what the row actually holds, not the value passed in', async () => {
      const written = new Date('2026-09-03T09:00:00.123Z');
      prisma.workerProfile.update.mockResolvedValue({
        newJobsSeenAt: written,
      });

      const result = await repository.markNewJobsSeen(
        'worker-1',
        new Date('2026-09-03T09:00:00.000Z'),
      );

      // The client measures unread against this exact instant, so it has to
      // be the persisted one — a few milliseconds of drift is enough to leave
      // a job straddling the boundary looking unread on one side and read on
      // the other.
      expect(result).toBe(written);
    });
  });

  describe('WorkersService.markNewJobsSeen', () => {
    let repository: any;
    let service: any;

    beforeEach(async () => {
      repository = {
        findByUserId: jest.fn(),
        markNewJobsSeen: jest.fn(),
      };
      const { WorkersService } = await import('./workers.service');
      service = Object.create(WorkersService.prototype);
      service.workersRepository = repository;
    });

    it('stamps the server clock — the caller never supplies a time', async () => {
      const before = Date.now();
      repository.findByUserId.mockResolvedValue({ id: 'worker-1' });
      repository.markNewJobsSeen.mockImplementation(
        (_id: string, seenAt: Date) => Promise.resolve(seenAt),
      );

      const result = await service.markNewJobsSeen('user-1');

      const [workerProfileId, seenAt] =
        repository.markNewJobsSeen.mock.calls[0];
      expect(workerProfileId).toBe('worker-1');
      expect(seenAt).toBeInstanceOf(Date);
      expect(seenAt.getTime()).toBeGreaterThanOrEqual(before);
      expect(seenAt.getTime()).toBeLessThanOrEqual(Date.now());
      expect(result).toEqual({ newJobsSeenAt: seenAt.toISOString() });
    });

    it('refuses a user with no worker profile rather than writing anything', async () => {
      repository.findByUserId.mockResolvedValue(null);

      await expect(service.markNewJobsSeen('user-1')).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(repository.markNewJobsSeen).not.toHaveBeenCalled();
    });
  });
});
