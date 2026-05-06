import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { BookingStatus, VerificationStatus, WorkerStatus } from '@prisma/client';
import { BidsRepository, BidWithRelations } from './bids.repository';
import { BidResponseDto, BidWorkerDto } from './dto/bid-response.dto';
import { NotificationsService } from '../notifications/notifications.service';
import { ChatService } from '../chat/chat.service';

@Injectable()
export class BidsService {
  private readonly logger = new Logger(BidsService.name);

  constructor(
    private readonly bidsRepository: BidsRepository,
    private readonly notificationsService: NotificationsService,
    private readonly chatService: ChatService,
  ) {}

  // ── Worker: submit or re-submit bid (upsert with 1-minute cooldown) ────────

  async createBid(
    userId: string,
    bookingId: string,
    amount: number,
    message?: string,
  ): Promise<BidWithRelations> {
    this.logger.log(`[createBid] userId=${userId} bookingId=${bookingId} amount=${amount}`);

    const workerProfile = await this.bidsRepository.findWorkerProfileByUserId(userId);
    if (!workerProfile) {
      throw new ForbiddenException('Worker profile not found');
    }

    this._assertWorkerEligible(workerProfile);

    const booking = await this.bidsRepository.findBookingById(bookingId);
    if (!booking) {
      throw new NotFoundException(`Booking ${bookingId} not found`);
    }

    if (booking.status !== BookingStatus.PENDING) {
      throw new BadRequestException(
        `Bids can only be placed on PENDING bookings (current status: ${booking.status})`,
      );
    }

    const existing = await this.bidsRepository.findExistingBid(bookingId, workerProfile.id);

    if (existing) {
      // Enforce 1-minute cooldown before allowing a re-submit/update.
      const secondsSinceUpdate =
        (Date.now() - new Date(existing.updatedAt).getTime()) / 1000;
      if (secondsSinceUpdate < 60) {
        const waitSecs = Math.ceil(60 - secondsSinceUpdate);
        throw new HttpException(
          `Please wait ${waitSecs} second${waitSecs === 1 ? '' : 's'} before updating your bid`,
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }

      // Update existing bid in-place instead of creating a duplicate.
      const updated = await this.bidsRepository.updateBidAmountAndMessage(
        existing.id,
        amount,
        message,
      );
      this.logger.log(`[createBid] updated existing bidId=${existing.id}`);
      return updated;
    }

    const bid = await this.bidsRepository.createBid({
      bookingId,
      workerProfileId: workerProfile.id,
      amount,
      message,
    });

    this.logger.log(`[createBid] created bidId=${bid.id}`);
    return bid;
  }

  // ── Worker: edit bid ─────────────────────────────────────────────────────

  async editBid(
    userId: string,
    bidId: string,
    amount: number,
    message?: string,
  ): Promise<BidWithRelations> {
    this.logger.log(`[editBid] userId=${userId} bidId=${bidId} amount=${amount}`);

    const workerProfile = await this.bidsRepository.findWorkerProfileByUserId(userId);
    if (!workerProfile) {
      throw new ForbiddenException('Worker profile not found');
    }

    const bid = await this.bidsRepository.findBidById(bidId);
    if (!bid) {
      throw new NotFoundException(`Bid ${bidId} not found`);
    }

    if (bid.workerProfile.id !== workerProfile.id) {
      throw new ForbiddenException('You do not own this bid');
    }

    if (bid.status !== 'PENDING') {
      throw new BadRequestException(
        `Cannot edit a bid with status ${bid.status}`,
      );
    }

    if (bid.editCount >= 1) {
      throw new BadRequestException('Bids can only be edited once');
    }

    if (bid.booking.status !== BookingStatus.PENDING) {
      throw new BadRequestException(
        `Cannot edit a bid on a booking that is no longer PENDING (current status: ${bid.booking.status})`,
      );
    }

    const updated = await this.bidsRepository.updateBid(bidId, { amount, message });
    this.logger.log(`[editBid] updated bidId=${bidId}`);
    return updated;
  }

  // ── Worker: get my bid on a booking ─────────────────────────────────────

  async getMyBid(userId: string, bookingId: string): Promise<BidWithRelations> {
    const workerProfile = await this.bidsRepository.findWorkerProfileByUserId(userId);
    if (!workerProfile) {
      throw new ForbiddenException('Worker profile not found');
    }

    const booking = await this.bidsRepository.findBookingById(bookingId);
    if (!booking) {
      throw new NotFoundException(`Booking ${bookingId} not found`);
    }

    const bid = await this.bidsRepository.findMyBidOnBooking(bookingId, workerProfile.id);
    if (!bid) {
      throw new NotFoundException('You have not placed a bid on this booking');
    }

    return bid;
  }

  // ── Client: list bids for a booking ─────────────────────────────────────

  async getBidsForBooking(userId: string, bookingId: string): Promise<BidResponseDto[]> {
    const clientProfile = await this.bidsRepository.findClientProfileByUserId(userId);
    if (!clientProfile) {
      throw new ForbiddenException('Client profile not found');
    }

    const booking = await this.bidsRepository.findBookingById(bookingId);
    if (!booking) {
      throw new NotFoundException(`Booking ${bookingId} not found`);
    }

    if (booking.clientProfileId !== clientProfile.id) {
      throw new ForbiddenException('You do not own this booking');
    }

    const bids = await this.bidsRepository.findBidsByBookingId(bookingId);

    return bids.map((bid) => {
      const wp = bid.workerProfile;
      const completedJobs = wp.bookings.length;
      const distanceKm = this._haversineKm(
        booking.latitude,
        booking.longitude,
        wp.currentLat,
        wp.currentLng,
      );

      const worker: BidWorkerDto = {
        id: wp.id,
        firstName: wp.firstName,
        lastName: wp.lastName,
        avatarUrl: wp.avatarUrl,
        rating: Number(wp.rating),
        completedJobs,
        distanceKm,
        currentLat: wp.currentLat ?? null,
        currentLng: wp.currentLng ?? null,
        locationUpdatedAt: wp.locationUpdatedAt ?? null,
      };

      return {
        id: bid.id,
        bookingId: bid.bookingId,
        amount: Number(bid.amount),
        message: bid.message,
        status: bid.status,
        editCount: bid.editCount,
        createdAt: bid.createdAt,
        updatedAt: bid.updatedAt,
        worker,
      };
    });
  }

  // ── Worker: live bid feed for a booking ─────────────────────────────────

  async getBidsForBookingAsWorker(
    userId: string,
    bookingId: string,
  ): Promise<BidResponseDto[]> {
    this.logger.log(`[getBidsForBookingAsWorker] userId=${userId} bookingId=${bookingId}`);

    const workerProfile = await this.bidsRepository.findWorkerProfileByUserId(userId);
    if (!workerProfile) {
      this.logger.warn(`[getBidsForBookingAsWorker] no worker profile for userId=${userId}`);
      throw new ForbiddenException('Worker profile not found');
    }

    this.logger.log(`[getBidsForBookingAsWorker] workerProfileId=${workerProfile.id}`);

    const booking = await this.bidsRepository.findBookingById(bookingId);
    if (!booking) {
      throw new NotFoundException(`Booking ${bookingId} not found`);
    }

    this.logger.log(
      `[getBidsForBookingAsWorker] booking.status=${booking.status} booking.categoryId=${booking.categoryId}`,
    );

    // Booking must still be PENDING (unassigned) for a worker to view the feed.
    if (booking.status !== BookingStatus.PENDING) {
      this.logger.log(
        `[getBidsForBookingAsWorker] booking not PENDING (${booking.status}) — returning []`,
      );
      return [];
    }

    // Worker must have a skill matching this booking's category.
    const categoryIds = workerProfile.skills.map((s) => s.categoryId);
    this.logger.log(
      `[getBidsForBookingAsWorker] worker categoryIds=${JSON.stringify(categoryIds)}`,
    );

    const categoryMatch = categoryIds.includes(booking.categoryId);
    this.logger.log(
      `[getBidsForBookingAsWorker] categoryMatch=${categoryMatch} (booking.categoryId=${booking.categoryId})`,
    );

    if (!categoryMatch) {
      throw new ForbiddenException('You are not allowed to view bids for this job');
    }

    const bids = await this.bidsRepository.findBidsByBookingIdNewestFirst(bookingId);

    return bids.map((bid) => {
      const wp = bid.workerProfile;
      const completedJobs = wp.bookings.length;
      const distanceKm = this._haversineKm(
        booking.latitude,
        booking.longitude,
        wp.currentLat,
        wp.currentLng,
      );

      const worker: BidWorkerDto = {
        id: wp.id,
        firstName: wp.firstName,
        lastName: wp.lastName,
        avatarUrl: wp.avatarUrl,
        rating: Number(wp.rating),
        completedJobs,
        distanceKm,
        currentLat: wp.currentLat ?? null,
        currentLng: wp.currentLng ?? null,
        locationUpdatedAt: wp.locationUpdatedAt ?? null,
      };

      return {
        id: bid.id,
        bookingId: bid.bookingId,
        amount: Number(bid.amount),
        message: bid.message,
        status: bid.status,
        editCount: bid.editCount,
        createdAt: bid.createdAt,
        updatedAt: bid.updatedAt,
        worker,
      };
    });
  }

  // ── Client: accept a bid ─────────────────────────────────────────────────

  async acceptBid(userId: string, bidId: string) {
    this.logger.log(`[acceptBid] userId=${userId} bidId=${bidId}`);

    const clientProfile = await this.bidsRepository.findClientProfileByUserId(userId);
    if (!clientProfile) {
      throw new ForbiddenException('Client profile not found');
    }

    const bid = await this.bidsRepository.findBidById(bidId);
    if (!bid) {
      throw new NotFoundException(`Bid ${bidId} not found`);
    }

    if (bid.booking.clientProfileId !== clientProfile.id) {
      throw new ForbiddenException('You do not own this booking');
    }

    if (bid.booking.status !== BookingStatus.PENDING) {
      throw new BadRequestException(
        `Cannot accept a bid on a booking that is no longer PENDING (current status: ${bid.booking.status})`,
      );
    }

    if (bid.status !== 'PENDING') {
      throw new BadRequestException('This bid is no longer available');
    }

    const booking = await this.bidsRepository.acceptBid(
      bidId,
      bid.booking.id,
      bid.workerProfile.id,
    );

    // Fire-and-forget notification to the winning worker.
    this.notificationsService
      .notify({
        userId: bid.workerProfile.userId,
        eventKey: 'BID_ACCEPTED',
        title: 'Bid Accepted!',
        body: 'Your bid has been accepted. Head to the job details.',
        bookingId: bid.booking.id,
        route: `/worker/jobs/${bid.booking.id}`,
      })
      .catch((err) => this.logger.warn(`[acceptBid] notify failed: ${err.message}`));

    // Ensure a chat thread exists for this client-worker pair.
    // Uses the userId fields returned by the acceptBid transaction.
    if (booking.clientProfile?.userId && booking.workerProfile?.userId) {
      void this.chatService.ensureConversationForBooking(
        booking.clientProfile.userId,
        booking.workerProfile.userId,
      );
    }

    this.logger.log(`[acceptBid] accepted bidId=${bidId} bookingId=${bid.booking.id}`);
    return { success: true, message: 'Bid accepted', bookingId: bid.booking.id };
  }

  // ── Worker: available jobs (new jobs feed) ───────────────────────────────

  async getNewJobsForWorker(userId: string) {
    const workerProfile = await this.bidsRepository.findWorkerProfileByUserId(userId);
    if (!workerProfile) {
      throw new ForbiddenException('Worker profile not found');
    }

    this._assertWorkerEligible(workerProfile);

    const categoryIds = workerProfile.skills.map((s) => s.categoryId);

    this.logger.log(
      `[getNewJobsForWorker] workerId=${workerProfile.id} currentlyWorking=${workerProfile.currentlyWorking} skillCategoryIds=${JSON.stringify(categoryIds)}`,
    );

    if (categoryIds.length === 0) {
      this.logger.log(`[getNewJobsForWorker] workerId=${workerProfile.id} — no skills set, returning []`);
      return [];
    }

    this.logger.log(
      `[getNewJobsForWorker] querying PENDING bookings for categoryIds=${JSON.stringify(categoryIds)}`,
    );

    const bookings = await this.bidsRepository.findAvailableJobsForWorker(
      workerProfile.id,
      categoryIds,
    );

    this.logger.log(
      `[getNewJobsForWorker] workerId=${workerProfile.id} — total PENDING jobs found after status+category filter: ${bookings.length}`,
    );

    const result = bookings.map((b) => {
      const distanceKm = this._haversineKm(
        b.latitude,
        b.longitude,
        workerProfile.currentLat,
        workerProfile.currentLng,
      );

      const myBid = b.bids?.[0] ?? null;
      const hasMyBid = myBid !== null;

      this.logger.log(
        `[getNewJobsForWorker] bookingId=${b.id} status=${b.status} categoryId=${b.categoryId} hasMyBid=${hasMyBid}`,
      );

      return {
        id: b.id,
        title: b.title,
        description: b.description,
        status: b.status,
        urgency: b.urgency,
        timeSlot: b.timeSlot,
        addressLine: b.addressLine,
        city: b.city,
        latitude: b.latitude,
        longitude: b.longitude,
        scheduledAt: b.scheduledAt,
        createdAt: b.createdAt,
        category: b.category,
        client: b.clientProfile,
        bidCount: b._count.bids,
        distanceKm,
        hasMyBid,
        myBidUpdatedAt: myBid?.updatedAt ?? null,
        workerProfileId: b.workerProfileId ?? null,
      };
    });

    this.logger.log(
      `[getNewJobsForWorker] workerId=${workerProfile.id} — returning ${result.length} jobs (bidded + non-bidded)`,
    );

    return result;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  private _assertWorkerEligible(workerProfile: {
    status: WorkerStatus;
    verificationStatus: VerificationStatus;
  }): void {
    if (workerProfile.status !== WorkerStatus.ACTIVE) {
      throw new ForbiddenException('Worker account is not active');
    }
    if (workerProfile.verificationStatus !== VerificationStatus.VERIFIED) {
      throw new ForbiddenException('Worker account is not verified');
    }
  }

  /** Returns null when either coordinate pair is missing. */
  private _haversineKm(
    lat1: number,
    lng1: number,
    lat2: number | null | undefined,
    lng2: number | null | undefined,
  ): number | null {
    if (lat2 == null || lng2 == null) return null;
    const R = 6371;
    const dLat = this._deg2rad(lat2 - lat1);
    const dLng = this._deg2rad(lng2 - lng1);
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(this._deg2rad(lat1)) *
        Math.cos(this._deg2rad(lat2)) *
        Math.sin(dLng / 2) ** 2;
    return +(R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))).toFixed(2);
  }

  private _deg2rad(deg: number) {
    return (deg * Math.PI) / 180;
  }
}
