import { BookingStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * Single source of truth for "cancellationRate", replacing the three
 * independent implementations that previously existed in
 * workers.repository.ts (getJobStats), bookings.repository.ts
 * (_attachWorkerStats, both PostGIS and Haversine paths), and
 * bids.repository.ts (inline bookings.length count).
 *
 * cancellationRate = round(workerCancelledCount / totalAcceptedCount * 100)
 *
 * A cancellation counts toward the worker if cancelledByRole === WORKER
 * (new, precise). For historical rows created before cancelledByRole
 * existed (always null), fall back to the legacy substring match on
 * cancellationReason so old cancellations are still counted correctly.
 */
export async function computeCancellationRate(
  prisma: PrismaService,
  workerProfileId: string,
): Promise<number> {
  const [workerCancelled, totalAccepted] = await Promise.all([
    prisma.booking.count({
      where: {
        workerProfileId,
        status: BookingStatus.CANCELLED,
        OR: [
          { cancelledByRole: 'WORKER' },
          {
            cancelledByRole: null,
            cancellationReason: { contains: 'Cancelled by worker' },
          },
        ],
      },
    }),
    prisma.booking.count({
      where: {
        workerProfileId,
        status: {
          in: [
            BookingStatus.ACCEPTED,
            BookingStatus.EN_ROUTE,
            BookingStatus.ARRIVED,
            BookingStatus.IN_PROGRESS,
            BookingStatus.COMPLETED,
            BookingStatus.CANCELLED,
          ],
        },
      },
    }),
  ]);

  return totalAccepted > 0
    ? Math.round((workerCancelled / totalAccepted) * 100)
    : 0;
}

/** completedJobs = COUNT(bookings WHERE workerProfileId AND status=COMPLETED). */
export async function computeCompletedJobs(
  prisma: PrismaService,
  workerProfileId: string,
): Promise<number> {
  return prisma.booking.count({
    where: { workerProfileId, status: BookingStatus.COMPLETED },
  });
}

/**
 * completedJobs-derived tier badge, mirrored from the Flutter-side
 * NearbyWorkerEntity.levelBadge getter so the backend can surface the same
 * label on the worker's own profile if needed.
 */
export function levelBadgeFromCompletedJobs(completedJobs: number): string {
  if (completedJobs > 70) return 'Master';
  if (completedJobs > 50) return 'Elite';
  if (completedJobs > 30) return 'Pro Ustaad';
  if (completedJobs > 10) return 'Pro';
  return 'Standard';
}
