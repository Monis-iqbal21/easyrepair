import { ConfigService } from '@nestjs/config';
import { AttachmentType, BookingUrgency, TimeSlot, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
export declare const BOOKING_INCLUDE: {
    category: {
        select: {
            name: true;
        };
    };
    clientProfile: {
        select: {
            userId: true;
        };
    };
    workerProfile: {
        select: {
            id: true;
            userId: true;
            firstName: true;
            lastName: true;
            avatarUrl: true;
            rating: true;
            currentLat: true;
            currentLng: true;
        };
    };
    attachments: {
        select: {
            id: true;
            type: true;
            url: true;
            fileName: true;
            mimeType: true;
            createdAt: true;
        };
        orderBy: {
            createdAt: "asc";
        };
    };
    review: {
        select: {
            id: true;
            rating: true;
            comment: true;
            createdAt: true;
        };
    };
};
export type BookingWithRelations = Prisma.BookingGetPayload<{
    include: typeof BOOKING_INCLUDE;
}>;
export declare class BookingsRepository {
    private readonly prisma;
    private readonly config;
    private readonly usePostgis;
    constructor(prisma: PrismaService, config: ConfigService);
    findCategoryByName(name: string): Promise<{
        id: string;
        name: string;
        description: string | null;
        iconUrl: string | null;
        isActive: boolean;
        createdAt: Date;
        updatedAt: Date;
    } | null>;
    findClientProfileByUserId(userId: string): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        userId: string;
        firstName: string;
        lastName: string;
        avatarUrl: string | null;
    } | null>;
    createBooking(data: {
        clientProfileId: string;
        categoryId: string;
        urgency: BookingUrgency;
        timeSlot?: TimeSlot;
        title?: string;
        description: string;
        addressLine: string;
        city: string;
        latitude: number;
        longitude: number;
        scheduledAt?: Date;
    }): Promise<BookingWithRelations>;
    findBookingsByClientProfileId(clientProfileId: string): Promise<BookingWithRelations[]>;
    findBookingById(id: string): Promise<BookingWithRelations | null>;
    updateBooking(bookingId: string, data: {
        categoryId?: string;
        title?: string | null;
        description?: string;
        urgency?: BookingUrgency;
        timeSlot?: TimeSlot | null;
        scheduledAt?: Date | null;
        addressLine?: string;
        city?: string;
        latitude?: number;
        longitude?: number;
    }): Promise<BookingWithRelations>;
    createAttachment(data: {
        bookingId: string;
        type: AttachmentType;
        url: string;
        fileName?: string;
        mimeType?: string;
    }): Promise<{
        id: string;
        createdAt: Date;
        type: import(".prisma/client").$Enums.AttachmentType;
        bookingId: string;
        url: string;
        fileName: string | null;
        mimeType: string | null;
    }>;
    findAttachmentById(id: string): Promise<{
        id: string;
        createdAt: Date;
        type: import(".prisma/client").$Enums.AttachmentType;
        bookingId: string;
        url: string;
        fileName: string | null;
        mimeType: string | null;
    } | null>;
    deleteAttachment(id: string): Promise<{
        id: string;
        createdAt: Date;
        type: import(".prisma/client").$Enums.AttachmentType;
        bookingId: string;
        url: string;
        fileName: string | null;
        mimeType: string | null;
    }>;
    createReview(bookingId: string, data: {
        rating: number;
        comment?: string;
        workerProfileId: string;
    }): Promise<BookingWithRelations>;
    cancelBooking(bookingId: string, reason?: string, workerProfileId?: string | null): Promise<BookingWithRelations>;
    findWorkerProfileById(workerProfileId: string): Promise<{
        id: string;
        userId: string;
        availabilityStatus: import(".prisma/client").$Enums.AvailabilityStatus;
    } | null>;
    findNearbyWorkers(params: {
        categoryId: string;
        lat: number;
        lng: number;
        radiusKm?: number;
    }): Promise<{
        workers: Array<{
            id: string;
            firstName: string;
            lastName: string;
            avatarUrl: string | null;
            rating: number;
            completedJobs: number;
            distanceMeters: number;
            skills: string[];
        }>;
        searchedRadiusKm: number;
        searchCompleted: boolean;
    }>;
    private _findNearbyWorkersPostgis;
    private _findNearbyWorkersHaversine;
    assignWorkerToBooking(bookingId: string, workerProfileId: string): Promise<BookingWithRelations>;
}
