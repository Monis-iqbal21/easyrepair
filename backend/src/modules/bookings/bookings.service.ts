import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
  Logger,
} from '@nestjs/common';
import { InjectQueue } from '@nestjs/bull';
import { Queue } from 'bull';
import {
  AttachmentType,
  AvailabilityStatus,
  BookingLane,
  BookingStatus,
  BookingUrgency,
  TimeSlot,
  UrgentWindow,
} from '@prisma/client';
import {
  BookingsRepository,
  BookingWithRelations,
} from './bookings.repository';
import {
  BOOKINGS_QUEUE,
  EXPIRE_BOOKING_JOB,
  ExpireBookingJobData,
} from './bookings.processor';
import { CreateBookingDto } from './dto/create-booking.dto';
import {
  BookingAttachmentDto,
  BookingResponseDto,
  BookingReviewDto,
  NearbyWorkerDto,
  NearbyWorkersResponseDto,
  WorkerSummaryDto,
} from './dto/booking-response.dto';
import { UpdateBookingDto } from './dto/update-booking.dto';
import { CreateReviewDto } from './dto/create-review.dto';
import { StorageService } from '../storage/storage.service';
import { NotificationsService } from '../notifications/notifications.service';
import { ChatService } from '../chat/chat.service';

/** 72 hours in milliseconds — auto-expiry window for PENDING bookings, all lanes. */
const BOOKING_EXPIRY_MS = 72 * 60 * 60 * 1000;

/** Max time to wait on the Bull/Redis queue before giving up — expiry scheduling must never hang the request. */
const EXPIRY_QUEUE_TIMEOUT_MS = 1800;

@Injectable()
export class BookingsService {
  private readonly logger = new Logger(BookingsService.name);

  constructor(
    private readonly bookingsRepository: BookingsRepository,
    private readonly storageService: StorageService,
    private readonly notificationsService: NotificationsService,
    private readonly chatService: ChatService,
    @InjectQueue(BOOKINGS_QUEUE) private readonly bookingsQueue: Queue,
  ) {}

  async createBooking(
    userId: string,
    dto: CreateBookingDto,
  ): Promise<BookingResponseDto> {
    this.logger.log(
      `[createBooking] userId=${userId} payload=${JSON.stringify(dto)}`,
    );

    const profile =
      await this.bookingsRepository.findClientProfileByUserId(userId);
    if (!profile) {
      this.logger.warn(
        `[createBooking] no client profile for userId=${userId}`,
      );
      throw new ForbiddenException('Client profile not found');
    }
    this.logger.log(`[createBooking] clientProfileId=${profile.id}`);

    const category = await this.bookingsRepository.findCategoryByName(
      dto.serviceCategory,
    );
    if (!category) {
      this.logger.warn(
        `[createBooking] category not found: "${dto.serviceCategory}"`,
      );
      throw new NotFoundException(
        `Service category "${dto.serviceCategory}" not found. Please contact support.`,
      );
    }
    this.logger.log(
      `[createBooking] categoryId=${category.id} name=${category.name}`,
    );

    // Reject missing or zero coordinates — every booking must have a real location.
    if (
      dto.latitude === undefined ||
      dto.longitude === undefined ||
      (dto.latitude === 0 && dto.longitude === 0)
    ) {
      throw new BadRequestException(
        'Valid GPS coordinates are required to create a booking.',
      );
    }

    const scheduledAt = dto.scheduledAt ? new Date(dto.scheduledAt) : undefined;

    if (dto.urgency === BookingUrgency.NORMAL && !dto.timeSlot) {
      throw new BadRequestException(
        'A time slot is required for normal (non-urgent) bookings.',
      );
    }

    // Only meaningful for URGENT bookings — ignore any urgentWindow sent
    // alongside a NORMAL booking so stored data never contradicts urgency.
    const urgentWindow: UrgentWindow | undefined =
      dto.urgency === BookingUrgency.URGENT ? dto.urgentWindow : undefined;

    // Lane defaults to BIDDING when omitted — older app builds that don't
    // send `lane` at all keep exercising the existing bidding flow unchanged.
    const lane: BookingLane = dto.lane ?? BookingLane.BIDDING;

    let standardServiceId: string | undefined;
    let standardServiceNameSnapshot: string | undefined;
    let standardServicePriceSnapshot: number | undefined;
    let standardServiceItems:
      | Array<{
          standardServiceId: string;
          nameSnapshot: string;
          priceSnapshot: number;
          quantity?: number;
        }>
      | undefined;
    let inspectionFeeSnapshot: number | undefined;
    let estimatedPrice: number | undefined;

    if (lane === BookingLane.STANDARD) {
      // standardServiceIds (multi-select) takes precedence over the legacy
      // singular standardServiceId when both are present.
      const requestedIds =
        dto.standardServiceIds && dto.standardServiceIds.length > 0
          ? dto.standardServiceIds
          : dto.standardServiceId
            ? [dto.standardServiceId]
            : [];

      const resolved = await this._resolveStandardServiceSelection(
        category.id,
        requestedIds,
      );
      standardServiceItems = resolved.standardServiceItems;
      standardServiceId = resolved.standardServiceId;
      standardServiceNameSnapshot = resolved.standardServiceNameSnapshot;
      standardServicePriceSnapshot = resolved.standardServicePriceSnapshot;
      estimatedPrice = resolved.estimatedPrice;
    } else if (lane === BookingLane.INSPECTION) {
      if (category.inspectionFee === null || category.inspectionFee === undefined) {
        throw new BadRequestException(
          `Inspection is not available for "${category.name}".`,
        );
      }
      inspectionFeeSnapshot = category.inspectionFee;
      estimatedPrice = category.inspectionFee;
    }

    // Keep the legacy `inspection` flag in sync for older app builds/backend
    // consumers that only ever read the boolean, without letting it override
    // an explicit lane sent by newer builds.
    const inspection = dto.inspection ?? lane === BookingLane.INSPECTION;

    const now = new Date();
    const expiresAt = new Date(now.getTime() + BOOKING_EXPIRY_MS);

    const booking = await this.bookingsRepository.createBooking({
      clientProfileId: profile.id,
      categoryId: category.id,
      urgency: dto.urgency,
      timeSlot: dto.timeSlot,
      title: dto.title,
      description: dto.description ?? '',
      addressLine: dto.addressLine,
      city: dto.city ?? '',
      latitude: dto.latitude,
      longitude: dto.longitude,
      scheduledAt,
      inspection,
      urgentWindow,
      lane,
      standardServiceId,
      standardServiceNameSnapshot,
      standardServicePriceSnapshot,
      standardServiceItems,
      inspectionFeeSnapshot,
      estimatedPrice,
      expiresAt,
      liveStartedAt: now,
    });

    this.logger.log(`[createBooking] created bookingId=${booking.id} lane=${lane}`);

    // Fire-and-forget: expiry scheduling talks to Redis/Bull and must never
    // block or fail the booking-creation response.
    void this._scheduleExpiry(booking.id, expiresAt).catch((err) => {
      this.logger.warn(
        `[expiry] scheduleExpiry failed for bookingId=${booking.id}: ${(err as Error)?.message}`,
      );
    });

    return this._toDto(booking);
  }

