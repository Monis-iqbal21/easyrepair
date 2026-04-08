import { AttachmentType, BookingStatus, BookingUrgency, TimeSlot } from '@prisma/client';
export declare class WorkerJobAttachmentDto {
    id: string;
    type: AttachmentType;
    url: string;
    fileName: string | null;
    mimeType: string | null;
    createdAt: string;
}
export declare class WorkerJobStatusHistoryDto {
    id: string;
    status: BookingStatus;
    note: string | null;
    createdAt: string;
}
export declare class WorkerJobResponseDto {
    id: string;
    serviceCategory: string;
    title: string | null;
    description: string;
    status: BookingStatus;
    urgency: BookingUrgency;
    timeSlot: TimeSlot | null;
    scheduledDate: string | null;
    createdAt: string;
    acceptedAt: string | null;
    startedAt: string | null;
    completedAt: string | null;
    estimatedPrice: number | null;
    finalPrice: number | null;
    address: string;
    city: string;
    latitude: number;
    longitude: number;
    clientName: string | null;
    attachments: WorkerJobAttachmentDto[];
    statusHistory: WorkerJobStatusHistoryDto[];
}
