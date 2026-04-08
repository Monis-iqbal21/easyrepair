import { AvailabilityStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
declare const WORKER_PROFILE_INCLUDE: {
    skills: {
        include: {
            category: {
                select: {
                    id: true;
                    name: true;
                    iconUrl: true;
                };
            };
        };
    };
};
export type WorkerProfileWithSkills = Prisma.WorkerProfileGetPayload<{
    include: typeof WORKER_PROFILE_INCLUDE;
}>;
declare const WORKER_JOB_INCLUDE: {
    category: {
        select: {
            name: true;
        };
    };
    clientProfile: {
        select: {
            firstName: true;
            lastName: true;
            userId: true;
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
    statusHistory: {
        select: {
            id: true;
            status: true;
            note: true;
            createdAt: true;
        };
        orderBy: {
            createdAt: "asc";
        };
    };
};
export type WorkerJobWithRelations = Prisma.BookingGetPayload<{
    include: typeof WORKER_JOB_INCLUDE;
}>;
declare const WORKER_REVIEW_INCLUDE: {
    booking: {
        select: {
            id: true;
            category: {
                select: {
                    name: true;
                };
            };
            clientProfile: {
                select: {
                    firstName: true;
                    lastName: true;
                };
            };
        };
    };
};
export type WorkerReviewWithBooking = Prisma.ReviewGetPayload<{
    include: typeof WORKER_REVIEW_INCLUDE;
}>;
export declare class WorkersRepository {
    private readonly prisma;
    constructor(prisma: PrismaService);
    findByUserId(userId: string): Promise<WorkerProfileWithSkills | null>;
    updateAvailability(workerProfileId: string, status: AvailabilityStatus, lat?: number, lng?: number): Promise<{
        availabilityStatus: import(".prisma/client").$Enums.AvailabilityStatus;
        currentLat: number | null;
        currentLng: number | null;
        locationUpdatedAt: Date | null;
    }>;
    replaceSkills(workerProfileId: string, categoryIds: string[]): Promise<({
        category: {
            id: string;
            name: string;
            iconUrl: string | null;
        };
    } & {
        id: string;
        createdAt: Date;
        workerProfileId: string;
        categoryId: string;
        yearsExperience: number;
    })[]>;
    getJobStats(workerProfileId: string): Promise<{
        completedJobs: number;
        activeJobs: number;
    }>;
    findOngoingJob(workerProfileId: string): Promise<{
        id: string;
        title: string | null;
        status: import(".prisma/client").$Enums.BookingStatus;
        category: {
            name: string;
        };
        addressLine: string;
        city: string;
    } | null>;
    findCategoriesByIds(ids: string[]): Promise<{
        id: string;
    }[]>;
    findJobsByWorkerProfileId(workerProfileId: string, statusFilter?: 'active' | 'completed' | 'cancelled'): Promise<WorkerJobWithRelations[]>;
    findJobByIdAndWorkerProfileId(bookingId: string, workerProfileId: string): Promise<WorkerJobWithRelations | null>;
    findWorkerReviews(workerProfileId: string, limit?: number): Promise<WorkerReviewWithBooking[]>;
    getWorkerReviewSummary(workerProfileId: string): Promise<{
        totalReviews: number;
        averageRating: number;
    }>;
    updateJobStatus(bookingId: string, workerProfileId: string, status: 'EN_ROUTE' | 'IN_PROGRESS'): Promise<WorkerJobWithRelations>;
    cancelJobByWorker(bookingId: string, workerProfileId: string, reason?: string): Promise<WorkerJobWithRelations>;
    completeBooking(bookingId: string, workerProfileId: string): Promise<WorkerJobWithRelations>;
}
export {};
