import { Injectable } from '@nestjs/common';
import { BidStatus, BookingStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

export const BID_INCLUDE = {
  workerProfile: {
    select: {
      id: true,
      userId: true,
      firstName: true,
      lastName: true,
      avatarUrl: true,
      rating: true,
    },
  },
  booking: {
    select: {
      id: true,
      status: true,
      clientProfileId: true,
    },
  },
} satisfies Prisma.BidInclude;

export type BidWithRelations = Prisma.BidGetPayload<{
  include: typeof BID_INCLUDE;
}>;

@Injectable()
export class BidsRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findBookingById(bookingId: string) {
    return this.prisma.booking.findUnique({
      where: { id: bookingId },
      select: { id: true, status: true, clientProfileId: true, categoryId: true, latitude: true, longitude: true },
    });
  }

  async findWorkerProfileByUserId(userId: string) {
    return this.prisma.workerProfile.findUnique({
      where: { userId },
      select: {
        id: true,
        status: true,
        verificationStatus: true,
        availabilityStatus: true,
        currentlyWorking: true,
        currentLat: true,
        currentLng: true,
        skills: { select: { categoryId: true } },
      },
    });
  }

  async findClientProfileByUserId(userId: string) {
    return this.prisma.clientProfile.findUnique({
      where: { userId },
      select: { id: true },
    });
  }

  async findExistingBid(bookingId: string, workerProfileId: string) {
    return this.prisma.bid.findUnique({
      where: { bookingId_workerProfileId: { bookingId, workerProfileId } },
      select: { id: true, updatedAt: true, status: true },
    });
  }

  async findBidById(bidId: string): Promise<BidWithRelations | null> {
    return this.prisma.bid.findUnique({
      where: { id: bidId },
      include: BID_INCLUDE,
    });
  }

  async createBid(data: {
    bookingId: string;
    workerProfileId: string;
    amount: number;
    message?: string;
  }): Promise<BidWithRelations> {
    const bid = await this.prisma.bid.create({
      data: {
        bookingId: data.bookingId,
        workerProfileId: data.workerProfileId,
        amount: data.amount,
        message: data.message ?? null,
        status: BidStatus.PENDING,
      },
    });
    return this.prisma.bid.findUniqueOrThrow({
      where: { id: bid.id },
      include: BID_INCLUDE,
    });
  }

  async updateBid(
    bidId: string,
    data: { amount: number; message?: string },
  ): Promise<BidWithRelations> {
    await this.prisma.bid.update({
      where: { id: bidId },
      data: {
        amount: data.amount,
        message: data.message ?? null,
        editCount: { increment: 1 },
      },
    });
    return this.prisma.bid.findUniqueOrThrow({
      where: { id: bidId },
      include: BID_INCLUDE,
    });
  }

  /** Update bid amount/message in-place, resetting the cooldown window (updatedAt). */
  async updateBidAmountAndMessage(
    bidId: string,
    amount: number,
    message?: string,
  ) {
    await this.prisma.bid.update({
      where: { id: bidId },
      data: { amount, message: message ?? null },
    });
    return this.prisma.bid.findUniqueOrThrow({
      where: { id: bidId },
      include: BID_INCLUDE,
    });
  }

  /** Find all bids for a booking, sorted by createdAt descending (newest first — live feed). */
  async findBidsByBookingIdNewestFirst(bookingId: string) {
    return this.prisma.bid.findMany({
      where: { bookingId },
      orderBy: { createdAt: 'desc' },
      include: {
        workerProfile: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            avatarUrl: true,
            rating: true,
            totalRatings: true,
            currentLat: true,
            currentLng: true,
            locationUpdatedAt: true,
            bookings: {
              where: { status: BookingStatus.COMPLETED },
              select: { id: true },
            },
          },
        },
      },
    });
  }

  /** Find all bids for a booking, sorted by amount ascending. */
  async findBidsByBookingId(bookingId: string) {
    return this.prisma.bid.findMany({
      where: { bookingId },
      orderBy: { amount: 'asc' },
      include: {
        workerProfile: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            avatarUrl: true,
            rating: true,
            totalRatings: true,
            currentLat: true,
            currentLng: true,
            locationUpdatedAt: true,
            bookings: {
              where: { status: BookingStatus.COMPLETED },
              select: { id: true },
            },
          },
        },
      },
    });
  }

  /** Find a specific bid by id + bookingId (for my-bid lookup). */
  async findMyBidOnBooking(bookingId: string, workerProfileId: string): Promise<BidWithRelations | null> {
    return this.prisma.bid.findUnique({
      where: { bookingId_workerProfileId: { bookingId, workerProfileId } },
      include: BID_INCLUDE,
    });
  }

  /**
   * Accept a bid: set it to ACCEPTED, reject all others on the same booking,
   * then assign the worker to the booking and transition it to ACCEPTED status.
   * All in one transaction.
   */
  async acceptBid(bidId: string, bookingId: string, workerProfileId: string) {
    return this.prisma.$transaction(async (tx) => {
      // Accept the chosen bid
      await tx.bid.update({
        where: { id: bidId },
        data: { status: BidStatus.ACCEPTED },
      });

      // Reject all other bids on this booking
      await tx.bid.updateMany({
        where: { bookingId, id: { not: bidId } },
        data: { status: BidStatus.REJECTED },
      });

      // Assign worker and transition booking to ACCEPTED
      const booking = await tx.booking.update({
        where: { id: bookingId },
        data: {
          workerProfileId,
          status: BookingStatus.ACCEPTED,
          acceptedAt: new Date(),
        },
        include: {
          category: { select: { name: true } },
          clientProfile: { select: { userId: true } },
          workerProfile: {
            select: { userId: true, firstName: true, lastName: true },
          },
        },
      });

      // Record status history
      await tx.bookingStatusHistory.create({
        data: { bookingId, status: BookingStatus.ACCEPTED, note: 'Bid accepted by client' },
      });

      // Mark worker as busy so they don't appear in new searches or new-jobs feed.
      await tx.workerProfile.update({
        where: { id: workerProfileId },
        data: { currentlyWorking: true },
      });

      return booking;
    });
  }

  /**
   * Find PENDING bookings that match the worker's skills.
   * Includes all jobs regardless of whether the worker already bid.
   * Returns `myBid` so callers can compute `hasMyBid`.
   */
  async findAvailableJobsForWorker(workerProfileId: string, categoryIds: string[]) {
    return this.prisma.booking.findMany({
      where: {
        status: BookingStatus.PENDING,
        categoryId: { in: categoryIds },
      },
      orderBy: { createdAt: 'desc' },
      include: {
        category: { select: { id: true, name: true, iconUrl: true } },
        clientProfile: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            avatarUrl: true,
          },
        },
        _count: { select: { bids: true } },
        bids: {
          where: { workerProfileId },
          select: { id: true, updatedAt: true },
          take: 1,
        },
      },
    });
  }

  async countCompletedJobsByWorkerProfileId(workerProfileId: string): Promise<number> {
    return this.prisma.booking.count({
      where: { workerProfileId, status: BookingStatus.COMPLETED },
    });
  }
}