  async getClientBookings(userId: string): Promise<BookingResponseDto[]> {
    this.logger.log(`[getClientBookings] userId=${userId}`);

    const profile =
      await this.bookingsRepository.findClientProfileByUserId(userId);
    if (!profile) {
      this.logger.warn(
        `[getClientBookings] no client profile for userId=${userId}`,
      );
      throw new ForbiddenException('Client profile not found');
    }

    const bookings =
      await this.bookingsRepository.findBookingsByClientProfileId(profile.id);
    this.logger.log(
      `[getClientBookings] clientProfileId=${profile.id} count=${bookings.length}`,
    );
    return bookings.map((b) => this._toDto(b));
  }

  async cancelBooking(
    userId: string,
    bookingId: string,
    reason?: string,
  ): Promise<BookingResponseDto> {
    const profile =
      await this.bookingsRepository.findClientProfileByUserId(userId);
    if (!profile) {
      throw new ForbiddenException('Client profile not found');
    }

    const booking = await this.bookingsRepository.findBookingById(bookingId);
    if (!booking) {
      throw new NotFoundException('Booking not found');
    }
    if (booking.clientProfileId !== profile.id) {
      throw new ForbiddenException('Not your booking');
    }

    if (booking.status !== BookingStatus.PENDING) {
      const reason =
        booking.workerProfileId != null
          ? 'Cannot cancel a booking that already has an assigned worker.'
          : `Cannot cancel a booking with status ${booking.status}`;
      throw new BadRequestException(reason);
    }

    const updated = await this.bookingsRepository.cancelBooking(
      bookingId,
      reason,
      booking.workerProfile?.id ?? null,
      'CLIENT',
    );

    // Booking is no longer PENDING — cancel its auto-expiry job. Fire-and-forget.
    void this._cancelExpiry(bookingId).catch((err) => {
      this.logger.warn(
        `[expiry] cancelExpiry failed for bookingId=${bookingId}: ${(err as Error)?.message}`,
      );
    });

    // Notify assigned worker that the job was cancelled by client
    if (updated.workerProfile?.userId) {
      void this.notificationsService.notify({
        userId: updated.workerProfile.userId,
        eventKey: 'booking.cancelled.by_client',
        title: 'Job Cancelled',
        body: 'The client has cancelled the job.',
        bookingId,
        route: `/worker/job/${bookingId}`,
        actorUserId: userId,
        actorRole: 'CLIENT',
        entityType: 'booking',
        entityId: bookingId,
      });
    }

    return this._toDto(updated);
  }

  async getBookingById(
    userId: string,
    bookingId: string,
  ): Promise<BookingResponseDto> {
    const profile =
      await this.bookingsRepository.findClientProfileByUserId(userId);
    if (!profile) throw new ForbiddenException('Client profile not found');

    const booking = await this.bookingsRepository.findBookingById(bookingId);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.clientProfileId !== profile.id) {
      throw new ForbiddenException('Not your booking');
    }

