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
var WorkersService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.WorkersService = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const workers_repository_1 = require("./workers.repository");
const notifications_service_1 = require("../notifications/notifications.service");
let WorkersService = WorkersService_1 = class WorkersService {
    constructor(workersRepository, notificationsService) {
        this.workersRepository = workersRepository;
        this.notificationsService = notificationsService;
        this.logger = new common_1.Logger(WorkersService_1.name);
    }
    async getProfile(userId) {
        const profile = await this.workersRepository.findByUserId(userId);
        if (!profile) {
            throw new common_1.NotFoundException('Worker profile not found');
        }
        const [stats, ongoingJob] = await Promise.all([
            this.workersRepository.getJobStats(profile.id),
            this.workersRepository.findOngoingJob(profile.id),
        ]);
        return {
            id: profile.id,
            userId: profile.userId,
            firstName: profile.firstName,
            lastName: profile.lastName,
            avatarUrl: profile.avatarUrl,
            bio: profile.bio,
            status: profile.status,
            verificationStatus: profile.verificationStatus,
            availabilityStatus: profile.availabilityStatus,
            currentlyWorking: profile.currentlyWorking,
            currentLat: profile.currentLat,
            currentLng: profile.currentLng,
            locationUpdatedAt: profile.locationUpdatedAt,
            rating: profile.rating,
            totalRatings: profile.totalRatings,
            skills: profile.skills.map((s) => ({
                id: s.id,
                yearsExperience: s.yearsExperience,
                category: s.category,
            })),
            stats,
            ongoingJob: ongoingJob
                ? {
                    id: ongoingJob.id,
                    title: ongoingJob.title,
                    categoryName: ongoingJob.category.name,
                    clientArea: ongoingJob.city,
                    addressLine: ongoingJob.addressLine,
                    status: ongoingJob.status,
                }
                : null,
        };
    }
    async updateAvailability(userId, dto) {
        const profile = await this.workersRepository.findByUserId(userId);
        if (!profile) {
            throw new common_1.NotFoundException('Worker profile not found');
        }
        if (dto.status === client_1.AvailabilityStatus.ONLINE &&
            profile.skills.length === 0) {
            throw new common_1.UnprocessableEntityException('You must add at least one skill before going online');
        }
        if (dto.status === client_1.AvailabilityStatus.ONLINE &&
            (dto.lat == null || dto.lng == null)) {
            throw new common_1.BadRequestException('Location is required when going online');
        }
        return this.workersRepository.updateAvailability(profile.id, dto.status, dto.lat, dto.lng);
    }
    async updateSkills(userId, dto) {
        this.logger.log(`[updateSkills] userId=${userId} categoryIds=${JSON.stringify(dto.categoryIds)}`);
        const profile = await this.workersRepository.findByUserId(userId);
        if (!profile) {
            this.logger.warn(`[updateSkills] worker profile not found for userId=${userId}`);
            throw new common_1.NotFoundException('Worker profile not found');
        }
        const found = await this.workersRepository.findCategoriesByIds(dto.categoryIds);
        this.logger.log(`[updateSkills] requested=${dto.categoryIds.length} found=${found.length}`);
        if (found.length !== dto.categoryIds.length) {
            const foundIds = found.map((c) => c.id);
            const missing = dto.categoryIds.filter((id) => !foundIds.includes(id));
            this.logger.warn(`[updateSkills] invalid categoryIds: ${JSON.stringify(missing)}`);
            throw new common_1.BadRequestException('One or more category IDs are invalid');
        }
        const skills = await this.workersRepository.replaceSkills(profile.id, dto.categoryIds);
        this.logger.log(`[updateSkills] saved ${skills.length} skills for workerProfileId=${profile.id}`);
        return skills.map((s) => ({
            id: s.id,
            yearsExperience: s.yearsExperience,
            category: s.category,
        }));
    }
    async getWorkerJobs(userId, statusFilter) {
        const profile = await this.workersRepository.findByUserId(userId);
        if (!profile)
            throw new common_1.NotFoundException('Worker profile not found');
        const jobs = await this.workersRepository.findJobsByWorkerProfileId(profile.id, statusFilter);
        return jobs.map((j) => this._toJobDto(j));
    }
    async getWorkerJobById(userId, bookingId) {
        const profile = await this.workersRepository.findByUserId(userId);
        if (!profile)
            throw new common_1.NotFoundException('Worker profile not found');
        const job = await this.workersRepository.findJobByIdAndWorkerProfileId(bookingId, profile.id);
        if (!job)
            throw new common_1.NotFoundException('Job not found');
        return this._toJobDto(job);
    }
    async completeJob(userId, bookingId) {
        const profile = await this.workersRepository.findByUserId(userId);
        if (!profile)
            throw new common_1.NotFoundException('Worker profile not found');
        const job = await this.workersRepository.findJobByIdAndWorkerProfileId(bookingId, profile.id);
        if (!job)
            throw new common_1.NotFoundException('Job not found');
        const completable = [
            client_1.BookingStatus.ACCEPTED,
            client_1.BookingStatus.EN_ROUTE,
            client_1.BookingStatus.IN_PROGRESS,
        ];
        if (!completable.includes(job.status)) {
            throw new common_1.BadRequestException(`Cannot complete a job with status ${job.status}`);
        }
        const updated = await this.workersRepository.completeBooking(bookingId, profile.id);
        if (updated.clientProfile?.userId) {
            void this.notificationsService.notify({
                userId: updated.clientProfile.userId,
                eventKey: 'booking.completed',
                title: 'Job Completed',
                body: 'Your worker has completed the job. Please leave a review.',
                bookingId,
                route: `/client/booking/${bookingId}`,
                actorUserId: userId,
                actorRole: 'WORKER',
                entityType: 'booking',
                entityId: bookingId,
            });
        }
        return this._toJobDto(updated);
    }
    async updateJobStatus(userId, bookingId, status) {
        const profile = await this.workersRepository.findByUserId(userId);
        if (!profile)
            throw new common_1.NotFoundException('Worker profile not found');
        const job = await this.workersRepository.findJobByIdAndWorkerProfileId(bookingId, profile.id);
        if (!job)
            throw new common_1.NotFoundException('Job not found');
        const validTransitions = {
            [client_1.BookingStatus.EN_ROUTE]: [client_1.BookingStatus.ACCEPTED],
            [client_1.BookingStatus.IN_PROGRESS]: [
                client_1.BookingStatus.ACCEPTED,
                client_1.BookingStatus.EN_ROUTE,
            ],
        };
        if (!validTransitions[status]?.includes(job.status)) {
            throw new common_1.BadRequestException(`Cannot transition job from ${job.status} to ${status}`);
        }
        const updated = await this.workersRepository.updateJobStatus(bookingId, profile.id, status);
        if (updated.clientProfile?.userId) {
            if (status === client_1.BookingStatus.EN_ROUTE) {
                void this.notificationsService.notify({
                    userId: updated.clientProfile.userId,
                    eventKey: 'booking.status.en_route',
                    title: 'Worker On the Way',
                    body: 'Your worker is on the way to your location.',
                    bookingId,
                    route: `/client/booking/${bookingId}`,
                    actorUserId: userId,
                    actorRole: 'WORKER',
                    entityType: 'booking',
                    entityId: bookingId,
                });
            }
            else {
                void this.notificationsService.notify({
                    userId: updated.clientProfile.userId,
                    eventKey: 'booking.status.in_progress',
                    title: 'Job Started',
                    body: 'Your worker has started working on your request.',
                    bookingId,
                    route: `/client/booking/${bookingId}`,
                    actorUserId: userId,
                    actorRole: 'WORKER',
                    entityType: 'booking',
                    entityId: bookingId,
                });
            }
        }
        return this._toJobDto(updated);
    }
    async cancelJob(userId, bookingId, reason) {
        const profile = await this.workersRepository.findByUserId(userId);
        if (!profile)
            throw new common_1.NotFoundException('Worker profile not found');
        const job = await this.workersRepository.findJobByIdAndWorkerProfileId(bookingId, profile.id);
        if (!job)
            throw new common_1.NotFoundException('Job not found');
        const cancellable = [
            client_1.BookingStatus.ACCEPTED,
            client_1.BookingStatus.EN_ROUTE,
        ];
        if (!cancellable.includes(job.status)) {
            throw new common_1.BadRequestException(`Cannot cancel a job with status ${job.status}`);
        }
        const updated = await this.workersRepository.cancelJobByWorker(bookingId, profile.id, reason);
        if (updated.clientProfile?.userId) {
            void this.notificationsService.notify({
                userId: updated.clientProfile.userId,
                eventKey: 'booking.cancelled.by_worker',
                title: 'Job Cancelled',
                body: 'The worker has cancelled the job.',
                bookingId,
                route: `/client/booking/${bookingId}`,
                actorUserId: userId,
                actorRole: 'WORKER',
                entityType: 'booking',
                entityId: bookingId,
            });
        }
        return this._toJobDto(updated);
    }
    _toJobDto(job) {
        const attachments = job.attachments.map((a) => ({
            id: a.id,
            type: a.type,
            url: a.url,
            fileName: a.fileName ?? null,
            mimeType: a.mimeType ?? null,
            createdAt: a.createdAt.toISOString(),
        }));
        const statusHistory = job.statusHistory.map((h) => ({
            id: h.id,
            status: h.status,
            note: h.note ?? null,
            createdAt: h.createdAt.toISOString(),
        }));
        const cp = job.clientProfile;
        const clientName = cp
            ? `${cp.firstName} ${cp.lastName}`.trim()
            : null;
        return {
            id: job.id,
            serviceCategory: job.category.name,
            title: job.title ?? null,
            description: job.description,
            status: job.status,
            urgency: job.urgency,
            timeSlot: job.timeSlot ?? null,
            scheduledDate: job.scheduledAt?.toISOString() ?? null,
            createdAt: job.createdAt.toISOString(),
            acceptedAt: job.acceptedAt?.toISOString() ?? null,
            startedAt: job.startedAt?.toISOString() ?? null,
            completedAt: job.completedAt?.toISOString() ?? null,
            estimatedPrice: job.estimatedPrice ?? null,
            finalPrice: job.finalPrice ?? null,
            address: job.addressLine,
            city: job.city,
            latitude: job.latitude,
            longitude: job.longitude,
            clientName,
            attachments,
            statusHistory,
            review: job.review
                ? {
                    id: job.review.id,
                    rating: job.review.rating,
                    comment: job.review.comment ?? null,
                    createdAt: job.review.createdAt.toISOString(),
                }
                : null,
        };
    }
    async getWorkerReviews(userId, limit) {
        const profile = await this.workersRepository.findByUserId(userId);
        if (!profile)
            throw new common_1.NotFoundException('Worker profile not found');
        const reviews = await this.workersRepository.findWorkerReviews(profile.id, limit);
        return reviews.map((r) => ({
            id: r.id,
            bookingId: r.booking.id,
            rating: r.rating,
            comment: r.comment ?? null,
            serviceCategory: r.booking.category.name,
            clientName: r.booking.clientProfile
                ? `${r.booking.clientProfile.firstName} ${r.booking.clientProfile.lastName}`.trim()
                : null,
            createdAt: r.createdAt.toISOString(),
        }));
    }
    async getWorkerReviewSummary(userId) {
        const profile = await this.workersRepository.findByUserId(userId);
        if (!profile)
            throw new common_1.NotFoundException('Worker profile not found');
        return this.workersRepository.getWorkerReviewSummary(profile.id);
    }
};
exports.WorkersService = WorkersService;
exports.WorkersService = WorkersService = WorkersService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [workers_repository_1.WorkersRepository,
        notifications_service_1.NotificationsService])
], WorkersService);
//# sourceMappingURL=workers.service.js.map