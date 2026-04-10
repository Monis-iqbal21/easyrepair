"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var BookingsService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.BookingsService = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const bookings_repository_1 = require("./bookings.repository");
const storage_service_1 = require("../storage/storage.service");
const notifications_service_1 = require("../notifications/notifications.service");
const chat_service_1 = require("../chat/chat.service");
let BookingsService = BookingsService_1 = class BookingsService {
    constructor(bookingsRepository, storageService, notificationsService, chatService) {
        this.bookingsRepository = bookingsRepository;
        this.storageService = storageService;
        this.notificationsService = notificationsService;
        this.chatService = chatService;
        this.logger = new common_1.Logger(BookingsService_1.name);
    }
    async createBooking(userId, dto) {
        this.logger.log(`[createBooking] userId=${userId} payload=${JSON.stringify(dto)}`);
        const profile = await this.bookingsRepository.findClientProfileByUserId(userId);
        if (!profile) {
            this.logger.warn(`[createBooking] no client profile for userId=${userId}`);
            throw new common_1.ForbiddenException('Client profile not found');
        }
        this.logger.log(`[createBooking] clientProfileId=${profile.id}`);
        const category = await this.bookingsRepository.findCategoryByName(dto.serviceCategory);
        if (!category) {
            this.logger.warn(`[createBooking] category not found: "${dto.serviceCategory}"`);
            throw new common_1.NotFoundException(`Service category "${dto.serviceCategory}" not found. Please contact support.`);
        }
        this.logger.log(`[createBooking] categoryId=${category.id} name=${category.name}`);
        if (dto.latitude === undefined ||
            dto.longitude === undefined ||
            (dto.latitude === 0 && dto.longitude === 0)) {
            throw new common_1.BadRequestException('Valid GPS coordinates are required to create a booking.');
        }
        const scheduledAt = dto.scheduledAt ? new Date(dto.scheduledAt) : undefined;
        if (dto.urgency === client_1.BookingUrgency.NORMAL && !dto.timeSlot) {
            throw new common_1.BadRequestException('A time slot is required for normal (non-urgent) bookings.');
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
    async getClientBookings(userId) {
        this.logger.log(`[getClientBookings] userId=${userId}`);
        const profile = await this.bookingsRepository.findClientProfileByUserId(userId);
        if (!profile) {
            this.logger.warn(`[getClientBookings] no client profile for userId=${userId}`);
            throw new common_1.ForbiddenException('Client profile not found');
        }
        const bookings = await this.bookingsRepository.findBookingsByClientProfileId(profile.id);
        this.logger.log(`[getClientBookings] clientProfileId=${profile.id} count=${bookings.length}`);
        return bookings.map((b) => this._toDto(b));
    }
    async cancelBooking(userId, bookingId, reason) {
        const profile = await this.bookingsRepository.findClientProfileByUserId(userId);
        if (!profile) {
            throw new common_1.ForbiddenException('Client profile not found');
        }
        const booking = await this.bookingsRepository.findBookingById(bookingId);
        if (!booking) {
            throw new common_1.NotFoundException('Booking not found');
        }
        if (booking.clientProfileId !== profile.id) {
            throw new common_1.ForbiddenException('Not your booking');
        }
        if (booking.status !== client_1.BookingStatus.PENDING) {
            const reason = booking.workerProfileId != null
                ? 'Cannot cancel a booking that already has an assigned worker.'
                : `Cannot cancel a booking with status ${booking.status}`;
            throw new common_1.BadRequestException(reason);
        }
        const updated = await this.bookingsRepository.cancelBooking(bookingId, reason, booking.workerProfile?.id ?? null);
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
    async getBookingById(userId, bookingId) {
        const profile = await this.bookingsRepository.findClientProfileByUserId(userId);
        if (!profile)
            throw new common_1.ForbiddenException('Client profile not found');
        const booking = await this.bookingsRepository.findBookingById(bookingId);
        if (!booking)
            throw new common_1.NotFoundException('Booking not found');
        if (booking.clientProfileId !== profile.id) {
            throw new common_1.ForbiddenException('Not your booking');
        }
        return this._toDto(booking);
    }
    async updateBooking(userId, bookingId, dto) {
        const profile = await this.bookingsRepository.findClientProfileByUserId(userId);
        if (!profile)
            throw new common_1.ForbiddenException('Client profile not found');
        const booking = await this.bookingsRepository.findBookingById(bookingId);
        if (!booking)
            throw new common_1.NotFoundException('Booking not found');
        if (booking.clientProfileId !== profile.id)
            throw new common_1.ForbiddenException('Not your booking');
        if (booking.status !== client_1.BookingStatus.PENDING) {
            throw new common_1.BadRequestException('Only PENDING bookings without an assigned worker can be edited.');
        }
        if (booking.workerProfileId !== null) {
            throw new common_1.BadRequestException('Cannot edit a booking that already has an assigned worker.');
        }
        let categoryId;
        if (dto.serviceCategory) {
            const category = await this.bookingsRepository.findCategoryByName(dto.serviceCategory);
            if (!category) {
                throw new common_1.NotFoundException(`Service category "${dto.serviceCategory}" not found.`);
            }
            categoryId = category.id;
        }
        if (dto.latitude !== undefined &&
            dto.longitude !== undefined &&
            dto.latitude === 0 &&
            dto.longitude === 0) {
            throw new common_1.BadRequestException('Valid GPS coordinates are required (0,0 is not a valid location).');
        }
        const newUrgency = dto.urgency ?? booking.urgency;
        const newTimeSlot = dto.timeSlot !== undefined ? dto.timeSlot : booking.timeSlot;
        if (newUrgency === client_1.BookingUrgency.NORMAL && !newTimeSlot) {
            throw new common_1.BadRequestException('A time slot is required for normal (non-urgent) bookings.');
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
    async submitReview(userId, bookingId, dto) {
        const profile = await this.bookingsRepository.findClientProfileByUserId(userId);
        if (!profile)
            throw new common_1.ForbiddenException('Client profile not found');
        const booking = await this.bookingsRepository.findBookingById(bookingId);
        if (!booking)
            throw new common_1.NotFoundException('Booking not found');
        if (booking.clientProfileId !== profile.id)
            throw new common_1.ForbiddenException('Not your booking');
        if (booking.status !== client_1.BookingStatus.COMPLETED) {
            throw new common_1.BadRequestException('Reviews can only be submitted for completed bookings.');
        }
        if (booking.review) {
            throw new common_1.ConflictException('A review has already been submitted for this booking.');
        }
        if (!booking.workerProfileId) {
            throw new common_1.BadRequestException('Cannot review a booking without an assigned worker.');
        }
        const updated = await this.bookingsRepository.createReview(bookingId, {
            rating: dto.rating,
            comment: dto.comment,
            workerProfileId: booking.workerProfileId,
        });
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
    async uploadAttachment(userId, bookingId, file) {
        const profile = await this.bookingsRepository.findClientProfileByUserId(userId);
        if (!profile)
            throw new common_1.ForbiddenException('Client profile not found');
        const booking = await this.bookingsRepository.findBookingById(bookingId);
        if (!booking)
            throw new common_1.NotFoundException('Booking not found');
        if (booking.clientProfileId !== profile.id)
            throw new common_1.ForbiddenException('Not your booking');
        if (booking.status !== client_1.BookingStatus.PENDING) {
            throw new common_1.BadRequestException('Attachments can only be added to PENDING bookings.');
        }
        if (booking.workerProfileId !== null) {
            throw new common_1.BadRequestException('Cannot add attachments to a booking that has an assigned worker.');
        }
        const type = this._resolveAttachmentType(file.mimetype);
        const url = await this.storageService.upload(file.buffer, file.originalname, file.mimetype, 'booking-attachments');
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
    async deleteAttachment(userId, bookingId, attachmentId) {
        const profile = await this.bookingsRepository.findClientProfileByUserId(userId);
        if (!profile)
            throw new common_1.ForbiddenException('Client profile not found');
        const booking = await this.bookingsRepository.findBookingById(bookingId);
        if (!booking)
            throw new common_1.NotFoundException('Booking not found');
        if (booking.clientProfileId !== profile.id)
            throw new common_1.ForbiddenException('Not your booking');
        if (booking.status !== client_1.BookingStatus.PENDING) {
            throw new common_1.BadRequestException('Attachments can only be removed from PENDING bookings.');
        }
        if (booking.workerProfileId !== null) {
            throw new common_1.BadRequestException('Cannot remove attachments from a booking that has an assigned worker.');
        }
        const attachment = await this.bookingsRepository.findAttachmentById(attachmentId);
        if (!attachment)
            throw new common_1.NotFoundException('Attachment not found');
        if (attachment.bookingId !== bookingId)
            throw new common_1.ForbiddenException('Attachment does not belong to this booking');
        await this.bookingsRepository.deleteAttachment(attachmentId);
        await this.storageService.deleteByUrl(attachment.url);
    }
    async getNearbyWorkers(userId, bookingId, radiusKm) {
        const profile = await this.bookingsRepository.findClientProfileByUserId(userId);
        if (!profile)
            throw new common_1.ForbiddenException('Client profile not found');
        const booking = await this.bookingsRepository.findBookingById(bookingId);
        if (!booking)
            throw new common_1.NotFoundException('Booking not found');
        if (booking.clientProfileId !== profile.id)
            throw new common_1.ForbiddenException('Not your booking');
        if (booking.status !== client_1.BookingStatus.PENDING) {
            throw new common_1.BadRequestException('Nearby workers are only available for PENDING bookings.');
        }
        if (booking.workerProfileId !== null) {
            throw new common_1.BadRequestException('This booking already has an assigned worker.');
        }
        const { workers, searchedRadiusKm, searchCompleted } = await this.bookingsRepository.findNearbyWorkers({
            categoryId: booking.categoryId,
            lat: booking.latitude,
            lng: booking.longitude,
            radiusKm,
        });
        const workerDtos = workers.map((w) => ({
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
    async assignWorker(userId, bookingId, workerProfileId) {
        const profile = await this.bookingsRepository.findClientProfileByUserId(userId);
        if (!profile)
            throw new common_1.ForbiddenException('Client profile not found');
        const booking = await this.bookingsRepository.findBookingById(bookingId);
        if (!booking)
            throw new common_1.NotFoundException('Booking not found');
        if (booking.clientProfileId !== profile.id)
            throw new common_1.ForbiddenException('Not your booking');
        if (booking.status !== client_1.BookingStatus.PENDING) {
            throw new common_1.BadRequestException('Can only assign a worker to a PENDING booking.');
        }
        if (booking.workerProfileId !== null) {
            throw new common_1.ConflictException('This booking already has an assigned worker.');
        }
        const worker = await this.bookingsRepository.findWorkerProfileById(workerProfileId);
        if (!worker)
            throw new common_1.NotFoundException('Worker not found.');
        if (worker.availabilityStatus !== client_1.AvailabilityStatus.ONLINE) {
            throw new common_1.BadRequestException('This worker is no longer available. Please choose another.');
        }
        const updated = await this.bookingsRepository.assignWorkerToBooking(bookingId, workerProfileId);
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
            void this.chatService.ensureConversationForBooking(userId, worker.userId);
        }
        return this._toDto(updated);
    }
    _resolveAttachmentType(mimeType) {
        if (mimeType.startsWith('image/'))
            return client_1.AttachmentType.IMAGE;
        if (mimeType.startsWith('video/'))
            return client_1.AttachmentType.VIDEO;
        if (mimeType.startsWith('audio/'))
            return client_1.AttachmentType.AUDIO;
        return client_1.AttachmentType.IMAGE;
    }
    _toDto(booking) {
        const wp = booking.workerProfile;
        const worker = wp
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
        const review = rv
            ? {
                id: rv.id,
                rating: rv.rating,
                comment: rv.comment ?? null,
                createdAt: rv.createdAt.toISOString(),
            }
            : null;
        const attachments = booking.attachments.map((a) => ({
            id: a.id,
            type: a.type,
            url: a.url,
            fileName: a.fileName ?? null,
            mimeType: a.mimeType ?? null,
            createdAt: a.createdAt.toISOString(),
        }));
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
};
exports.BookingsService = BookingsService;
exports.BookingsService = BookingsService = BookingsService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [bookings_repository_1.BookingsRepository,
        storage_service_1.StorageService,
        notifications_service_1.NotificationsService,
        chat_service_1.ChatService])
], BookingsService);
//# sourceMappingURL=bookings.service.js.map