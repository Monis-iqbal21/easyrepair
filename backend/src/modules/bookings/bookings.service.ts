import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
  Logger,
  Inject,
  forwardRef,
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
import { WorkerUnavailableError } from '../../common/errors/worker-unavailable.error';
import { WORKER_PRESENCE_STALE_MS } from '../../common/utils/job-eligibility.util';
import { isAttachableDecisionStatus } from '../../common/utils/attachable-inspection.util';
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
import { calculatePlatformFee } from '../../common/utils/commission.util';
import { deriveInspectionFeePaid } from '../../common/utils/inspection-fee.util';
import { JobBroadcastService } from '../matching/job-broadcast.service';
import { JobCompletionNotifierService } from '../matching/job-completion-notifier.service';

/** 72 hours in milliseconds â€” auto-expiry window for PENDING bookings, all lanes. */
const BOOKING_EXPIRY_MS = 72 * 60 * 60 * 1000;

/** Max time to wait on the Bull/Redis queue before giving up â€” expiry scheduling must never hang the request. */
const EXPIRY_QUEUE_TIMEOUT_MS = 1800;

@Injectable()
export class BookingsService {
  private readonly logger = new Logger(BookingsService.name);

  constructor(
    private readonly bookingsRepository: BookingsRepository,
    private readonly storageService: StorageService,
    private readonly notificationsService: NotificationsService,
    @Inject(forwardRef(() => ChatService))
    private readonly chatService: ChatService,
    @InjectQueue(BOOKINGS_QUEUE) private readonly bookingsQueue: Queue,
    // Both live in the leaf MatchingModule so WorkersService can share them
    // without the two services importing each other.
    private readonly jobBroadcastService: JobBroadcastService,
    private readonly jobCompletionNotifier: JobCompletionNotifierService,
  ) {}

  /**
   * Validates an optional client-supplied `attachedInspectionBookingId` and
   * returns the id to persist (or undefined when none was requested).
   *
   * The client-supplied id is NEVER trusted: every rule below is re-checked
   * against the database. "Doesn't exist" and "belongs to a different client"
   * deliberately raise the SAME error, so this can't be used to probe which
   * booking ids exist.
   *
   * This is a pure read + validate step — it never writes to, reopens, or
   * otherwise touches the historical inspection booking or its report, which
   * stay exactly as the original (already closed and paid) transaction left
   * them. The resulting reference is informational only; see the schema doc
   * on Booking.attachedInspectionBookingId for why it is deliberately not
   * sourceInspectionBookingId.
   */
  private async _resolveAttachedInspection(params: {
    requested?: string;
    clientProfileId: string;
    categoryId: string;
    lane: BookingLane;
  }): Promise<string | undefined> {
    if (!params.requested) return undefined;

    // Attaching context only makes sense for an open marketplace job. The
    // STANDARD/INSPECTION lanes are direct-assign and have no bidders to
    // inform.
    if (params.lane !== BookingLane.BIDDING) {
      throw new BadRequestException(
        'An inspection report can only be attached to a bidding job.',
      );
    }

    const notAttachable = new BadRequestException(
      'That inspection report is not available to attach.',
    );

    const source = await this.bookingsRepository.findInspectionForAttachment(
      params.requested,
    );
    if (!source) throw notAttachable;
    // Ownership — the single most important check here.
    if (source.clientProfileId !== params.clientProfileId) throw notAttachable;
    if (source.lane !== BookingLane.INSPECTION) throw notAttachable;
    if (source.status !== BookingStatus.COMPLETED) throw notAttachable;
    // A report must actually have been submitted — never a draft/never-filled
    // inspection.
    if (!source.inspectionReport) throw notAttachable;
    if (!isAttachableDecisionStatus(source.inspectionReport.decisionStatus)) {
      throw notAttachable;
    }
    if (source.categoryId !== params.categoryId) {
      throw new BadRequestException(
        'The attached inspection report is for a different service.',
      );
    }

    return source.id;
  }

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

    // Retry of the same submission attempt (network timeout, lost response)
    // reuses the same idempotencyKey — short-circuit before re-running any
    // validation/lookups and return the already-created booking as-is,
    // rather than creating a second identical booking.
    if (dto.idempotencyKey) {
      const existing = await this.bookingsRepository.findBookingByIdempotencyKey(
        dto.idempotencyKey,
      );
      if (existing) {
        if (existing.clientProfileId !== profile.id) {
          throw new ForbiddenException('Client profile not found');
        }
        this.logger.log(
          `[createBooking] idempotent replay bookingId=${existing.id} idempotencyKey=${dto.idempotencyKey}`,
        );
        return this._toDto(existing);
      }
    }

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

