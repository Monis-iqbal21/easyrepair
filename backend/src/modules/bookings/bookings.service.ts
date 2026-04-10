import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
  Logger,
} from '@nestjs/common';
import {
  AttachmentType,
  AvailabilityStatus,
  BookingStatus,
  BookingUrgency,
  TimeSlot,
} from '@prisma/client';
import {
  BookingsRepository,
  BookingWithRelations,
} from './bookings.repository';
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

@Injectable()
export class BookingsService {
  private readonly logger = new Logger(BookingsService.name);

  constructor(
    private readonly bookingsRepository: BookingsRepository,
    private readonly storageService: StorageService,
    private readonly notificationsService: NotificationsService,
    private readonly chatService: ChatService,
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
    });

    this.logger.log(`[createBooking] created bookingId=${booking.id}`);
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
    );

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
    });

    return this._toDto(updated);
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
    const url = await this.storageService.upload(
      file.buffer,
      file.originalname,
      file.mimetype,
      'booking-attachments',
    );

    const attachment = await this.bookingsRepository.createAttachment({
      bookingId,
      type,
      url,
      fileName: file.originalname,
      mimeType: file.mimetype,
    });

    return {
      id: attachment.id,
      type: attachment.type,
      url: attachment.url,
      fileName: attachment.fileName ?? null,
      mimeType: attachment.mimeType ?? null,
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

    const { workers, searchedRadiusKm, searchCompleted } =
      await this.bookingsRepository.findNearbyWorkers({
        categoryId: booking.categoryId,
        lat: booking.latitude,
        lng: booking.longitude,
        radiusKm,
      });

    const workerDtos: NearbyWorkerDto[] = workers.map((w) => ({
      id: w.id,
      firstName: w.firstName,
      lastName: w.lastName,
      avatarUrl: w.avatarUrl,
      rating: w.rating,
      completedJobs: w.completedJobs,
      distanceKm: Math.round(w.distanceMeters / 100) / 10,
      skills: w.skills,
    }));

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

    const worker =
      await this.bookingsRepository.findWorkerProfileById(workerProfileId);
    if (!worker) throw new NotFoundException('Worker not found.');
    if (worker.availabilityStatus !== AvailabilityStatus.ONLINE) {
      throw new BadRequestException(
        'This worker is no longer available. Please choose another.',
      );
    }

    const updated = await this.bookingsRepository.assignWorkerToBooking(
      bookingId,
      workerProfileId,
    );

    // Notify the assigned worker
    if (worker.userId) {
      void this.notificationsService.notify({
        userId: worker.userId,
        eventKey: 'booking.assigned',
        title: 'New Job Assigned',
        body: "You've been assigned to a new job. Tap to view details.",
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

  // ── Private helpers ────────────────────────────────────────────────────────

  private _resolveAttachmentType(mimeType: string): AttachmentType {
    if (mimeType.startsWith('image/')) return AttachmentType.IMAGE;
    if (mimeType.startsWith('video/')) return AttachmentType.VIDEO;
    if (mimeType.startsWith('audio/')) return AttachmentType.AUDIO;
    // Fallback — treat unknown mime types as image to avoid blocking the upload.
    return AttachmentType.IMAGE;
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
        }
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
        fileName: a.fileName ?? null,
        mimeType: a.mimeType ?? null,
        createdAt: a.createdAt.toISOString(),
      }),
    );

    return {
      id: booking.id,
      serviceCategory: booking.category.name,
      title: booking.title ?? null,
      description: booking.description,
      status: booking.status,
      urgency: booking.urgency,
      timeSlot: booking.timeSlot ?? null,
      scheduledDate: booking.scheduledAt?.toISOString() ?? null,
      createdAt: booking.createdAt.toISOString(),
      estimatedPrice: booking.estimatedPrice ?? null,
      finalPrice: booking.finalPrice ?? null,
      address: booking.addressLine,
      city: booking.city,
      latitude: booking.latitude,
      longitude: booking.longitude,
      completedAt: booking.completedAt?.toISOString() ?? null,
      cancellationReason: booking.cancellationReason ?? null,
      worker,
      availableWorkersCount: null,
      attachments,
      review,
    };
  }
}
