import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { BookingStatus, VerificationStatus, WorkerStatus } from '@prisma/client';
import { BidsRepository, BidWithRelations } from './bids.repository';
import { BidResponseDto, BidWorkerDto } from './dto/bid-response.dto';
import { NotificationsService } from '../notifications/notifications.service';
import { ChatService } from '../chat/chat.service';
import { WorkerUnavailableError } from '../../common/errors/worker-unavailable.error';
import { haversineKm } from '../../common/utils/geo.util';

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
    this._assertProfileCompleted(workerProfile);

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

    // Notify the booking client about the new bid.
    // booking.clientProfile is already loaded by findBookingById.
    const clientUserId = booking.clientProfile?.userId;
    if (clientUserId) {
      const workerName = [workerProfile.firstName, workerProfile.lastName]
        .filter(Boolean)
        .join(' ') || 'A worker';
      void this.notificationsService.notify({
        userId: clientUserId,
        eventKey: 'bid.received',
        title: 'New offer received',
        body: `${workerName} sent you an offer for PKR ${amount}`,
        bookingId,
        route: `/client/booking/${bookingId}`,
        actorUserId: userId,
        actorRole: 'WORKER',
        entityType: 'booking',
        entityId: bookingId,
      });
    }

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

    this._assertProfileCompleted(workerProfile);

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
      const distanceKm = haversineKm(
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
    const workerProfile = await this.bidsRepository.findWorkerProfileByUserId(userId);
    if (!workerProfile) {
      throw new ForbiddenException('Worker profile not found');
    }

    const booking = await this.bidsRepository.findBookingById(bookingId);
    if (!booking) {
      throw new NotFoundException(`Booking ${bookingId} not found`);
    }

    // Booking must still be PENDING (unassigned) for a worker to view the feed.
    if (booking.status !== BookingStatus.PENDING) {
      return [];
    }

    // Worker must have a skill matching this booking's category.
    const categoryIds = workerProfile.skills.map((s) => s.categoryId);
    if (!categoryIds.includes(booking.categoryId)) {
      throw new ForbiddenException('You are not allowed to view bids for this job');
    }

    const bids = await this.bidsRepository.findBidsByBookingIdNewestFirst(bookingId);

    return bids.map((bid) => {
      const wp = bid.workerProfile;
      const completedJobs = wp.bookings.length;
      const distanceKm = haversineKm(
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

    let booking: Awaited<ReturnType<typeof this.bidsRepository.acceptBid>>;
    try {
      booking = await this.bidsRepository.acceptBid(
        bidId,
        bid.booking.id,
        bid.workerProfile.id,
        Number(bid.amount),
      );
    } catch (err) {
      if (err instanceof WorkerUnavailableError) {
        throw new ConflictException(
          'This Ustaad just got another job. Please choose another Ustaad.',
        );
      }
      throw err;
    }

    // Fire-and-forget notification to the winning worker.
    this.notificationsService
      .notify({
        userId: bid.workerProfile.userId,
        eventKey: 'bid.accepted',
        title: 'Bid Accepted!',
        body: 'Your bid has been accepted. Head to the job details.',
        bookingId: bid.booking.id,
        route: `/worker/job/${bid.booking.id}`,
        actorUserId: userId,
        actorRole: 'CLIENT',
        entityType: 'booking',
        entityId: bid.booking.id,
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

    if (categoryIds.length === 0) {
      return [];
    }

    const bookings = await this.bidsRepository.findAvailableJobsForWorker(
      workerProfile.id,
      categoryIds,
    );

    const result = bookings.map((b) => {
      const distanceKm = haversineKm(
        b.latitude,
        b.longitude,
        workerProfile.currentLat,
        workerProfile.currentLng,
      );

      const myBid = b.bids?.[0] ?? null;
      const hasMyBid = myBid !== null;

      return {
        id: b.id,
        title: b.title,
        description: b.description,
        status: b.status,
        urgency: b.urgency,
        timeSlot: b.timeSlot,
        // Privacy: unassigned/pending workers must never receive the exact
        // address — only city + server-computed distanceKm below. Exact
        // address/lat/lng are only exposed once a worker is actually hired
        // (see WorkersService._toJobDto's isAssignedToCaller gate).
        city: b.city,
        scheduledAt: b.scheduledAt,
        createdAt: b.createdAt,
        inspection: b.inspection,
        lane: b.lane,
        standardServiceItems: b.standardServiceItems.map((item) => ({
          id: item.id,
          standardServiceId: item.standardServiceId,
          nameSnapshot: item.nameSnapshot,
          priceSnapshot: item.priceSnapshot,
          quantity: item.quantity,
        })),
        category: b.category,
        client: b.clientProfile,
        bidCount: b._count.bids,
        distanceKm,
        hasMyBid,
        myBidUpdatedAt: myBid?.updatedAt ?? null,
        workerProfileId: b.workerProfileId ?? null,
      };
    });

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

  /**
   * Gate for actions that commit a worker to a job (bid/apply/edit-bid).
   * Deliberately NOT applied to read-only endpoints like getNewJobsForWorker —
   * an incomplete-profile Ustaad can still browse jobs, just not act on them.
   */
  private _assertProfileCompleted(workerProfile: {
    profileCompleted: boolean;
  }): void {
    if (!workerProfile.profileCompleted) {
      throw new ForbiddenException(
        'Profile complete karein taake jobs apply kar saken.',
      );
    }
  }

}
