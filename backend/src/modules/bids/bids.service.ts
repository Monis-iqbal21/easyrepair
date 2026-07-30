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
import {
  BookingLane,
  BookingStatus,
  WorkerStatus,
  WorkerOnboardingStatus,
} from '@prisma/client';
import { BidsRepository, BidWithRelations } from './bids.repository';
import { BidResponseDto, BidWorkerDto } from './dto/bid-response.dto';
import { NotificationsService } from '../notifications/notifications.service';
import { ChatService } from '../chat/chat.service';
import { WorkerUnavailableError } from '../../common/errors/worker-unavailable.error';
import { haversineKm } from '../../common/utils/geo.util';
import { calculatePlatformFee } from '../../common/utils/commission.util';
import {
  assertEligibleForInspectionBidding,
  isEligibleForInspectionBidding,
} from '../../common/utils/inspection-bidder-eligibility.util';

/** Rebid/update cooldown, measured off the bid row's own updatedAt. Server-time authoritative. */
const BID_COOLDOWN_SECONDS = 60;

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
    this.logger.log(
      `[createBid] userId=${userId} bookingId=${bookingId} amount=${amount}`,
    );

    const workerProfile =
      await this.bidsRepository.findWorkerProfileByUserId(userId);
    if (!workerProfile) {
      throw new ForbiddenException('Worker profile not found');
    }

    this._assertWorkerApproved(workerProfile);

    const booking = await this.bidsRepository.findBookingById(bookingId);
    if (!booking) {
      throw new NotFoundException(`Booking ${bookingId} not found`);
    }

    if (booking.status !== BookingStatus.PENDING) {
      throw new BadRequestException(
        `Bids can only be placed on PENDING bookings (current status: ${booking.status})`,
      );
    }

    // BIDDING is always biddable. INSPECTION is biddable only once the
    // customer has explicitly opted to "Find Other Ustaad" — ordinary
    // Inspection/Standard bookings must never accept bids.
    const postInspection = this._postInspectionBiddingContext(booking);
    if (booking.lane !== BookingLane.BIDDING && !postInspection.isOpen) {
      throw new BadRequestException(
        'Bidding is not available for this booking.',
      );
    }
    if (postInspection.isOpen) {
      // Post-inspection repair jobs (old-style reopened inspections AND
      // new-style linked BIDDING children) enforce the full approved/active/
      // profile-completed/online/category/radius/fresh-GPS gate (same
      // standard as the nearby-worker notification pipeline), plus exclusion
      // of the original inspecting worker. Normal BIDDING lane deliberately
      // stays more permissive (workers may browse/bid while offline/distant)
      // — this gate is scoped to post-inspection jobs only.
      assertEligibleForInspectionBidding(
        workerProfile,
        booking,
        postInspection.inspectorWorkerProfileId,
      );
    }

    const existing = await this.bidsRepository.findExistingBid(
      bookingId,
      workerProfile.id,
    );

    if (existing) {
      // Enforce cooldown before allowing a re-submit/update. Server clock is
      // authoritative (compared against the DB row's own updatedAt) — a
      // client can't bypass this by resubmitting from another device or
      // retrying the request, since the check is always re-evaluated
      // against the persisted timestamp, not anything the client sends.
      this._assertCooldownElapsed(existing.updatedAt);

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
      const workerName =
        [workerProfile.firstName, workerProfile.lastName]
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
    this.logger.log(
      `[editBid] userId=${userId} bidId=${bidId} amount=${amount}`,
    );

    const workerProfile =
      await this.bidsRepository.findWorkerProfileByUserId(userId);
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

    this._assertWorkerApproved(workerProfile);

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

    // Re-check the same reopened-inspection eligibility gate enforced at bid
    // creation — a worker could have gone offline/left the radius since
    // their original bid, so editing must re-verify, not just creating.
    const fullBooking = await this.bidsRepository.findBookingById(
      bid.booking.id,
    );
    if (fullBooking) {
      const postInspection = this._postInspectionBiddingContext(fullBooking);
      if (postInspection.isOpen) {
        assertEligibleForInspectionBidding(
          workerProfile,
          fullBooking,
          postInspection.inspectorWorkerProfileId,
        );
      }
    }

    // Same 60s cooldown as the POST re-submit path in createBid, keyed off
    // the same server-authoritative bid.updatedAt clock — PATCH must not be
    // usable as a bypass route for the amount-change cooldown.
    this._assertCooldownElapsed(bid.updatedAt);

    const updated = await this.bidsRepository.updateBid(bidId, {
      amount,
      message,
    });
    this.logger.log(`[editBid] updated bidId=${bidId}`);
    return updated;
  }

  // ── Worker: get my bid on a booking ─────────────────────────────────────

  async getMyBid(
    userId: string,
    bookingId: string,
  ): Promise<BidWithRelations & { cooldownRemainingSeconds: number }> {
    const workerProfile =
      await this.bidsRepository.findWorkerProfileByUserId(userId);
    if (!workerProfile) {
      throw new ForbiddenException('Worker profile not found');
    }

    const booking = await this.bidsRepository.findBookingById(bookingId);
    if (!booking) {
      throw new NotFoundException(`Booking ${bookingId} not found`);
    }

    const bid = await this.bidsRepository.findMyBidOnBooking(
      bookingId,
      workerProfile.id,
    );
    if (!bid) {
      throw new NotFoundException('You have not placed a bid on this booking');
    }

    // Server-authoritative remaining cooldown, same clock basis as createBid.
    const secondsSinceUpdate =
      (Date.now() - new Date(bid.updatedAt).getTime()) / 1000;
    const cooldownRemainingSeconds = Math.max(
      0,
      Math.ceil(BID_COOLDOWN_SECONDS - secondsSinceUpdate),
    );

    return { ...bid, cooldownRemainingSeconds };
  }

  // ── Client: list bids for a booking ─────────────────────────────────────

  async getBidsForBooking(
    userId: string,
    bookingId: string,
  ): Promise<BidResponseDto[]> {
    const clientProfile =
      await this.bidsRepository.findClientProfileByUserId(userId);
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
    const workerProfile =
      await this.bidsRepository.findWorkerProfileByUserId(userId);
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
      throw new ForbiddenException(
        'You are not allowed to view bids for this job',
      );
    }

    const bids =
      await this.bidsRepository.findBidsByBookingIdNewestFirst(bookingId);

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

    const clientProfile =
      await this.bidsRepository.findClientProfileByUserId(userId);
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

    // BIDDING has no parts concept — the accepted bid amount is the full
    // labour/service commission base.
    const finalPrice = Number(bid.amount);
    const platformFee = calculatePlatformFee(finalPrice);

    let booking: Awaited<ReturnType<typeof this.bidsRepository.acceptBid>>;
    try {
      booking = await this.bidsRepository.acceptBid(
        bidId,
        bid.booking.id,
        bid.workerProfile.id,
        finalPrice,
        platformFee,
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
      .catch((err) =>
        this.logger.warn(`[acceptBid] notify failed: ${err.message}`),
      );

    // Ensure a chat thread exists for this client-worker pair.
    // Uses the userId fields returned by the acceptBid transaction.
    if (booking.clientProfile?.userId && booking.workerProfile?.userId) {
      void this.chatService.ensureConversationForBooking(
        booking.clientProfile.userId,
        booking.workerProfile.userId,
      );
    }

    this.logger.log(
      `[acceptBid] accepted bidId=${bidId} bookingId=${bid.booking.id}`,
    );
    return {
      success: true,
      message: 'Bid accepted',
      bookingId: bid.booking.id,
    };
  }

  // ── Worker: available jobs (new jobs feed) ───────────────────────────────

  async getNewJobsForWorker(userId: string) {
    const workerProfile =
      await this.bidsRepository.findWorkerProfileByUserId(userId);
    if (!workerProfile) {
      throw new ForbiddenException('Worker profile not found');
    }

    this._assertWorkerApproved(workerProfile);

    const categoryIds = workerProfile.skills.map((s) => s.categoryId);

    if (categoryIds.length === 0) {
      return [];
    }

    const allBookings = await this.bidsRepository.findAvailableJobsForWorker(
      workerProfile.id,
      categoryIds,
    );

    // Post-inspection repair jobs — old-style reopened (FIND_OTHER_USTAAD)
    // inspections AND new-style linked BIDDING children — are hidden from a
    // worker's New Jobs feed if they wouldn't pass the same eligibility gate
    // enforced at report-view/bid-create time (offline, out of radius, stale
    // GPS, or the original inspector themselves). Because this check runs
    // fresh on every call against the worker's live location/online state, a
    // worker who enters the radius (or comes online) later sees the still-
    // open job on their next refresh — visibility is never limited to the
    // one-time creation push. Normal BIDDING and ordinary Standard/
    // Inspection jobs are untouched.
    const bookings = allBookings.filter((b) => {
      const postInspection = this._postInspectionBiddingContext(b);
      if (!postInspection.isOpen) return true;
      return isEligibleForInspectionBidding(
        workerProfile,
        b,
        postInspection.inspectorWorkerProfileId,
      );
    });

    const result = bookings.map((b) => {
      const distanceKm = haversineKm(
        b.latitude,
        b.longitude,
        workerProfile.currentLat,
        workerProfile.currentLng,
      );

      const myBid = b.bids?.[0] ?? null;
      const hasMyBid = myBid !== null;
      // Server-authoritative remaining cooldown so Flutter can render a
      // countdown without trusting the device clock.
      let myBidCooldownRemainingSeconds = 0;
      if (myBid) {
        const secondsSinceUpdate =
          (Date.now() - new Date(myBid.updatedAt).getTime()) / 1000;
        myBidCooldownRemainingSeconds = Math.max(
          0,
          Math.ceil(BID_COOLDOWN_SECONDS - secondsSinceUpdate),
        );
      }

      // INSPECTION jobs are only actionable-as-a-bid once the customer has
      // opted to "Find Other Ustaad" — ordinary Standard/Inspection jobs
      // stay direct-assign-only (see NewJobEntity.isDirectAssignLane on the
      // Flutter side, which reads this field for the lane==inspection case).
      const isOpenForBidding =
        b.lane === 'BIDDING' ||
        (b.lane === 'INSPECTION' &&
          b.inspectionReport?.decisionStatus === 'FIND_OTHER_USTAAD');

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
        inspectionDecisionStatus: b.inspectionReport?.decisionStatus ?? null,
        // Linked post-inspection repair job marker — the worker app shows
        // the optional "Inspection Report Dekhein" entry point off this.
        sourceInspectionBookingId: b.sourceInspectionBookingId ?? null,
        isOpenForBidding,
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
        myBidCooldownRemainingSeconds,
        workerProfileId: b.workerProfileId ?? null,
      };
    });

    return result;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /**
   * Identifies a booking as a post-inspection repair job open for bidding,
   * and who the original inspecting worker is (must be excluded from
   * bidding on it). Two shapes exist:
   *  - old-style: the INSPECTION booking itself reopened in place
   *    (decisionStatus FIND_OTHER_USTAAD on its own report);
   *  - new-style: a BIDDING-lane child booking linked back to the completed
   *    inspection via sourceInspectionBookingId — the inspector is on the
   *    source booking's report.
   */
  private _postInspectionBiddingContext(booking: {
    lane: BookingLane | string;
    sourceInspectionBookingId?: string | null;
    inspectionReport?: {
      decisionStatus: string;
      workerProfileId: string;
    } | null;
    sourceInspectionBooking?: {
      inspectionReport: {
        decisionStatus: string;
        workerProfileId: string;
      } | null;
    } | null;
  }): { isOpen: boolean; inspectorWorkerProfileId: string | null } {
    if (
      booking.lane === BookingLane.INSPECTION &&
      booking.inspectionReport?.decisionStatus === 'FIND_OTHER_USTAAD'
    ) {
      return {
        isOpen: true,
        inspectorWorkerProfileId: booking.inspectionReport.workerProfileId,
      };
    }
    if (
      booking.lane === BookingLane.BIDDING &&
      booking.sourceInspectionBookingId != null
    ) {
      return {
        isOpen: true,
        inspectorWorkerProfileId:
          booking.sourceInspectionBooking?.inspectionReport?.workerProfileId ??
          null,
      };
    }
    return { isOpen: false, inspectorWorkerProfileId: null };
  }

  /**
   * Single cooldown gate shared by every bid-amount-changing route (POST
   * re-submit and PATCH edit alike) so there is exactly one cooldown clock
   * per bid, keyed off the DB row's own @updatedAt — never client-supplied
   * data — making it authoritative across devices and unbypassable by
   * switching routes.
   */
  private _assertCooldownElapsed(lastUpdatedAt: Date): void {
    const secondsSinceUpdate =
      (Date.now() - new Date(lastUpdatedAt).getTime()) / 1000;
    if (secondsSinceUpdate < BID_COOLDOWN_SECONDS) {
      const waitSecs = Math.ceil(BID_COOLDOWN_SECONDS - secondsSinceUpdate);
      throw new HttpException(
        {
          message: `Please wait ${waitSecs} second${waitSecs === 1 ? '' : 's'} before updating your bid`,
          cooldownRemainingSeconds: waitSecs,
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }

  /**
   * Single hireability gate — admin-approved onboarding is now required even
   * to browse New Jobs, not just to bid/apply (previously getNewJobsForWorker
   * only checked account status/verification and let an incomplete profile
   * browse; that carve-out is intentionally removed per the onboarding flow).
   */
  private _assertWorkerApproved(workerProfile: {
    status: WorkerStatus;
    onboardingStatus: WorkerOnboardingStatus;
    profileCompleted: boolean;
  }): void {
    if (workerProfile.status !== WorkerStatus.ACTIVE) {
      throw new ForbiddenException('Worker account is not active');
    }
    if (
      workerProfile.onboardingStatus !== WorkerOnboardingStatus.APPROVED ||
      !workerProfile.profileCompleted
    ) {
      throw new ForbiddenException(
        'Profile complete karein taake jobs apply kar saken.',
      );
    }
  }
}