    return this._toDto(booking);
  }

  async updateBooking(
    userId: string,
    bookingId: string,
    dto: UpdateBookingDto,
  ): Promise<BookingResponseDto> {
    const profile =
      await this.bookingsRepository.findClientProfileByUserId(userId);
    if (!profile) throw new ForbiddenException('Client profile not found');

    const booking = await this.bookingsRepository.findBookingById(bookingId);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.clientProfileId !== profile.id)
      throw new ForbiddenException('Not your booking');

    if (booking.status !== BookingStatus.PENDING) {
      throw new BadRequestException(
        'Only PENDING bookings without an assigned worker can be edited.',
      );
    }
    if (booking.workerProfileId !== null) {
      throw new BadRequestException(
        'Cannot edit a booking that already has an assigned worker.',
      );
    }

    // Resolve new category id if the service category is being changed.
    let categoryId: string | undefined;
    if (dto.serviceCategory) {
      const category = await this.bookingsRepository.findCategoryByName(
        dto.serviceCategory,
      );
      if (!category) {
        throw new NotFoundException(
          `Service category "${dto.serviceCategory}" not found.`,
        );
      }
      categoryId = category.id;
    }

    // Reject 0,0 coordinates if caller is explicitly updating them.
    if (
      dto.latitude !== undefined &&
      dto.longitude !== undefined &&
      dto.latitude === 0 &&
      dto.longitude === 0
    ) {
      throw new BadRequestException(
        'Valid GPS coordinates are required (0,0 is not a valid location).',
      );
    }

    // Validate: if urgency changes to NORMAL, a timeSlot must be provided
    // (either in the dto or already on the booking).
    const newUrgency = dto.urgency ?? booking.urgency;
    const newTimeSlot =
      dto.timeSlot !== undefined ? dto.timeSlot : booking.timeSlot;
    if (newUrgency === BookingUrgency.NORMAL && !newTimeSlot) {
      throw new BadRequestException(
        'A time slot is required for normal (non-urgent) bookings.',
      );
    }

    // Only meaningful for URGENT bookings — if the effective urgency is/becomes
    // NORMAL, clear urgentWindow so stored data never contradicts urgency.
    // undefined here means "leave the stored value untouched".
    const urgentWindow: UrgentWindow | null | undefined =
      newUrgency === BookingUrgency.URGENT ? dto.urgentWindow : null;

    // Replace the STANDARD-lane sub-service selection when the client sent
    // one. Lane itself is never editable here, so this only makes sense on a
    // booking that's already STANDARD.
    let standardServiceUpdate:
      | Awaited<ReturnType<BookingsService['_resolveStandardServiceSelection']>>
      | undefined;
    if (dto.standardServiceIds !== undefined) {
      if (booking.lane !== BookingLane.STANDARD) {
        throw new BadRequestException(
          'standardServiceIds can only be updated on a STANDARD lane booking.',
        );
      }
      standardServiceUpdate = await this._resolveStandardServiceSelection(
        categoryId ?? booking.categoryId,
        dto.standardServiceIds,
      );
    }

    const updated = await this.bookingsRepository.updateBooking(bookingId, {
      categoryId,
      title: dto.title,
      description: dto.description,
      urgency: dto.urgency,
      timeSlot: dto.timeSlot,
      scheduledAt: dto.scheduledAt ? new Date(dto.scheduledAt) : undefined,
      addressLine: dto.addressLine,
      city: dto.city,
      latitude: dto.latitude,
      longitude: dto.longitude,
      inspection: dto.inspection,
      urgentWindow,
      ...(standardServiceUpdate && {
        standardServiceId: standardServiceUpdate.standardServiceId,
        standardServiceNameSnapshot:
          standardServiceUpdate.standardServiceNameSnapshot,
        standardServicePriceSnapshot:
          standardServiceUpdate.standardServicePriceSnapshot,
        standardServiceItems: standardServiceUpdate.standardServiceItems,
        estimatedPrice: standardServiceUpdate.estimatedPrice,
      }),
    });

    return this._toDto(updated);
  }

  /**
   * Validate + resolve STANDARD-lane sub-service ids into snapshot rows, the
   * legacy singular fields, and the combined price. Shared by createBooking
   * and updateBooking so both stay in sync.
   */
  private async _resolveStandardServiceSelection(
    categoryId: string,
    requestedIds: string[],
  ): Promise<{
    standardServiceItems: Array<{
      standardServiceId: string;
      nameSnapshot: string;
      priceSnapshot: number;
      quantity?: number;
    }>;
    standardServiceId: string;
    standardServiceNameSnapshot: string;
    standardServicePriceSnapshot: number;
    estimatedPrice: number;
  }> {
    if (requestedIds.length === 0) {
      throw new BadRequestException(
        'At least one standard service is required for a STANDARD lane booking.',
      );
    }

    const uniqueIds = Array.from(new Set(requestedIds));
    const services =
      await this.bookingsRepository.findStandardServicesByIds(uniqueIds);

    if (services.length !== uniqueIds.length) {
      throw new NotFoundException(
        'One or more selected standard services could not be found.',
      );
    }
    const invalid = services.find(
      (s) => !s.isActive || s.categoryId !== categoryId,
    );
    if (invalid) {
      throw new NotFoundException(
        'Selected standard service is not available for this category.',
      );
    }

    // Preserve the order the client selected them in.
    const byId = new Map(services.map((s) => [s.id, s]));
    const standardServiceItems = uniqueIds.map((id) => {
      const s = byId.get(id)!;
      return {
        standardServiceId: s.id,
        nameSnapshot: s.name,
        priceSnapshot: s.price,
        quantity: 1,
      };
    });

    // Legacy fields mirror the first selected item for older app builds.
    const first = standardServiceItems[0];
    const estimatedPrice = standardServiceItems.reduce(
      (sum, item) => sum + item.priceSnapshot * (item.quantity ?? 1),
      0,
    );

    return {
      standardServiceItems,
      standardServiceId: first.standardServiceId,
      standardServiceNameSnapshot: first.nameSnapshot,
      standardServicePriceSnapshot: first.priceSnapshot,
      estimatedPrice,
    };
  }

  async submitReview(
    userId: string,
    bookingId: string,
    dto: CreateReviewDto,
  ): Promise<BookingResponseDto> {
    const profile =
      await this.bookingsRepository.findClientProfileByUserId(userId);
    if (!profile) throw new ForbiddenException('Client profile not found');

    const booking = await this.bookingsRepository.findBookingById(bookingId);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.clientProfileId !== profile.id)
      throw new ForbiddenException('Not your booking');

    if (booking.status !== BookingStatus.COMPLETED) {
      throw new BadRequestException(
        'Reviews can only be submitted for completed bookings.',
      );
    }
    if (booking.review) {
      throw new ConflictException(
        'A review has already been submitted for this booking.',
      );
    }

    if (!booking.workerProfileId) {
      throw new BadRequestException(
        'Cannot review a booking without an assigned worker.',
      );
    }

    const updated = await this.bookingsRepository.createReview(bookingId, {
      rating: dto.rating,
      comment: dto.comment,
      workerProfileId: booking.workerProfileId,
    });

    // Notify worker of the new review
    if (updated.workerProfile?.userId) {
      void this.notificationsService.notify({
        userId: updated.workerProfile.userId,
        eventKey: 'booking.review.created',
        title: 'New Review',
        body: `Your client left you a ${dto.rating}-star review.`,
        bookingId,
        route: `/worker/job/${bookingId}`,
        actorUserId: userId,
        actorRole: 'CLIENT',
        entityType: 'booking',
        entityId: bookingId,
      });
    }

    return this._toDto(updated);
  }

  // ── Attachment endpoints ──────────────────────────────────────────────────

  async uploadAttachment(
    userId: string,
    bookingId: string,
    file: Express.Multer.File,
    durationSeconds?: number,
  ): Promise<BookingAttachmentDto> {
    const profile =
      await this.bookingsRepository.findClientProfileByUserId(userId);
    if (!profile) throw new ForbiddenException('Client profile not found');

    const booking = await this.bookingsRepository.findBookingById(bookingId);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.clientProfileId !== profile.id)
      throw new ForbiddenException('Not your booking');

    if (booking.status !== BookingStatus.PENDING) {
      throw new BadRequestException(
        'Attachments can only be added to PENDING bookings.',
      );
    }
    if (booking.workerProfileId !== null) {
      throw new BadRequestException(
        'Cannot add attachments to a booking that has an assigned worker.',
      );
    }

    const type = this._resolveAttachmentType(file.mimetype);
    const folder = this._attachmentFolder(bookingId, type);
    const uploaded = await this.storageService.uploadFile(
      file.buffer,
      file.originalname,
      file.mimetype,
      folder,
    );

    const attachment = await this.bookingsRepository.createAttachment({
      bookingId,
      type,
      url: uploaded.url,
      storageKey: uploaded.key,
      fileName: uploaded.fileName,
      mimeType: uploaded.mimeType,
      sizeBytes: uploaded.sizeBytes,
      durationSeconds: Number.isFinite(durationSeconds) ? durationSeconds : undefined,
    });

    return {
      id: attachment.id,
      type: attachment.type,
      url: attachment.url,
      storageKey: attachment.storageKey ?? null,
      fileName: attachment.fileName ?? null,
      mimeType: attachment.mimeType ?? null,
      sizeBytes: attachment.sizeBytes ?? null,
      durationSeconds: attachment.durationSeconds ?? null,
      thumbnailUrl: attachment.thumbnailUrl ?? null,
      createdAt: attachment.createdAt.toISOString(),
    };
  }

  async deleteAttachment(
    userId: string,
    bookingId: string,
    attachmentId: string,
  ): Promise<void> {
    const profile =
      await this.bookingsRepository.findClientProfileByUserId(userId);
    if (!profile) throw new ForbiddenException('Client profile not found');

    const booking = await this.bookingsRepository.findBookingById(bookingId);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.clientProfileId !== profile.id)
      throw new ForbiddenException('Not your booking');

    if (booking.status !== BookingStatus.PENDING) {
      throw new BadRequestException(
        'Attachments can only be removed from PENDING bookings.',
      );
    }
    if (booking.workerProfileId !== null) {
      throw new BadRequestException(
        'Cannot remove attachments from a booking that has an assigned worker.',
      );
    }

    const attachment =
      await this.bookingsRepository.findAttachmentById(attachmentId);
    if (!attachment) throw new NotFoundException('Attachment not found');
    if (attachment.bookingId !== bookingId)
      throw new ForbiddenException(
        'Attachment does not belong to this booking',
      );

    await this.bookingsRepository.deleteAttachment(attachmentId);
    await this.storageService.deleteByUrl(attachment.url);
  }

  // ── Nearby workers + assignment ───────────────────────────────────────────

  /**
   * Return workers who are online, near the booking location, and skilled in
   * the booking's service category.
   * When radiusKm is provided only that single radius is searched (the Flutter
   * client drives progressive expansion by calling this repeatedly with
   * increasing radii).  When radiusKm is omitted the full ladder is run
   * server-side for backward compatibility.
   */
  async getNearbyWorkers(
    userId: string,
    bookingId: string,
    radiusKm?: number,
  ): Promise<NearbyWorkersResponseDto> {
    const profile =
      await this.bookingsRepository.findClientProfileByUserId(userId);
    if (!profile) throw new ForbiddenException('Client profile not found');

    const booking = await this.bookingsRepository.findBookingById(bookingId);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.clientProfileId !== profile.id)
      throw new ForbiddenException('Not your booking');

    if (booking.status !== BookingStatus.PENDING) {
      throw new BadRequestException(
        'Nearby workers are only available for PENDING bookings.',
      );
    }
    if (booking.workerProfileId !== null) {
      throw new BadRequestException(
        'This booking already has an assigned worker.',
      );
    }
    if (
      booking.lane !== BookingLane.STANDARD &&
      booking.lane !== BookingLane.INSPECTION
    ) {
      throw new BadRequestException(
        'Nearby-worker selection is only available for STANDARD or INSPECTION bookings.',
      );
    }

    const excludedWorkerIds = booking.workerExclusions.map(
      (e) => e.workerProfileId,
    );

    const { workers, searchedRadiusKm, searchCompleted } =
      await this.bookingsRepository.findNearbyWorkers({
        categoryId: booking.categoryId,
        lat: booking.latitude,
        lng: booking.longitude,
        radiusKm,
        lane: booking.lane,
        excludedWorkerIds,
      });

    const workerDtos: NearbyWorkerDto[] = workers.map((w) => ({
      id: w.id,
      firstName: w.firstName,
      lastName: w.lastName,
      avatarUrl: w.avatarUrl,
      rating: w.rating,
      completedJobs: w.completedJobs,
      reviewsCount: w.reviewsCount,
      cancellationRate: w.cancellationRate,
      distanceKm: Math.round(w.distanceMeters / 100) / 10,
      skills: w.skills,
      recommended: w.recommended,
    }));

    // STANDARD lane: notify each listed worker (deduped) that they've been
    // suggested for this job. Fire-and-forget — must never block the response.
    if (booking.lane === BookingLane.STANDARD) {
      void this._notifyWorkersListedForStandardJob(bookingId, workerDtos);
    }

    return {
      workers: workerDtos,
      searchedRadiusKm,
      totalFound: workerDtos.length,
      searchCompleted,
    };
  }

  /**
   * Assign a specific worker to a PENDING booking.
   * Validates: ownership, booking status, no existing worker, worker is ONLINE.
   * Transitions the booking to ACCEPTED.
   */
  async assignWorker(
    userId: string,
    bookingId: string,
    workerProfileId: string,
  ): Promise<BookingResponseDto> {
    const profile =
      await this.bookingsRepository.findClientProfileByUserId(userId);
    if (!profile) throw new ForbiddenException('Client profile not found');

    const booking = await this.bookingsRepository.findBookingById(bookingId);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.clientProfileId !== profile.id)
      throw new ForbiddenException('Not your booking');

    if (booking.status !== BookingStatus.PENDING) {
      throw new BadRequestException(
        'Can only assign a worker to a PENDING booking.',
      );
    }
    if (booking.workerProfileId !== null) {
      throw new ConflictException(
        'This booking already has an assigned worker.',
      );
    }
    if (
      booking.lane !== BookingLane.STANDARD &&
      booking.lane !== BookingLane.INSPECTION
    ) {
      throw new BadRequestException(
        'Direct worker assignment is only available for STANDARD or INSPECTION bookings. Use the bidding flow instead.',
      );
    }

    const worker =
      await this.bookingsRepository.findWorkerProfileById(workerProfileId);
    if (!worker) throw new NotFoundException('Worker not found.');
    if (worker.availabilityStatus !== AvailabilityStatus.ONLINE) {
      throw new BadRequestException(
        'This worker is no longer available. Please choose another.',
      );
    }
    if (!worker.profileCompleted) {
      throw new BadRequestException(
        'This worker has not completed their profile yet and cannot be hired.',
      );
    }

    // STANDARD lane: total is the sum of all selected item snapshots
    // (supports multiple sub-services). Falls back to the legacy singular
    // snapshot when no item rows exist (older bookings created before the
    // item table existed). INSPECTION keeps its existing single-fee snapshot.
    const finalPrice =
      booking.lane === BookingLane.STANDARD
        ? booking.standardServiceItems.length > 0
          ? booking.standardServiceItems.reduce(
              (sum, item) => sum + item.priceSnapshot * item.quantity,
              0,
            )
          : booking.standardServicePriceSnapshot ?? undefined
        : booking.inspectionFeeSnapshot ?? undefined;

    const updated = await this.bookingsRepository.assignWorkerToBooking(
      bookingId,
      workerProfileId,
      finalPrice,
    );

    // Booking is no longer PENDING — cancel its auto-expiry job. Fire-and-forget.
    void this._cancelExpiry(bookingId).catch((err) => {
      this.logger.warn(
        `[expiry] cancelExpiry failed for bookingId=${bookingId}: ${(err as Error)?.message}`,
      );
    });

    // Notify the assigned worker
    if (worker.userId) {
      const hireBody =
        booking.lane === BookingLane.STANDARD
          ? 'Mubarak ho! Client ne aap ko Standard job ke liye hire kar liya hai.'
          : "You've been assigned to a new job. Tap to view details.";
      void this.notificationsService.notify({
        userId: worker.userId,
        eventKey: 'booking.assigned',
        title: 'New Job Assigned',
        body: hireBody,
        bookingId,
        route: `/worker/job/${bookingId}`,
        actorUserId: userId,
        actorRole: 'CLIENT',
        entityType: 'booking',
        entityId: bookingId,
      });

      // Ensure a chat conversation exists for this client-worker pair.
      // Fire-and-forget: errors are caught inside the method and never
      // propagate to the booking response.
      void this.chatService.ensureConversationForBooking(userId, worker.userId);
    }

    return this._toDto(updated);
  }

  // ── Lifecycle endpoints (assigned worker only) ────────────────────────────

  /** Resolve and authorize: booking exists, caller is the assigned worker. */
  private async _authorizeAssignedWorker(
    userId: string,
    bookingId: string,
  ): Promise<BookingWithRelations> {
    const workerProfile =
      await this.bookingsRepository.findWorkerProfileByUserId(userId);
    if (!workerProfile) throw new ForbiddenException('Worker profile not found');

    const booking = await this.bookingsRepository.findBookingById(bookingId);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.workerProfileId !== workerProfile.id) {
      throw new ForbiddenException('You are not assigned to this booking');
    }
    return booking;
  }

  /** POST /bookings/:id/on-my-way — ACCEPTED → EN_ROUTE. */
  async markOnMyWay(
    userId: string,
    bookingId: string,
  ): Promise<BookingResponseDto> {
    const booking = await this._authorizeAssignedWorker(userId, bookingId);
    if (booking.status !== BookingStatus.ACCEPTED) {
      throw new BadRequestException(
        `Cannot mark on-the-way from status ${booking.status}. Expected ACCEPTED.`,
      );
    }

    const updated = await this.bookingsRepository.markEnRoute(bookingId);

    if (updated.clientProfile?.userId) {
      void this.notificationsService.notify({
        userId: updated.clientProfile.userId,
        eventKey: 'booking.status.en_route',
        title: 'Worker On the Way',
        body: 'Ustaad aap ke ghar ke liye nikal chuka hai.',
        bookingId,
        route: `/client/booking/${bookingId}`,
        actorUserId: userId,
        actorRole: 'WORKER',
        entityType: 'booking',
        entityId: bookingId,
      });
    }

    return this._toDto(updated);
  }

  /** POST /bookings/:id/arrived — EN_ROUTE → ARRIVED. */
  async markArrived(
    userId: string,
    bookingId: string,
  ): Promise<BookingResponseDto> {
    const booking = await this._authorizeAssignedWorker(userId, bookingId);
    if (booking.status !== BookingStatus.EN_ROUTE) {
      throw new BadRequestException(
        `Cannot mark arrived from status ${booking.status}. Expected EN_ROUTE.`,
      );
    }

    const updated = await this.bookingsRepository.markArrived(bookingId);

    if (updated.clientProfile?.userId) {
      void this.notificationsService.notify({
        userId: updated.clientProfile.userId,
        eventKey: 'booking.status.arrived',
        title: 'Worker Arrived',
        body: 'Ustaad location par pohanch gaya hai.',
        bookingId,
        route: `/client/booking/${bookingId}`,
        actorUserId: userId,
        actorRole: 'WORKER',
        entityType: 'booking',
        entityId: bookingId,
      });
    }

    return this._toDto(updated);
  }

  /** POST /bookings/:id/start — ARRIVED → IN_PROGRESS. */
  async startJob(
    userId: string,
    bookingId: string,
  ): Promise<BookingResponseDto> {
    const booking = await this._authorizeAssignedWorker(userId, bookingId);
    if (booking.status !== BookingStatus.ARRIVED) {
      throw new BadRequestException(
        `Cannot start job from status ${booking.status}. Expected ARRIVED.`,
      );
    }

    const updated = await this.bookingsRepository.markInProgress(bookingId);

    if (updated.clientProfile?.userId) {
      void this.notificationsService.notify({
        userId: updated.clientProfile.userId,
        eventKey: 'booking.status.in_progress',
        title: 'Job Started',
        body: 'Aap ka kaam start ho gaya hai.',
        bookingId,
        route: `/client/booking/${bookingId}`,
        actorUserId: userId,
        actorRole: 'WORKER',
        entityType: 'booking',
        entityId: bookingId,
      });
    }

    return this._toDto(updated);
  }

  /**
   * POST /bookings/:id/complete — completes an active job.
   * Backward compatible: accepts ACCEPTED, EN_ROUTE, ARRIVED, or IN_PROGRESS
   * as the starting status (older app builds / the legacy
   * /workers/jobs/:id/complete endpoint could complete directly from
   * ACCEPTED or EN_ROUTE without ever visiting ARRIVED/IN_PROGRESS).
   */
  async completeJob(
    userId: string,
    bookingId: string,
  ): Promise<BookingResponseDto> {
    const booking = await this._authorizeAssignedWorker(userId, bookingId);

    // INSPECTION lane: worker cannot complete without submitting a report,
    // and cannot complete while the client hasn't decided or has already
    // closed the job after inspection (that path completes automatically —
    // see completeAfterInspectionClose). STANDARD/BIDDING are unaffected.
    if (booking.lane === BookingLane.INSPECTION) {
      if (booking.status !== BookingStatus.IN_PROGRESS) {
        throw new BadRequestException(
          'Start the inspection before completing this job.',
        );
      }
      const report = booking.inspectionReport;
      if (!report) {
        throw new BadRequestException(
          'Submit the inspection report before completing this job.',
        );
      }
      if (report.decisionStatus === 'PENDING_CLIENT_DECISION') {
        throw new BadRequestException(
          'Waiting for the client to decide on the inspection report.',
        );
      }
      if (report.decisionStatus === 'CLOSED_AFTER_INSPECTION') {
        throw new BadRequestException(
          'This booking was already closed after inspection.',
        );
      }
      // ACCEPTED_REPAIR falls through to normal completion below.
    }

    const completable: BookingStatus[] = [
      BookingStatus.ACCEPTED,
      BookingStatus.EN_ROUTE,
      BookingStatus.ARRIVED,
      BookingStatus.IN_PROGRESS,
    ];
    if (!completable.includes(booking.status)) {
      throw new BadRequestException(
        `Cannot complete a job with status ${booking.status}`,
      );
    }

    const workerProfile =
      await this.bookingsRepository.findWorkerProfileByUserId(userId);
    const updated = await this.bookingsRepository.completeBookingLifecycle(
      bookingId,
      workerProfile!.id,
    );

    if (updated.clientProfile?.userId) {
      void this.notificationsService.notify({
        userId: updated.clientProfile.userId,
        eventKey: 'booking.completed',
        title: 'Job Completed',
        body: 'Aap ka kaam complete ho gaya hai. Barah-e-karam review dein.',
        bookingId,
        route: `/client/booking/${bookingId}`,
        actorUserId: userId,
        actorRole: 'WORKER',
        entityType: 'booking',
        entityId: bookingId,
      });
    }
    // Also notify the worker so both sides get an in-app banner/push.
    if (updated.workerProfile?.userId) {
      void this.notificationsService.notify({
        userId: updated.workerProfile.userId,
        eventKey: 'booking.completed',
        title: 'Job Completed',
        body: 'Job successfully marked as completed.',
        bookingId,
        route: `/worker/job/${bookingId}`,
        actorUserId: userId,
        actorRole: 'WORKER',
        entityType: 'booking',
        entityId: bookingId,
      });
    }

    return this._toDto(updated);
  }

  /**
   * Completes an INSPECTION booking on the client's behalf when they choose
   * "Close After Inspection" — the final amount is the inspection fee only,
   * no worker action required. Called by InspectionReportsService after it
   * has already authorized the client and validated the report/decision
   * state; this method re-checks lane/status defensively and performs the
   * same completion write + notifications as completeJob.
   */
  async completeAfterInspectionClose(
    bookingId: string,
  ): Promise<BookingResponseDto> {
    const booking = await this.bookingsRepository.findBookingById(bookingId);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.lane !== BookingLane.INSPECTION) {
      throw new BadRequestException(
        'Only INSPECTION bookings can be closed after inspection.',
      );
    }
    if (booking.status !== BookingStatus.IN_PROGRESS) {
      throw new BadRequestException(
        `Cannot close booking with status ${booking.status}. Expected IN_PROGRESS.`,
      );
    }
    if (!booking.workerProfileId) {
      throw new BadRequestException('Booking has no assigned worker.');
    }

    const updated = await this.bookingsRepository.completeBookingLifecycle(
      bookingId,
      booking.workerProfileId,
    );

    if (updated.clientProfile?.userId) {
      void this.notificationsService.notify({
        userId: updated.clientProfile.userId,
        eventKey: 'booking.completed',
        title: 'Job Completed',
        body: 'Inspection close ho gayi hai. Barah-e-karam review dein.',
        bookingId,
        route: `/client/booking/${bookingId}`,
        actorRole: 'CLIENT',
        entityType: 'booking',
        entityId: bookingId,
      });
    }
    if (updated.workerProfile?.userId) {
      void this.notificationsService.notify({
        userId: updated.workerProfile.userId,
        eventKey: 'booking.inspection.closed',
        title: 'Inspection Closed',
        body: 'Client ne inspection ke baad job close kar di hai.',
        bookingId,
        route: `/worker/job/${bookingId}`,
        actorRole: 'CLIENT',
        entityType: 'booking',
        entityId: bookingId,
      });
    }

    return this._toDto(updated);
  }

  /**
   * POST /bookings/:id/worker-cancel — worker cancels before arrival.
   * Only allowed while status is ACCEPTED or EN_ROUTE (i.e. strictly before
   * ARRIVED, per spec — once the page would show "In Progress" the cancel
   * button must already be hidden client-side, and the backend enforces the
   * same rule so a stale client can't bypass it).
   */
  async workerCancelBooking(
    userId: string,
    bookingId: string,
    reason: string,
  ): Promise<BookingResponseDto> {
    const booking = await this._authorizeAssignedWorker(userId, bookingId);
    const cancellable: BookingStatus[] = [
      BookingStatus.ACCEPTED,
      BookingStatus.EN_ROUTE,
    ];
    if (!cancellable.includes(booking.status)) {
      throw new BadRequestException(
        `Cannot cancel a job with status ${booking.status}. Workers may only cancel before arrival.`,
      );
    }

    const workerProfile =
      await this.bookingsRepository.findWorkerProfileByUserId(userId);

    // Booking is live/searching again — restart its 72h expiry window.
    const now = new Date();
    const expiresAt = new Date(now.getTime() + BOOKING_EXPIRY_MS);

    const updated = await this.bookingsRepository.workerCancelBooking(
      bookingId,
      workerProfile!.id,
      reason,
      expiresAt,
      now,
    );

    void this._scheduleExpiry(bookingId, expiresAt).catch((err) => {
      this.logger.warn(
        `[expiry] scheduleExpiry failed for bookingId=${bookingId}: ${(err as Error)?.message}`,
      );
    });

    if (updated.clientProfile?.userId) {
      void this.notificationsService.notify({
        userId: updated.clientProfile.userId,
        eventKey: 'booking.cancelled.by_worker',
        title: 'Worker Cancelled',
        body: 'Ustaad ne job cancel kar di hai. Aap naya Ustaad choose kar sakte hain.',
        bookingId,
        route: `/client/booking/${bookingId}`,
        actorUserId: userId,
        actorRole: 'WORKER',
        entityType: 'booking',
        entityId: bookingId,
      });
    }

    return this._toDto(updated);
  }

  /**
   * PATCH /bookings/:id/relist — client "Make Live Again" on an EXPIRED
   * booking. Resets the 72h window and reschedules the expiry job. Existing
   * worker exclusions are left untouched (kept keyed by bookingId).
   */
  async relistBooking(
    userId: string,
    bookingId: string,
  ): Promise<BookingResponseDto> {
    const profile =
      await this.bookingsRepository.findClientProfileByUserId(userId);
    if (!profile) throw new ForbiddenException('Client profile not found');

    const booking = await this.bookingsRepository.findBookingById(bookingId);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.clientProfileId !== profile.id) {
      throw new ForbiddenException('Not your booking');
    }
    if (booking.status !== BookingStatus.EXPIRED) {
      throw new BadRequestException(
        'Only EXPIRED bookings can be made live again.',
      );
    }

    const now = new Date();
    const expiresAt = new Date(now.getTime() + BOOKING_EXPIRY_MS);
    const updated = await this.bookingsRepository.relistBooking(
      bookingId,
      now,
      expiresAt,
    );

    void this._scheduleExpiry(bookingId, expiresAt).catch((err) => {
      this.logger.warn(
        `[expiry] scheduleExpiry failed for bookingId=${bookingId}: ${(err as Error)?.message}`,
      );
    });

    void this.notificationsService.notify({
      userId,
      eventKey: 'booking.relisted',
      title: 'Job Live Again',
      body: 'Aap ki job dobara live ho gayi hai. Naye Ustaad dekhna shuru karein.',
      bookingId,
      route: `/client/booking/${bookingId}`,
      entityType: 'booking',
      entityId: bookingId,
    });

    return this._toDto(updated);
  }

  // ── Expiry job management ─────────────────────────────────────────────────

  /**
   * Schedule (or reschedule) the 72h auto-expiry BullMQ job for a booking.
   * Mirrors WorkersService._syncAutoOfflineJob: deterministic jobId so a
   * reschedule (relist) simply replaces the existing delayed job.
   */
  private async _scheduleExpiry(
    bookingId: string,
    expiresAt: Date,
  ): Promise<void> {
    const work = async () => {
      const jobId = `expire-${bookingId}`;
      const existing = await this.bookingsQueue.getJob(jobId);
      if (existing) await existing.remove();

      const delay = Math.max(0, expiresAt.getTime() - Date.now());
      const data: ExpireBookingJobData = { bookingId };
      await this.bookingsQueue.add(EXPIRE_BOOKING_JOB, data, {
        jobId,
        delay,
        removeOnComplete: true,
        removeOnFail: false,
      });
      this.logger.log(
        `[expiry] scheduled bookingId=${bookingId} in ${Math.round(delay / 1000 / 60)} min`,
      );
    };

    await this._withQueueTimeout(work(), `scheduleExpiry(${bookingId})`);
  }

  /** Cancel any pending auto-expiry job — call whenever a booking leaves PENDING. */
  private async _cancelExpiry(bookingId: string): Promise<void> {
    const work = async () => {
      const jobId = `expire-${bookingId}`;
      const existing = await this.bookingsQueue.getJob(jobId);
      if (existing) {
        await existing.remove();
        this.logger.log(`[expiry] cancelled bookingId=${bookingId}`);
      }
    };

    await this._withQueueTimeout(work(), `cancelExpiry(${bookingId})`);
  }

  /**
   * Race a Bull/Redis queue operation against a short timeout so a slow or
   * hung queue can never block the HTTP response. Callers treat both queue
   * errors and timeouts as best-effort failures (log a warning, never throw
   * back to the request).
   */
  private _withQueueTimeout<T>(promise: Promise<T>, label: string): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new Error(`${label} timed out after ${EXPIRY_QUEUE_TIMEOUT_MS}ms`));
      }, EXPIRY_QUEUE_TIMEOUT_MS);

      promise
        .then((value) => {
          clearTimeout(timer);
          resolve(value);
        })
        .catch((err) => {
          clearTimeout(timer);
          reject(err);
        });
    });
  }

  // ── Worker-listed notification (STANDARD lane) ────────────────────────────

  /**
   * Notify each worker returned by a STANDARD-lane nearby-workers search that
   * they've been suggested to a client, with push + in-app banner. Deduped
   * per booking/worker pair via the notifications table so repeated polling
   * of the nearby-workers endpoint never spams the same worker twice for the
   * same booking. Never throws — fire-and-forget from the caller.
   */
  private async _notifyWorkersListedForStandardJob(
    bookingId: string,
    workers: NearbyWorkerDto[],
  ): Promise<void> {
    if (workers.length === 0) return;
    try {
      const userIdByWorkerId =
        await this.bookingsRepository.findUserIdsByWorkerProfileIds(
          workers.map((w) => w.id),
        );

      const eventKey = 'booking.standard.worker_listed';
      for (const w of workers) {
        const userId = userIdByWorkerId.get(w.id);
        if (!userId) continue;

        const alreadyNotified = await this.notificationsService.wasAlreadyNotified(
          userId,
          bookingId,
          eventKey,
        );
        if (alreadyNotified) continue;

        void this.notificationsService.notify({
          userId,
          eventKey,
          title: 'New Standard Job',
          body: 'Aap ko ek Standard job ke liye client ko suggest kiya ja raha hai.',
          bookingId,
          route: `/worker/jobs/${bookingId}`,
          entityType: 'booking',
          entityId: bookingId,
        });
      }
    } catch (err) {
      this.logger.warn(
        `[worker-listed] notify failed for bookingId=${bookingId}: ${(err as Error)?.message}`,
      );
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  private _resolveAttachmentType(mimeType: string): AttachmentType {
    if (mimeType.startsWith('image/')) return AttachmentType.IMAGE;
    if (mimeType.startsWith('video/')) return AttachmentType.VIDEO;
    if (mimeType.startsWith('audio/')) return AttachmentType.AUDIO;
    throw new BadRequestException(
      `Unsupported file type: ${mimeType}. Allowed: image, video, or audio.`,
    );
  }

  private _attachmentFolder(bookingId: string, type: AttachmentType): string {
    const sub =
      type === AttachmentType.IMAGE
        ? 'images'
        : type === AttachmentType.VIDEO
          ? 'videos'
          : 'voice';
    return `uploads/bookings/${bookingId}/${sub}`;
  }

  private _toDto(booking: BookingWithRelations): BookingResponseDto {
    const wp = booking.workerProfile;
    const worker: WorkerSummaryDto | null = wp
      ? {
          id: wp.id,
          firstName: wp.firstName,
          lastName: wp.lastName,
          rating: wp.rating,
          avatarUrl: wp.avatarUrl,
          currentLat: wp.currentLat ?? null,
          currentLng: wp.currentLng ?? null,
          phone: wp.user.phone,
        }
      : null;

    const acceptedBidAmount = booking.bids[0]
      ? Number(booking.bids[0].amount)
      : null;

    const rv = booking.review;
    const review: BookingReviewDto | null = rv
      ? {
          id: rv.id,
          rating: rv.rating,
          comment: rv.comment ?? null,
          createdAt: rv.createdAt.toISOString(),
        }
      : null;

    const attachments: BookingAttachmentDto[] = booking.attachments.map(
      (a) => ({
        id: a.id,
        type: a.type,
        url: a.url,
        storageKey: a.storageKey ?? null,
        fileName: a.fileName ?? null,
        mimeType: a.mimeType ?? null,
        sizeBytes: a.sizeBytes ?? null,
        durationSeconds: a.durationSeconds ?? null,
        thumbnailUrl: a.thumbnailUrl ?? null,
        createdAt: a.createdAt.toISOString(),
      }),
    );

    const standardServiceItems = booking.standardServiceItems.map((item) => ({
      id: item.id,
      standardServiceId: item.standardServiceId ?? null,
      nameSnapshot: item.nameSnapshot,
      priceSnapshot: item.priceSnapshot,
      quantity: item.quantity,
    }));

    const workerExclusions = booking.workerExclusions.map((e) => ({
      workerProfileId: e.workerProfileId,
      reason: e.reason ?? null,
      createdAt: e.createdAt.toISOString(),
    }));

    // Most recent exclusion reason — drives the client's "Previous Ustaad
    // cancelled: [reason]" strip while the booking is back in choose-worker state.
    const lastWorkerCancellationReason = workerExclusions[0]?.reason ?? null;

    return {
      id: booking.id,
      serviceCategory: booking.category.name,
      title: booking.title ?? null,
      description: booking.description,
      status: booking.status,
      urgency: booking.urgency,
      timeSlot: booking.timeSlot ?? null,
      urgentWindow: booking.urgentWindow ?? null,
      scheduledDate: booking.scheduledAt?.toISOString() ?? null,
      createdAt: booking.createdAt.toISOString(),
      inspection: booking.inspection,
      lane: booking.lane,
      standardServiceId: booking.standardServiceId ?? null,
      standardServiceNameSnapshot: booking.standardServiceNameSnapshot ?? null,
      standardServicePriceSnapshot:
        booking.standardServicePriceSnapshot ?? null,
      standardServiceItems,
      inspectionFeeSnapshot: booking.inspectionFeeSnapshot ?? null,
      estimatedPrice: booking.estimatedPrice ?? null,
      finalPrice: booking.finalPrice ?? null,
      address: booking.addressLine,
      city: booking.city,
      latitude: booking.latitude,
      longitude: booking.longitude,
      acceptedAt: booking.acceptedAt?.toISOString() ?? null,
      enRouteAt: booking.enRouteAt?.toISOString() ?? null,
      arrivedAt: booking.arrivedAt?.toISOString() ?? null,
      startedAt: booking.startedAt?.toISOString() ?? null,
      completedAt: booking.completedAt?.toISOString() ?? null,
      cancellationReason: booking.cancellationReason ?? null,
      cancelledByRole: (booking.cancelledByRole as 'CLIENT' | 'WORKER' | null) ?? null,
      expiresAt: booking.expiresAt?.toISOString() ?? null,
      liveStartedAt: booking.liveStartedAt?.toISOString() ?? null,
      relistedAt: booking.relistedAt?.toISOString() ?? null,
      worker,
      availableWorkersCount: null,
      attachments,
      review,
      acceptedBidAmount,
      workerExclusions,
      lastWorkerCancellationReason,
      inspectionReportSubmitted: booking.inspectionReport != null,
      inspectionDecisionStatus: booking.inspectionReport?.decisionStatus ?? null,
      inspectionReportSubmittedAt:
        booking.inspectionReport?.createdAt.toISOString() ?? null,
    };
  }
}
