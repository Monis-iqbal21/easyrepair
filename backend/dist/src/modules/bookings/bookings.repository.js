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
exports.BookingsRepository = exports.BOOKING_INCLUDE = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const client_1 = require("@prisma/client");
const prisma_service_1 = require("../../prisma/prisma.service");
function haversineMeters(lat1, lng1, lat2, lng2) {
    const R = 6_371_000;
    const toRad = (d) => (d * Math.PI) / 180;
    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);
    const a = Math.sin(dLat / 2) ** 2 +
        Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}
exports.BOOKING_INCLUDE = {
    category: {
        select: { name: true },
    },
    clientProfile: {
        select: { userId: true },
    },
    workerProfile: {
        select: {
            id: true,
            userId: true,
            firstName: true,
            lastName: true,
            avatarUrl: true,
            rating: true,
            currentLat: true,
            currentLng: true,
        },
    },
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
    review: {
        select: {
            id: true,
            rating: true,
            comment: true,
            createdAt: true,
        },
    },
};
let BookingsRepository = class BookingsRepository {
    constructor(prisma, config) {
        this.prisma = prisma;
        this.config = config;
        this.usePostgis = this.config.get('usePostgis') ?? false;
    }
    async findCategoryByName(name) {
        return this.prisma.serviceCategory.findFirst({
            where: { name: { equals: name, mode: 'insensitive' }, isActive: true },
        });
    }
    async findClientProfileByUserId(userId) {
        return this.prisma.clientProfile.findUnique({ where: { userId } });
    }
    async createBooking(data) {
        const created = await this.prisma.$transaction(async (tx) => {
            const booking = await tx.booking.create({
                data: {
                    clientProfileId: data.clientProfileId,
                    categoryId: data.categoryId,
                    urgency: data.urgency,
                    timeSlot: data.timeSlot ?? null,
                    title: data.title ?? null,
                    description: data.description,
                    addressLine: data.addressLine,
                    city: data.city,
                    latitude: data.latitude,
                    longitude: data.longitude,
                    scheduledAt: data.scheduledAt ?? null,
                    status: client_1.BookingStatus.PENDING,
                },
            });
            await tx.bookingStatusHistory.create({
                data: {
                    bookingId: booking.id,
                    status: client_1.BookingStatus.PENDING,
                    note: 'Booking created',
                },
            });
            return booking;
        });
        return this.prisma.booking.findUniqueOrThrow({
            where: { id: created.id },
            include: exports.BOOKING_INCLUDE,
        });
    }
    async findBookingsByClientProfileId(clientProfileId) {
        return this.prisma.booking.findMany({
            where: { clientProfileId },
            orderBy: { createdAt: 'desc' },
            include: exports.BOOKING_INCLUDE,
        });
    }
    async findBookingById(id) {
        return this.prisma.booking.findUnique({
            where: { id },
            include: exports.BOOKING_INCLUDE,
        });
    }
    async updateBooking(bookingId, data) {
        await this.prisma.booking.update({
            where: { id: bookingId },
            data: {
                ...(data.categoryId !== undefined && { categoryId: data.categoryId }),
                ...(data.title !== undefined && { title: data.title }),
                ...(data.description !== undefined && {
                    description: data.description,
                }),
                ...(data.urgency !== undefined && { urgency: data.urgency }),
                ...(data.timeSlot !== undefined && { timeSlot: data.timeSlot }),
                ...(data.scheduledAt !== undefined && {
                    scheduledAt: data.scheduledAt,
                }),
                ...(data.addressLine !== undefined && {
                    addressLine: data.addressLine,
                }),
                ...(data.city !== undefined && { city: data.city }),
                ...(data.latitude !== undefined && { latitude: data.latitude }),
                ...(data.longitude !== undefined && { longitude: data.longitude }),
            },
        });
        return this.prisma.booking.findUniqueOrThrow({
            where: { id: bookingId },
            include: exports.BOOKING_INCLUDE,
        });
    }
    async createAttachment(data) {
        return this.prisma.bookingAttachment.create({ data });
    }
    async findAttachmentById(id) {
        return this.prisma.bookingAttachment.findUnique({ where: { id } });
    }
    async deleteAttachment(id) {
        return this.prisma.bookingAttachment.delete({ where: { id } });
    }
    async createReview(bookingId, data) {
        await this.prisma.$transaction(async (tx) => {
            await tx.review.create({
                data: {
                    bookingId,
                    rating: data.rating,
                    comment: data.comment ?? null,
                },
            });
            const worker = await tx.workerProfile.findUniqueOrThrow({
                where: { id: data.workerProfileId },
                select: { rating: true, totalRatings: true },
            });
            const oldCount = worker.totalRatings;
            const oldAvg = worker.rating;
            const newCount = oldCount + 1;
            const newAvg = Math.round(((oldAvg * oldCount + data.rating) / newCount) * 10) / 10;
            await tx.workerProfile.update({
                where: { id: data.workerProfileId },
                data: {
                    rating: newAvg,
                    totalRatings: newCount,
                },
            });
        });
        return this.prisma.booking.findUniqueOrThrow({
            where: { id: bookingId },
            include: exports.BOOKING_INCLUDE,
        });
    }
    async cancelBooking(bookingId, reason, workerProfileId) {
        const note = reason ?? 'Cancelled by client';
        await this.prisma.$transaction(async (tx) => {
            await tx.booking.update({
                where: { id: bookingId },
                data: {
                    status: client_1.BookingStatus.CANCELLED,
                    cancelledAt: new Date(),
                    cancellationReason: note,
                },
            });
            await tx.bookingStatusHistory.create({
                data: {
                    bookingId,
                    status: client_1.BookingStatus.CANCELLED,
                    note,
                },
            });
            if (workerProfileId) {
                await tx.workerProfile.update({
                    where: { id: workerProfileId },
                    data: { currentlyWorking: false },
                });
            }
        });
        return this.prisma.booking.findUniqueOrThrow({
            where: { id: bookingId },
            include: exports.BOOKING_INCLUDE,
        });
    }
    async findWorkerProfileById(workerProfileId) {
        return this.prisma.workerProfile.findUnique({
            where: { id: workerProfileId },
            select: { id: true, userId: true, availabilityStatus: true },
        });
    }
    async findNearbyWorkers(params) {
        return this.usePostgis
            ? this._findNearbyWorkersPostgis(params)
            : this._findNearbyWorkersHaversine(params);
    }
    async _findNearbyWorkersPostgis(params) {
        const TARGET_POOL = 4;
        const radii = params.radiusKm !== undefined
            ? [Math.round(params.radiusKm * 1000)]
            : [3000, 5000, 8000, 10000, 15000, 20000];
        const seen = new Map();
        let finalRadius = radii[radii.length - 1];
        for (const radius of radii) {
            finalRadius = radius;
            const rows = await this.prisma.$queryRaw `
        SELECT
          wp.id,
          wp."firstName",
          wp."lastName",
          wp."avatarUrl",
          wp.rating,
          ST_Distance(
            ST_SetSRID(ST_MakePoint(wp."currentLng"::float8, wp."currentLat"::float8), 4326)::geography,
            ST_SetSRID(ST_MakePoint(${params.lng}::float8, ${params.lat}::float8), 4326)::geography
          )::float8 AS distance_meters,
          ARRAY(
            SELECT sc.name
            FROM worker_skills ws2
            JOIN service_categories sc ON ws2."categoryId" = sc.id
            WHERE ws2."workerProfileId" = wp.id
          ) AS skills,
          (
            SELECT COUNT(*)
            FROM bookings b
            WHERE b."workerProfileId" = wp.id
              AND b.status = 'COMPLETED'::"BookingStatus"
          ) AS completed_jobs
        FROM worker_profiles wp
        WHERE wp."availabilityStatus" = 'ONLINE'::"AvailabilityStatus"
          AND wp."currentlyWorking" = FALSE
          AND wp."currentLat" IS NOT NULL
          AND wp."currentLng" IS NOT NULL
          AND wp."locationUpdatedAt" > NOW() - INTERVAL '30 minutes'
          AND wp.status = 'ACTIVE'::"WorkerStatus"
          AND wp."verificationStatus" = 'VERIFIED'::"VerificationStatus"
          AND EXISTS (
            SELECT 1 FROM worker_skills ws
            WHERE ws."workerProfileId" = wp.id
              AND ws."categoryId" = ${params.categoryId}
          )
          AND ST_DWithin(
            ST_SetSRID(ST_MakePoint(wp."currentLng"::float8, wp."currentLat"::float8), 4326)::geography,
            ST_SetSRID(ST_MakePoint(${params.lng}::float8, ${params.lat}::float8), 4326)::geography,
            ${radius}::float8
          )
        ORDER BY distance_meters ASC, wp.rating DESC
      `;
            for (const r of rows) {
                if (!seen.has(r.id)) {
                    seen.set(r.id, {
                        id: r.id,
                        firstName: r.firstName,
                        lastName: r.lastName,
                        avatarUrl: r.avatarUrl ?? null,
                        rating: Number(r.rating),
                        completedJobs: Number(r.completed_jobs),
                        distanceMeters: Number(r.distance_meters),
                        skills: r.skills,
                    });
                }
            }
            if (seen.size >= TARGET_POOL)
                break;
        }
        const workers = Array.from(seen.values()).sort((a, b) => a.distanceMeters !== b.distanceMeters
            ? a.distanceMeters - b.distanceMeters
            : b.rating - a.rating);
        return {
            workers,
            searchedRadiusKm: finalRadius / 1000,
            searchCompleted: seen.size >= TARGET_POOL,
        };
    }
    async _findNearbyWorkersHaversine(params) {
        const TARGET_POOL = 4;
        const radiusLadderKm = params.radiusKm !== undefined
            ? [params.radiusKm]
            : [3, 5, 8, 10, 15, 20];
        const freshThreshold = new Date(Date.now() - 30 * 60 * 1000);
        const candidates = await this.prisma.workerProfile.findMany({
            where: {
                availabilityStatus: client_1.AvailabilityStatus.ONLINE,
                currentlyWorking: false,
                status: client_1.WorkerStatus.ACTIVE,
                verificationStatus: client_1.VerificationStatus.VERIFIED,
                currentLat: { not: null },
                currentLng: { not: null },
                locationUpdatedAt: { gte: freshThreshold },
                skills: { some: { categoryId: params.categoryId } },
            },
            select: {
                id: true,
                firstName: true,
                lastName: true,
                avatarUrl: true,
                rating: true,
                currentLat: true,
                currentLng: true,
                skills: {
                    include: { category: { select: { name: true } } },
                },
                _count: {
                    select: {
                        bookings: { where: { status: client_1.BookingStatus.COMPLETED } },
                    },
                },
            },
        });
        const seen = new Map();
        let finalRadiusKm = radiusLadderKm[radiusLadderKm.length - 1];
        for (const radiusKm of radiusLadderKm) {
            finalRadiusKm = radiusKm;
            const radiusMeters = radiusKm * 1000;
            for (const w of candidates) {
                if (seen.has(w.id))
                    continue;
                const distanceMeters = haversineMeters(params.lat, params.lng, w.currentLat, w.currentLng);
                if (distanceMeters <= radiusMeters) {
                    seen.set(w.id, {
                        id: w.id,
                        firstName: w.firstName,
                        lastName: w.lastName,
                        avatarUrl: w.avatarUrl ?? null,
                        rating: Number(w.rating),
                        completedJobs: w._count.bookings,
                        distanceMeters,
                        skills: w.skills.map((s) => s.category.name),
                    });
                }
            }
            if (seen.size >= TARGET_POOL)
                break;
        }
        const workers = Array.from(seen.values()).sort((a, b) => a.distanceMeters !== b.distanceMeters
            ? a.distanceMeters - b.distanceMeters
            : b.rating - a.rating);
        return {
            workers,
            searchedRadiusKm: finalRadiusKm,
            searchCompleted: seen.size >= TARGET_POOL,
        };
    }
    async assignWorkerToBooking(bookingId, workerProfileId) {
        await this.prisma.$transaction(async (tx) => {
            await tx.booking.update({
                where: { id: bookingId },
                data: {
                    workerProfileId,
                    status: client_1.BookingStatus.ACCEPTED,
                    acceptedAt: new Date(),
                },
            });
            await tx.bookingStatusHistory.create({
                data: {
                    bookingId,
                    status: client_1.BookingStatus.ACCEPTED,
                    note: 'Worker assigned by client',
                },
            });
            await tx.workerProfile.update({
                where: { id: workerProfileId },
                data: { currentlyWorking: true },
            });
        });
        return this.prisma.booking.findUniqueOrThrow({
            where: { id: bookingId },
            include: exports.BOOKING_INCLUDE,
        });
    }
};
exports.BookingsRepository = BookingsRepository;
exports.BookingsRepository = BookingsRepository = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        config_1.ConfigService])
], BookingsRepository);
//# sourceMappingURL=bookings.repository.js.map