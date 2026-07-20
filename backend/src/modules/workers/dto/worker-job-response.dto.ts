import {
  AttachmentType,
  BookingLane,
  BookingStatus,
  BookingUrgency,
  TimeSlot,
  UrgentWindow,
} from '@prisma/client';

export class WorkerJobStandardServiceItemDto {
  id: string;
  standardServiceId: string | null;
  nameSnapshot: string;
  priceSnapshot: number;
  quantity: number;
}

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

export class WorkerJobReviewDto {
  id: string;
  rating: number;
  comment: string | null;
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
  urgentWindow: UrgentWindow | null;
  scheduledDate: string | null;
  createdAt: string;
  inspection: boolean;
  lane: BookingLane;
  standardServiceItems: WorkerJobStandardServiceItemDto[];
  acceptedAt: string | null;
  enRouteAt: string | null;
  arrivedAt: string | null;
  startedAt: string | null;
  completedAt: string | null;
  cancellationReason: string | null;
  cancelledByRole: 'CLIENT' | 'WORKER' | null;
  estimatedPrice: number | null;
  finalPrice: number | null;
  /**
   * Privacy: exact address/coordinates are only populated once this worker
   * is actually assigned to the booking. Not-yet-assigned callers (the New
   * Job detail fallback) receive `null` here — use `city` + `distanceKm`
   * instead.
   */
  address: string | null;
  city: string;
  latitude: number | null;
  longitude: number | null;
  /** Server-computed distance in km — only present when not yet assigned. */
  distanceKm: number | null;
  /** First + last name of the client who created the booking. */
  clientName: string | null;
  /**
   * Client's phone number — powers the worker's "Call" button once hired.
   * Privacy: `null` until this worker is actually assigned.
   */
  clientPhone: string | null;
  attachments: WorkerJobAttachmentDto[];
  statusHistory: WorkerJobStatusHistoryDto[];
  review: WorkerJobReviewDto | null;
  /** INSPECTION lane: true once this worker has submitted the report. */
  inspectionReportSubmitted: boolean;
  inspectionDecisionStatus:
    | 'PENDING_CLIENT_DECISION'
    | 'ACCEPTED_REPAIR'
    | 'CLOSED_AFTER_INSPECTION'
    | null;
  inspectionReportSubmittedAt: string | null;
}