    // Reject missing or zero coordinates â€” every booking must have a real location.
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

    // Only meaningful for URGENT bookings â€” ignore any urgentWindow sent
    // alongside a NORMAL booking so stored data never contradicts urgency.
    const urgentWindow: UrgentWindow | undefined =
      dto.urgency === BookingUrgency.URGENT ? dto.urgentWindow : undefined;

    // Lane defaults to BIDDING when omitted â€” older app builds that don't
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
      if (
        category.inspectionFee === null ||
        category.inspectionFee === undefined
      ) {
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

    // Optional read-only historical inspection report attached by the client.
    // Fully validated server-side before the booking row is written; never
    // reads or mutates the historical inspection itself.
    const attachedInspectionBookingId = await this._resolveAttachedInspection({
      requested: dto.attachedInspectionBookingId,
      clientProfileId: profile.id,
      categoryId: category.id,
      lane,
    });

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
      idempotencyKey: dto.idempotencyKey,
      attachedInspectionBookingId,
    });

    this.logger.log(
      `[createBooking] created bookingId=${booking.id} lane=${lane}`,
    );

    // Fire-and-forget: expiry scheduling talks to Redis/Bull and must never
    // block or fail the booking-creation response.
    void this._scheduleExpiry(booking.id, expiresAt).catch((err) => {
      this.logger.warn(
        `[expiry] scheduleExpiry failed for bookingId=${booking.id}: ${(err as Error)?.message}`,
      );
    });

    // Every lane broadcasts the moment the job goes live, so nearby eligible
    // Ustaads learn about it without polling. Per-live-cycle dedup makes a
    // later re-broadcast (e.g. the STANDARD discovery screen) a no-op.
    void this.jobBroadcastService.broadcastJob(booking.id);

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

  /**
   * GET /bookings/pending-reviews â€” completed work units awaiting this
   * client's review, newest first. The app treats this as authoritative:
   * a booking is only dropped from its review queue once it stops appearing
   * here, so a dismissed, failed or missed prompt is always re-offered.
   */
  async getPendingReviews(userId: string): Promise<BookingResponseDto[]> {
    const profile =
      await this.bookingsRepository.findClientProfileByUserId(userId);
    if (!profile) throw new ForbiddenException('Client profile not found');

    const bookings =
      await this.bookingsRepository.findPendingReviewBookingsByClientProfileId(
        profile.id,
      );
    return bookings.map((b) => this._toDto(b));
  }

  async cancelBooking(
    userId: string,
    bookingId: string,
    reason: string,
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

    // Client can cancel up through ACCEPTED (worker hired but not yet on the
    // way). Once the worker marks EN_ROUTE or later, the client can no
    // longer cancel â€” matches BookingEntity.canClientCancel on the Flutter side.
    const clientCancellableStatuses: BookingStatus[] = [
      BookingStatus.PENDING,
      BookingStatus.ACCEPTED,
    ];

    // A retry of an already-successful cancel (client's first response was
    // lost, or a double-tap raced past the disabled button) lands here with
    // the booking already CANCELLED. That is exactly the outcome the caller
    // wanted, so return the current state as success instead of a conflict
    // error, and skip re-running the expiry-cancel / notification below.
    if (booking.status === BookingStatus.CANCELLED) {
      return this._toDto(booking);
    }

    if (!clientCancellableStatuses.includes(booking.status)) {
      throw new BadRequestException(
        `Cannot cancel a booking with status ${booking.status}. Cancellation is only allowed before the worker is on the way.`,
      );
    }

    const { booking: updated, changed } =
      await this.bookingsRepository.cancelBooking(
        bookingId,
        clientCancellableStatuses,
        reason,
        booking.workerProfile?.id ?? null,
        'CLIENT',
      );

    if (!changed) {
      // Lost the race to a concurrent request on the same booking. If the
      // winner also cancelled it, this is a safe idempotent retry outcome;
      // any other status is a genuine conflict.
      if (updated.status === BookingStatus.CANCELLED) {
        return this._toDto(updated);
      }
      throw new BadRequestException(
        `Cannot cancel a booking with status ${updated.status}. Cancellation is only allowed before the worker is on the way.`,
      );
    }

    // Booking is no longer PENDING â€” cancel its auto-expiry job. Fire-and-forget.
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
        title: 'Kaam cancel ho gaya',
        body: `Client ne cancel kar diya: ${reason}`,
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

    // Only meaningful for URGENT bookings â€” if the effective urgency is/becomes
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

    // Notify worker of the new review â€” Roman Urdu, all lanes. Uses the
    // client's name when available, falling back to a generic term rather
    // than ever showing a blank/undefined name.
    if (updated.workerProfile?.userId) {
      const clientName = [profile.firstName, profile.lastName]
        .filter((n) => n && n.trim().length > 0)
        .join(' ')
        .trim();
      const clientLabel = clientName.length > 0 ? clientName : 'Client';
      void this.notificationsService.notify({
        userId: updated.workerProfile.userId,
        eventKey: 'booking.review.created',
        title: 'Aapko naya review mila hai',
        body: `${clientLabel} ne aapke kaam ka review diya hai. App mein check karein.`,
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

  // â”€â”€ Attachment endpoints â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
      durationSeconds: Number.isFinite(durationSeconds)
        ? durationSeconds
        : undefined,
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

  // â”€â”€ Nearby workers + assignment â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
    if (booking.inspectionReport?.decisionStatus === 'FIND_OTHER_USTAAD') {
      throw new BadRequestException(
        'This job is open for bidding from other Ustaads. Use the bidding flow instead.',
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

    // Re-broadcast while the client is on the discovery screen. Per-live-cycle
    // dedup means this is a no-op for anyone already notified at creation; it
    // exists so a worker who only just became eligible is still reached.
    // Fire-and-forget â€” must never block the response.
    void this.jobBroadcastService.broadcastJob(bookingId);

    return {
      workers: workerDtos,
      searchedRadiusKm,
      totalFound: workerDtos.length,
      searchCompleted,
    };
  }

  /**
   * Single shared source of truth for "may this client open a chat with
   * this worker, in the context of this booking" â€” reused by ChatService
   * for both pre-assignment (available-worker list) and post-completion
   * chat, replacing what used to be several inconsistent/absent checks.
   *
   * A client may chat with a worker for a booking they own when the worker
   * is any of:
   *   1. The currently (or formerly â€” cancellation/completion never clears
   *      this field) assigned worker.
   *   2. The original INSPECTION-lane inspector â€” preserved permanently even
   *      after a different worker is later hired for the repair.
   *   3. A genuinely eligible candidate for a still-open (PENDING) booking:
   *      a bidder (BIDDING lane, or a reopened "Find Other Ustaad" job), or
   *      a worker present in the nearby-worker result (STANDARD/ordinary
   *      INSPECTION) â€” i.e. exactly the set already shown to the client,
   *      never an arbitrary worker id.
   *
   * Throws NotFoundException / ForbiddenException when disallowed.
   */
  async assertClientCanChatWithWorker(
    clientUserId: string,
    bookingId: string,
    workerProfileId: string,
  ): Promise<void> {
    const booking = await this.bookingsRepository.findBookingById(bookingId);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.clientProfile?.userId !== clientUserId) {
      throw new ForbiddenException('Not your booking');
    }

    if (booking.workerProfileId === workerProfileId) return;
    if (booking.inspectionReport?.workerProfile?.id === workerProfileId) {
      return;
    }

    if (booking.status === BookingStatus.PENDING) {
      const isFindOtherUstaadOpen =
        booking.inspectionReport?.decisionStatus === 'FIND_OTHER_USTAAD';
      if (booking.lane === BookingLane.BIDDING || isFindOtherUstaadOpen) {
        const hasBid = await this.bookingsRepository.hasBidFromWorker(
          bookingId,
          workerProfileId,
        );
        if (hasBid) return;
      } else {
        const excludedWorkerIds = booking.workerExclusions.map(
          (e) => e.workerProfileId,
        );
        // Membership test only — the ids variant runs the identical search
        // and ladder but skips the per-worker stats/ranking this check never
        // reads. See BookingsRepository.findNearbyWorkerIds.
        const nearbyIds = await this.bookingsRepository.findNearbyWorkerIds({
          categoryId: booking.categoryId,
          lat: booking.latitude,
          lng: booking.longitude,
          lane: booking.lane,
          excludedWorkerIds,
        });
        if (nearbyIds.has(workerProfileId)) return;
      }
    }

    throw new ForbiddenException(
      'You are not allowed to chat with this worker for this booking.',
    );
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

    // Retry of an already-successful hire to this same worker (lost
    // response, double-tap that raced the disabled button) — return the
    // current booking as success instead of a conflict.
    if (booking.workerProfileId === workerProfileId) {
      return this._toDto(booking);
    }
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
    if (booking.inspectionReport?.decisionStatus === 'FIND_OTHER_USTAAD') {
      throw new BadRequestException(
        'This job is open for bidding from other Ustaads. Use the bidding flow instead.',
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

    if (
      booking.workerExclusions.some(
        (e) => e.workerProfileId === workerProfileId,
      )
    ) {
      throw new BadRequestException(
        'This Ustaad is not eligible for this booking.',
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
    // Presence lease recheck: the worker may have gone stale (abandoned
    // app / logged out elsewhere) between browsing the nearby-worker list
    // and confirming the hire — same rule the matching-time eligibility
    // gate applies everywhere else. Independent of location freshness.
    if (
      !worker.lastSeenAt ||
      Date.now() - worker.lastSeenAt.getTime() > WORKER_PRESENCE_STALE_MS
    ) {
      throw new BadRequestException(
        'This worker is no longer available. Please choose another.',
      );
    }
    if (!worker.profileCompleted || worker.onboardingStatus !== 'APPROVED') {
      throw new BadRequestException(
        'This worker has not completed their profile yet and cannot be hired.',
      );
    }
    // Common (non-race) case: worker visibly already busy â€” give the
    // friendly message immediately rather than waiting for the transactional
    // guard below (which remains the authoritative check for genuine races).
    if (worker.currentlyWorking) {
      throw new ConflictException(
        'This Ustaad just got another job. Please choose another Ustaad.',
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
          : (booking.standardServicePriceSnapshot ?? undefined)
        : (booking.inspectionFeeSnapshot ?? undefined);

    // Commission is computed on this same amount at assignment time â€” for
    // STANDARD it's the final labour/service total; for INSPECTION it's the
    // visit fee (only overwritten later if the customer accepts a repair
    // quote, see setInspectionRepairPrice).
    const platformFee =
      finalPrice !== undefined ? calculatePlatformFee(finalPrice) : undefined;

    let updated: BookingWithRelations;
    let changed: boolean;
    try {
      ({ booking: updated, changed } =
        await this.bookingsRepository.assignWorkerToBooking(
          bookingId,
          workerProfileId,
          finalPrice,
          platformFee,
        ));
    } catch (err) {
      if (err instanceof WorkerUnavailableError) {
        throw new ConflictException(
          'This Ustaad just got another job. Please choose another Ustaad.',
        );
      }
      throw err;
    }
    if (!changed) {
      // Lost the race to a concurrent assign/acceptBid on the same booking.
      if (updated.workerProfileId === workerProfileId) {
        return this._toDto(updated);
      }
      throw new ConflictException(
        'This booking already has an assigned worker.',
      );
    }

    // Booking is no longer PENDING â€” cancel its auto-expiry job. Fire-and-forget.
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
          : 'Aapko ek naya kaam assign hua hai. Details app mein check karein.';
      void this.notificationsService.notify({
        userId: worker.userId,
        eventKey: 'booking.assigned',
        title: 'Naya kaam assign hua hai',
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

  // â”€â”€ Lifecycle endpoints (assigned worker only) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /** Resolve and authorize: booking exists, caller is the assigned worker. */
  private async _authorizeAssignedWorker(
    userId: string,
    bookingId: string,
  ): Promise<BookingWithRelations> {
    const workerProfile =
      await this.bookingsRepository.findWorkerProfileByUserId(userId);
    if (!workerProfile)
      throw new ForbiddenException('Worker profile not found');

    const booking = await this.bookingsRepository.findBookingById(bookingId);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.workerProfileId !== workerProfile.id) {
      throw new ForbiddenException('You are not assigned to this booking');
    }
    return booking;
  }

  /** POST /bookings/:id/on-my-way â€” ACCEPTED â†’ EN_ROUTE. */
  async markOnMyWay(
    userId: string,
    bookingId: string,
  ): Promise<BookingResponseDto> {
    const booking = await this._authorizeAssignedWorker(userId, bookingId);

    // Retry of an already-successful transition (lost response, double-tap
    // that raced the disabled button) — return current state, no duplicate
    // history row or notification.
    if (booking.status === BookingStatus.EN_ROUTE) {
      return this._toDto(booking);
    }
    if (booking.status !== BookingStatus.ACCEPTED) {
      throw new BadRequestException(
        `Cannot mark on-the-way from status ${booking.status}. Expected ACCEPTED.`,
      );
    }

    const { booking: updated, changed } =
      await this.bookingsRepository.markEnRoute(bookingId);
    if (!changed) {
      if (updated.status === BookingStatus.EN_ROUTE) {
        return this._toDto(updated);
      }
      throw new BadRequestException(
        `Cannot mark on-the-way from status ${updated.status}. Expected ACCEPTED.`,
      );
    }

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

  /** POST /bookings/:id/arrived â€” EN_ROUTE â†’ ARRIVED. */
  async markArrived(
    userId: string,
    bookingId: string,
  ): Promise<BookingResponseDto> {
    const booking = await this._authorizeAssignedWorker(userId, bookingId);

    if (booking.status === BookingStatus.ARRIVED) {
      return this._toDto(booking);
    }
    if (booking.status !== BookingStatus.EN_ROUTE) {
      throw new BadRequestException(
        `Cannot mark arrived from status ${booking.status}. Expected EN_ROUTE.`,
      );
    }

    const { booking: updated, changed } =
      await this.bookingsRepository.markArrived(bookingId);
    if (!changed) {
      if (updated.status === BookingStatus.ARRIVED) {
        return this._toDto(updated);
      }
      throw new BadRequestException(
        `Cannot mark arrived from status ${updated.status}. Expected EN_ROUTE.`,
      );
    }

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

  /** POST /bookings/:id/start â€” ARRIVED â†’ IN_PROGRESS. */
  async startJob(
    userId: string,
    bookingId: string,
  ): Promise<BookingResponseDto> {
    const booking = await this._authorizeAssignedWorker(userId, bookingId);

    if (booking.status === BookingStatus.IN_PROGRESS) {
      return this._toDto(booking);
    }
    if (booking.status !== BookingStatus.ARRIVED) {
      throw new BadRequestException(
        `Cannot start job from status ${booking.status}. Expected ARRIVED.`,
      );
    }

    const { booking: updated, changed } =
      await this.bookingsRepository.markInProgress(bookingId);
    if (!changed) {
      if (updated.status === BookingStatus.IN_PROGRESS) {
        return this._toDto(updated);
      }
      throw new BadRequestException(
        `Cannot start job from status ${updated.status}. Expected ARRIVED.`,
      );
    }

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
   * POST /bookings/:id/complete â€” completes an active job.
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

    // Retry of an already-successful completion (lost response, double-tap
    // that raced the disabled button, or the sibling legacy
    // /workers/jobs/:id/complete endpoint already completed it) — return
    // current state, no duplicate earnings/commission recompute or
    // notification.
    if (booking.status === BookingStatus.COMPLETED) {
      return this._toDto(booking);
    }

    // INSPECTION lane: worker cannot complete without submitting a report,
    // and cannot complete while the client hasn't decided or has already
    // closed the job after inspection (that path completes automatically â€”
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
      // ACCEPTED_REPAIR (rehired inspector) and FIND_OTHER_USTAAD (a
      // different repair worker hired via bidding â€” see acceptBid, which
      // never touches decisionStatus, so it stays FIND_OTHER_USTAAD for the
      // rest of this booking's lifecycle) both fall through to normal
      // completion below â€” the assigned-worker check above already ensures
      // only whoever is actually hired right now can complete it.
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
    const { booking: updated, changed } =
      await this.bookingsRepository.completeBookingLifecycle(
        bookingId,
        workerProfile!.id,
        completable,
      );
    if (!changed) {
      if (updated.status === BookingStatus.COMPLETED) {
        return this._toDto(updated);
      }
      throw new BadRequestException(
        `Cannot complete a job with status ${updated.status}`,
      );
    }

    // Single shared, deduplicated completion notice â€” see
    // JobCompletionNotifierService. Every completion path routes here so the
    // client can only ever receive one `booking.completed` per work unit.
    void this.jobCompletionNotifier.notifyClientJobCompleted(
      bookingId,
      'NORMAL',
      { userId, role: 'WORKER' },
    );

    // The worker's own confirmation is a different audience and stays inline.
    if (updated.workerProfile?.userId) {
      void this.notificationsService.notify({
        userId: updated.workerProfile.userId,
        eventKey: 'booking.completed',
        title: 'Kaam complete ho gaya',
        body: 'Booking complete mark ho gayi hai.',
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
   * "Close After Inspection" â€” the final amount is the inspection fee only,
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
    if (booking.status === BookingStatus.COMPLETED) {
      return this._toDto(booking);
    }
    if (booking.status !== BookingStatus.IN_PROGRESS) {
      throw new BadRequestException(
        `Cannot close booking with status ${booking.status}. Expected IN_PROGRESS.`,
      );
    }
    if (!booking.workerProfileId) {
      throw new BadRequestException('Booking has no assigned worker.');
    }

    const { booking: updated, changed } =
      await this.bookingsRepository.completeBookingLifecycle(
        bookingId,
        booking.workerProfileId,
        [BookingStatus.IN_PROGRESS],
      );
    if (!changed) {
      if (updated.status === BookingStatus.COMPLETED) {
        return this._toDto(updated);
      }
      throw new BadRequestException(
        `Cannot close booking with status ${updated.status}. Expected IN_PROGRESS.`,
      );
    }

    void this.jobCompletionNotifier.notifyClientJobCompleted(
      bookingId,
      'NORMAL',
      { role: 'CLIENT' },
    );
    if (updated.workerProfile?.userId) {
      void this.notificationsService.notify({
        userId: updated.workerProfile.userId,
        eventKey: 'booking.inspection.closed',
        title: 'Inspection band ho gayi',
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
   * INSPECTION lane, third outcome ("Find Other Ustaad"): atomically marks
   * the report FIND_OTHER_USTAAD, completes the original inspection booking
   * (kept forever on the inspector for stats/earnings/My Jobs), releases the
   * inspector, and spawns a new linked BIDDING-lane child booking for the
   * repair. Idempotent: a retry/double-tap resolves to the already-created
   * child booking and returns the same id as a success â€” notification
   * delivery is re-attempted on that path too (the per-worker
   * wasAlreadyNotified dedup guard prevents duplicates).
   *
   * Returns the linked repair booking's id.
   */
  async closeInspectionAndOpenRepairBidding(params: {
    reportId: string;
    originalBookingId: string;
    inspectingWorkerProfileId: string;
    clientProfileId: string;
    categoryId: string;
    title: string | null;
    description: string;
    addressLine: string;
    city: string;
    latitude: number;
    longitude: number;
  }): Promise<string> {
    const now = new Date();
    const expiresAt = new Date(now.getTime() + BOOKING_EXPIRY_MS);

    const result =
      await this.bookingsRepository.closeInspectionAndOpenRepairBidding({
        ...params,
        now,
        expiresAt,
      });

    switch (result.outcome) {
      case 'CREATED': {
        const childId = result.childBooking.id;
        void this._scheduleExpiry(childId, expiresAt).catch((err) => {
          this.logger.warn(
            `[expiry] scheduleExpiry failed for bookingId=${childId}: ${(err as Error)?.message}`,
          );
        });
        void this.jobBroadcastService.broadcastJob(childId);
        // The client's inspection work unit is now complete â€” prompt them to
        // review the ORIGINAL inspecting Ustaad (never the child booking).
        void this.jobCompletionNotifier.notifyClientJobCompleted(
          params.originalBookingId,
          'INSPECTION_BEFORE_SWITCH',
          { role: 'CLIENT' },
        );
        return childId;
      }
      case 'ALREADY_DONE': {
        // Idempotent replay â€” re-attempt delivery in case the first request
        // died after commit; per-cycle dedup guarantees no worker is pushed
        // twice for the same live cycle.
        const childId = result.childBooking.id;
        void this.jobBroadcastService.broadcastJob(childId);
        void this.jobCompletionNotifier.notifyClientJobCompleted(
          params.originalBookingId,
          'INSPECTION_BEFORE_SWITCH',
          { role: 'CLIENT' },
        );
        return childId;
      }
      case 'CONFLICTING_DECISION':
        throw new BadRequestException(
          `This report has already been decided (${result.decisionStatus}).`,
        );
      case 'LINK_MISSING':
        throw new ConflictException({
          message:
            'This inspection was already closed but its repair job could not be found. Please contact support.',
          error: 'INSPECTION_LINK_MISSING',
        });
      case 'BOOKING_STATE_CHANGED':
        throw new ConflictException(
          'This inspection booking is no longer in progress, so it cannot be closed for bidding.',
        );
    }
  }

  /**
   * INSPECTION lane, third outcome: customer re-hires the original
   * inspecting worker after having pressed "Find Other Ustaad". Reuses the
   * exact same labour-only commission math as a normal accepted quote.
   * Double-hire-safe (atomic conditional update in the repository); throws
   * ConflictException if the job was already hired to someone else in the
   * meantime, or if the inspecting worker is no longer eligible/online.
   */
  async rehireInspectingWorker(
    userId: string,
    bookingId: string,
    workerProfileId: string,
    repairQuoteTotal: number,
    labourCost: number,
  ): Promise<BookingResponseDto> {
    // Re-check availability at this exact moment. "Busy on another job" gets
    // its own controlled error code so the client app can show the specific
    // Roman Urdu message and keep the bidding list open; every other
    // unavailability reason keeps the existing generic conflict below.
    const inspector =
      await this.bookingsRepository.findWorkerProfileById(workerProfileId);
    if (inspector?.currentlyWorking) {
      throw new ConflictException({
        message:
          'Inspection karne wala Ustaad abhi doosre kaam mein masroof hai. Neeche se koi aur Ustaad choose karein.',
        error: 'INSPECTOR_BUSY',
      });
    }

    const platformFee = calculatePlatformFee(labourCost);

    let updated: BookingWithRelations;
    try {
      updated = await this.bookingsRepository.rehireInspectingWorker(
        bookingId,
        workerProfileId,
        repairQuoteTotal,
        platformFee,
      );
    } catch (err) {
      if (err instanceof WorkerUnavailableError) {
        throw new ConflictException(
          'This Ustaad is no longer available. Please choose another option.',
        );
      }
      throw err;
    }

    if (updated.workerProfile?.userId) {
      void this.notificationsService.notify({
        userId: updated.workerProfile.userId,
        eventKey: 'booking.assigned',
        title: 'Naya kaam assign hua hai',
        body: 'Aapko dobara hire kar liya gaya hai. Details app mein check karein.',
        bookingId,
        route: `/worker/job/${bookingId}`,
        actorUserId: userId,
        actorRole: 'CLIENT',
        entityType: 'booking',
        entityId: bookingId,
      });
      void this.chatService.ensureConversationForBooking(
        userId,
        updated.workerProfile.userId,
      );
    }

    return this._toDto(updated);
  }

  /**
   * POST /bookings/:id/worker-cancel â€” worker cancels an assigned job.
   * Allowed only while status is ACCEPTED, EN_ROUTE, or ARRIVED â€” once
   * IN_PROGRESS (work/inspection actually started), cancellation is no
   * longer available for any lane. Terminally cancels the booking (status
   * CANCELLED) rather than returning it to PENDING â€” it must never silently
   * reappear in New Jobs for another worker to pick up; the client
   * separately triggers reopening (see reopenAfterWorkerCancellation).
   */
  async workerCancelBooking(
    userId: string,
    bookingId: string,
    reason: string,
  ): Promise<BookingResponseDto> {
    const booking = await this._authorizeAssignedWorker(userId, bookingId);
    // Matches BookingEntity.canWorkerCancel on Flutter.
    const cancellable: BookingStatus[] = [
      BookingStatus.ACCEPTED,
      BookingStatus.EN_ROUTE,
      BookingStatus.ARRIVED,
    ];
    if (!cancellable.includes(booking.status)) {
      throw new BadRequestException(
        `Cannot cancel a job with status ${booking.status}.`,
      );
    }

    const workerProfile =
      await this.bookingsRepository.findWorkerProfileByUserId(userId);

    const updated = await this.bookingsRepository.workerCancelBooking(
      bookingId,
      workerProfile!.id,
      reason,
    );

    if (updated.clientProfile?.userId) {
      void this.notificationsService.notify({
        userId: updated.clientProfile.userId,
        eventKey: 'booking.cancelled.by_worker',
        title: 'Kaam Cancel Ho Gaya',
        body: `Ustaad ne kaam cancel kar diya: ${reason}`,
        bookingId,
        route: `/client/booking/${bookingId}`,
        actorUserId: userId,
        actorRole: 'WORKER',
        entityType: 'booking',
        entityId: bookingId,
      });
    }

    // Cancelling released this worker's `currentlyWorking` flag â€” they are
    // free again, so surface any still-open nearby job to them now.
    if (workerProfile?.id) {
      void this.jobBroadcastService.matchOpenJobsForWorker(workerProfile.id, {
        bypassCooldown: true,
      });
    }

    return this._toDto(updated);
  }

  /**
   * POST /bookings/:id/reopen-after-cancellation â€” client action, taken
   * after a worker-cancelled booking, to find/hire another worker for the
   * same booking. Only valid while status is CANCELLED with
   * cancelledByRole WORKER (guards against double-reopening and against
   * reopening a booking the CLIENT cancelled). Excludes the cancelling
   * worker; STANDARD/INSPECTION-without-report clients continue via the
   * existing nearby-worker discovery screen, BIDDING/INSPECTION-with-report
   * get a fresh nearby-worker notification push so other Ustaads can bid
   * again â€” mirroring how each lane is notified on first creation.
   */
  async reopenAfterWorkerCancellation(
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
    if (
      booking.status !== BookingStatus.CANCELLED ||
      booking.cancelledByRole !== 'WORKER'
    ) {
      throw new BadRequestException(
        'This booking is not eligible to be reopened.',
      );
    }
    // workerProfileId is deliberately left set after a worker cancellation
    // (so the cancelling worker still sees it in their own history) â€” that
    // is exactly who must now be excluded from being rehired.
    const cancelledWorkerProfileId = booking.workerProfileId;
    if (!cancelledWorkerProfileId) {
      throw new BadRequestException(
        'No previously assigned worker found for this booking.',
      );
    }

    const now = new Date();
    const expiresAt = new Date(now.getTime() + BOOKING_EXPIRY_MS);
    const updated = await this.bookingsRepository.reopenAfterWorkerCancellation(
      bookingId,
      cancelledWorkerProfileId,
      booking.cancellationReason ?? 'Worker cancelled',
      now,
      expiresAt,
    );

    void this._scheduleExpiry(bookingId, expiresAt).catch((err) => {
      this.logger.warn(
        `[expiry] scheduleExpiry failed for bookingId=${bookingId}: ${(err as Error)?.message}`,
      );
    });

    // The booking is live again, and reopening reset `liveStartedAt` â€” which
    // starts a NEW broadcast cycle, so eligible workers notified during the
    // previous cycle are reachable once more (exactly once). The cancelling
    // worker is excluded by the exclusion row the reopen just wrote.
    void this.jobBroadcastService.broadcastJob(bookingId);

    return this._toDto(updated);
  }

  /**
   * PATCH /bookings/:id/relist â€” client "Make Live Again" on an EXPIRED
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

    // Relisting reset `liveStartedAt`, opening a new broadcast cycle â€” every
    // currently-eligible nearby Ustaad may be notified once more.
    void this.jobBroadcastService.broadcastJob(bookingId);

    return this._toDto(updated);
  }

  // â”€â”€ Expiry job management â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

  /** Cancel any pending auto-expiry job â€” call whenever a booking leaves PENDING. */
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
        reject(
          new Error(`${label} timed out after ${EXPIRY_QUEUE_TIMEOUT_MS}ms`),
        );
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

  // â”€â”€ Nearby-worker broadcast â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //
  // The three former per-lane fan-outs (_notifyWorkersListedForStandardJob,
  // _notifyNearbyWorkersForBidding, _notifyNearbyWorkersForPostInspectionBidding)
  // have been replaced by JobBroadcastService.broadcastJob, which lives in the
  // leaf MatchingModule and shares its final eligibility decision with the New
  // Jobs feed so notification reach and feed visibility cannot drift.

  // â”€â”€ Private helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

    // The inspecting worker lives on this booking's own report, or â€” for a
    // linked repair booking spawned by "Find Other Ustaad" â€” on the source
    // inspection booking's report.
    const iwp =
      booking.inspectionReport?.workerProfile ??
      booking.sourceInspectionBooking?.inspectionReport?.workerProfile;
    const inspectingWorker: WorkerSummaryDto | null = iwp
      ? {
          id: iwp.id,
          firstName: iwp.firstName,
          lastName: iwp.lastName,
          rating: iwp.rating,
          avatarUrl: iwp.avatarUrl,
          currentLat: iwp.currentLat ?? null,
          currentLng: iwp.currentLng ?? null,
          phone: iwp.user.phone,
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
      workerName: e.workerProfile
        ? `${e.workerProfile.firstName} ${e.workerProfile.lastName}`.trim()
        : null,
      reason: e.reason ?? null,
      createdAt: e.createdAt.toISOString(),
    }));

    // Most recent exclusion reason/name â€” drives the client's "Previous
    // Ustaad [name] cancelled: [reason]" strip while the booking is back in
    // choose-worker state.
    const lastWorkerCancellationReason = workerExclusions[0]?.reason ?? null;
    const lastWorkerCancellationWorkerName =
      workerExclusions[0]?.workerName ?? null;

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
      cancelledByRole:
        (booking.cancelledByRole as 'CLIENT' | 'WORKER' | null) ?? null,
      expiresAt: booking.expiresAt?.toISOString() ?? null,
      liveStartedAt: booking.liveStartedAt?.toISOString() ?? null,
      relistedAt: booking.relistedAt?.toISOString() ?? null,
      worker,
      inspectingWorker,
      availableWorkersCount: null,
      attachments,
      review,
      acceptedBidAmount,
      workerExclusions,
      lastWorkerCancellationReason,
      lastWorkerCancellationWorkerName,
      inspectionReportSubmitted: booking.inspectionReport != null,
      inspectionDecisionStatus:
        booking.inspectionReport?.decisionStatus ?? null,
      inspectionReportSubmittedAt:
        booking.inspectionReport?.createdAt.toISOString() ?? null,
      sourceInspectionBookingId: booking.sourceInspectionBookingId ?? null,
      attachedInspectionBookingId:
        booking.attachedInspectionBookingId ?? null,
      linkedRepairBookingId: booking.repairBooking?.id ?? null,
      // Derived from the ORIGINAL inspection work unit reaching COMPLETED â€”
      // never from paymentStatus (a dead column), the existence of a report,
      // or the linked repair's own status. See inspection-fee.util.ts.
      inspectionFeePaid: deriveInspectionFeePaid(booking),
    };
  }
}


