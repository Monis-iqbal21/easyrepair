import { BookingStatus, BookingUrgency, TimeSlot, AttachmentType } from '@prisma/client';
export declare class NearbyWorkerDto {
    id: string;
    firstName: string;
    lastName: string;
    avatarUrl: string | null;
    rating: number;
    completedJobs: number;
    distanceKm: number;
    skills: string[];
}
export declare class NearbyWorkersResponseDto {
    workers: NearbyWorkerDto[];
    searchedRadiusKm: number;
    totalFound: number;
    searchCompleted: boolean;
}
export declare class WorkerSummaryDto {
    id: string;
    firstName: string;
    lastName: string;
    rating: number;
    avatarUrl: string | null;
    currentLat: number | null;
    currentLng: number | null;
}
export declare class BookingReviewDto {
    id: string;
    rating: number;
    comment: string | null;
    createdAt: string;
}
export declare class BookingAttachmentDto {
    id: string;
    type: AttachmentType;
    url: string;
    fileName: string | null;
    mimeType: string | null;
    createdAt: string;
}
export declare class BookingResponseDto {
    id: string;
    serviceCategory: string;
    title: string | null;
    description: string;
    status: BookingStatus;
    urgency: BookingUrgency;
    timeSlot: TimeSlot | null;
    scheduledDate: string | null;
    createdAt: string;
    estimatedPrice: number | null;
    finalPrice: number | null;
    address: string;
    city: string;
    latitude: number;
    longitude: number;
    completedAt: string | null;
    cancellationReason: string | null;
    worker: WorkerSummaryDto | null;
    availableWorkersCount: number | null;
    attachments: BookingAttachmentDto[];
    review: BookingReviewDto | null;
}
