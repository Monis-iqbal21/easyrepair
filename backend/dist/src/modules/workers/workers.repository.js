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
Object.defineProperty(exports, "__esModule", { value: true });
exports.WorkersRepository = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const prisma_service_1 = require("../../prisma/prisma.service");
const WORKER_PROFILE_INCLUDE = {
    skills: {
        include: {
            category: {
                select: { id: true, name: true, iconUrl: true },
            },
        },
    },
};
const WORKER_JOB_INCLUDE = {
    category: { select: { name: true } },
    clientProfile: { select: { firstName: true, lastName: true, userId: true } },
    attachments: {
        select: {
            id: true,
            type: true,
            url: true,
            fileName: true,
            mimeType: true,
            createdAt: true,
        },
        orderBy: { createdAt: 'asc' },
    },
    statusHistory: {
        select: {
            id: true,
            status: true,
            note: true,
            createdAt: true,
        },
        orderBy: { createdAt: 'asc' },
    },
};
const WORKER_REVIEW_INCLUDE = {
    booking: {
        select: {
            id: true,
            category: { select: { name: true } },
            clientProfile: { select: { firstName: true, lastName: true } },
        },
    },
};
let WorkersRepository = class WorkersRepository {
    constructor(prisma) {
        this.prisma = prisma;
    }
    async findByUserId(userId) {
        return this.prisma.workerProfile.findUnique({
            where: { userId },
            include: WORKER_PROFILE_INCLUDE,
        });
    }
    async updateAvailability(workerProfileId, status, lat, lng) {
        return this.prisma.workerProfile.update({
            where: { id: workerProfileId },
            data: {
                availabilityStatus: status,
                isOnline: status === client_1.AvailabilityStatus.ONLINE ||
                    status === client_1.AvailabilityStatus.BUSY,
                ...(lat !== undefined && lng !== undefined
                    ? {
                        currentLat: lat,
                        currentLng: lng,
                        locationUpdatedAt: new Date(),
                    }
                    : {}),
            },
            select: {
                availabilityStatus: true,
                currentLat: true,
                currentLng: true,
                locationUpdatedAt: true,
            },
        });
    }
    async replaceSkills(workerProfileId, categoryIds) {
        return this.prisma.$transaction(async (tx) => {
            await tx.workerSkill.deleteMany({ where: { workerProfileId } });
            await tx.workerSkill.createMany({
                data: categoryIds.map((categoryId) => ({
                    workerProfileId,
                    categoryId,
                })),
            });
            return tx.workerSkill.findMany({
                where: { workerProfileId },
                include: {
                    category: {
                        select: { id: true, name: true, iconUrl: true },
                    },
                },
            });
        });
    }
    async getJobStats(workerProfileId) {
        const [completedJobs, activeJobs] = await Promise.all([
            this.prisma.booking.count({
                where: { workerProfileId, status: client_1.BookingStatus.COMPLETED },
            }),
            this.prisma.booking.count({
                where: {
                    workerProfileId,
                    status: {
                        in: [
                            client_1.BookingStatus.ACCEPTED,
                            client_1.BookingStatus.EN_ROUTE,
                            client_1.BookingStatus.IN_PROGRESS,
                        ],
                    },
                },
            }),
        ]);
        return { completedJobs, activeJobs };
    }
    async findOngoingJob(workerProfileId) {
        return this.prisma.booking.findFirst({
            where: {
                workerProfileId,
                status: {
                    in: [
                        client_1.BookingStatus.ACCEPTED,
                        client_1.BookingStatus.EN_ROUTE,
                        client_1.BookingStatus.IN_PROGRESS,
                    ],
                },
            },
            orderBy: { updatedAt: 'desc' },
            select: {
                id: true,
                title: true,
                status: true,
                city: true,
                addressLine: true,
                category: { select: { name: true } },
            },
        });
    }
    async findCategoriesByIds(ids) {
        return this.prisma.serviceCategory.findMany({
            where: { id: { in: ids }, isActive: true },
            select: { id: true },
        });
    }
    async findJobsByWorkerProfileId(workerProfileId, statusFilter) {
        const statusIn = (() => {
            if (statusFilter === 'active') {
                return [client_1.BookingStatus.ACCEPTED, client_1.BookingStatus.EN_ROUTE, client_1.BookingStatus.IN_PROGRESS];
            }
            if (statusFilter === 'completed')
                return [client_1.BookingStatus.COMPLETED];
            if (statusFilter === 'cancelled')
                return [client_1.BookingStatus.REJECTED, client_1.BookingStatus.CANCELLED];
            return undefined;
        })();
        return this.prisma.booking.findMany({
            where: {
                workerProfileId,
                ...(statusIn ? { status: { in: statusIn } } : {}),
            },
            include: WORKER_JOB_INCLUDE,
            orderBy: { createdAt: 'desc' },
        });
    }
    async findJobByIdAndWorkerProfileId(bookingId, workerProfileId) {
        return this.prisma.booking.findFirst({
            where: { id: bookingId, workerProfileId },
            include: WORKER_JOB_INCLUDE,
        });
    }
    async findWorkerReviews(workerProfileId, limit) {
        return this.prisma.review.findMany({
            where: { booking: { workerProfileId } },
            include: WORKER_REVIEW_INCLUDE,
            orderBy: { createdAt: 'desc' },
            ...(limit !== undefined ? { take: limit } : {}),
        });
    }
    async getWorkerReviewSummary(workerProfileId) {
        const agg = await this.prisma.review.aggregate({
            where: { booking: { workerProfileId } },
            _count: { id: true },
            _avg: { rating: true },
        });
        return {
            totalReviews: agg._count.id,
            averageRating: Math.round((agg._avg.rating ?? 0) * 10) / 10,
        };
    }
    async updateJobStatus(bookingId, workerProfileId, status) {
        const noteMap = {
            [client_1.BookingStatus.EN_ROUTE]: 'Worker is en route',
            [client_1.BookingStatus.IN_PROGRESS]: 'Job started by worker',
        };
        await this.prisma.$transaction(async (tx) => {
            await tx.booking.update({
                where: { id: bookingId },
                data: {
                    status,
                    ...(status === client_1.BookingStatus.IN_PROGRESS
                        ? { startedAt: new Date() }
                        : {}),
                },
            });
            await tx.bookingStatusHistory.create({
                data: { bookingId, status, note: noteMap[status] },
            });
        });
        return this.prisma.booking.findUniqueOrThrow({
            where: { id: bookingId },
            include: WORKER_JOB_INCLUDE,
        });
    }
    async cancelJobByWorker(bookingId, workerProfileId, reason) {
        await this.prisma.$transaction(async (tx) => {
            await tx.booking.update({
                where: { id: bookingId },
                data: {
                    status: client_1.BookingStatus.CANCELLED,
                    cancelledAt: new Date(),
                    cancellationReason: reason ?? 'Cancelled by worker',
                },
            });
            await tx.bookingStatusHistory.create({
                data: {
                    bookingId,
                    status: client_1.BookingStatus.CANCELLED,
                    note: reason ?? 'Cancelled by worker',
                },
            });
            await tx.workerProfile.update({
                where: { id: workerProfileId },
                data: { currentlyWorking: false },
            });
        });
        return this.prisma.booking.findUniqueOrThrow({
            where: { id: bookingId },
            include: WORKER_JOB_INCLUDE,
        });
    }
    async completeBooking(bookingId, workerProfileId) {
        await this.prisma.$transaction(async (tx) => {
            await tx.booking.update({
                where: { id: bookingId },
                data: {
                    status: client_1.BookingStatus.COMPLETED,
                    completedAt: new Date(),
                },
            });
            await tx.bookingStatusHistory.create({
                data: {
                    bookingId,
                    status: client_1.BookingStatus.COMPLETED,
                    note: 'Job marked as completed by worker',
                },
            });
            await tx.workerProfile.update({
                where: { id: workerProfileId },
                data: { currentlyWorking: false },
            });
        });
        return this.prisma.booking.findUniqueOrThrow({
            where: { id: bookingId },
            include: WORKER_JOB_INCLUDE,
        });
    }
};
exports.WorkersRepository = WorkersRepository;
exports.WorkersRepository = WorkersRepository = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], WorkersRepository);
//# sourceMappingURL=workers.repository.js.map