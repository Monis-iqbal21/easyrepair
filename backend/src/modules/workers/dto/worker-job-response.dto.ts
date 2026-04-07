import { AttachmentType, BookingStatus, BookingUrgency, TimeSlot } from '@prisma/client';

export class WorkerJobAttachmentDto {
  id: string;
  type: AttachmentType;
  url: string;
  fileName: string | null;
  mimeType: string | null;
  createdAt: string;
}

export class WorkerJobStatusHistoryDto {
  id: string;
  status: BookingStatus;
  note: string | null;
  createdAt: string;
}

/**
 * Response shape for worker job endpoints.
 * Field names intentionally mirror BookingResponseDto (address / scheduledDate)
 * so the Flutter BookingModel.fromJson can parse both client and worker responses.
 * Extra fields (acceptedAt, startedAt, statusHistory) are absent from the client
 * DTO; the Flutter model reads them with null-safe fallbacks.
 */
export class WorkerJobResponseDto {
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
  attachments: WorkerJobAttachmentDto[];
  statusHistory: WorkerJobStatusHistoryDto[];
}
