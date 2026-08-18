import {
  AttachmentType,
  BidStatus,
  BookingLane,
  BookingStatus,
  BookingUrgency,
  TimeSlot,
  UrgentWindow,
} from '@prisma/client';
import { WorkerSummaryDto } from '../../bookings/dto/booking-response.dto';

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
    | 'FIND_OTHER_USTAAD'
    | null;
  inspectionReportSubmittedAt: string | null;
  /**
   * True when this entry appears in the caller's job list solely because
   * they were the ORIGINAL inspector on a booking a different Ustaad ended
   * up performing (via "Find Other Ustaad") — finalPrice/estimatedPrice
   * above reflect the inspection fee they earned, not the other worker's
   * work amount.
   */
  isInspectionOnlyForCaller: boolean;
  /**
   * The worker who submitted the inspection report, if any — same field
   * name/shape as BookingResponseDto so BookingEntity.isDifferentWorkerPerformingWork
   * (shared with the client app) works identically here: a repair worker
   * hired via "Find Other Ustaad" has assignedWorker.id !== inspectingWorker.id,
   * which is how the app tells them apart from the original inspector to
   * show the correct lifecycle (On My Way → Arrived → In Progress →
   * Completed, never Start Inspection).
   */
  inspectingWorker: WorkerSummaryDto | null;
  /**
   * Set only on a BIDDING-lane repair booking spawned by "Find Other
   * Ustaad" — the completed inspection booking it was created from. The
   * worker app uses it to know an (always price-sanitized for non-
   * inspectors) inspection report exists for this job.
   */
  sourceInspectionBookingId: string | null;
  /**
   * Set when the client attached one of their own past completed
   * inspections' reports to this independently-posted BIDDING job. Purely
   * informational: it lets the worker open the (sanitized) report for
   * context and never excludes the original inspector from bidding.
   */
  attachedInspectionBookingId: string | null;
  /**
   * Whether the client has paid the inspection fee for the work unit this
   * Ustaad inspected — derived ONLY from the original inspection booking
   * reaching COMPLETED (see inspection-fee.util.ts). `null` when no
   * inspection is involved.
   */
  inspectionFeePaid: boolean | null;
  /**
   * My Jobs → Applied/Bids only: the status of THIS worker's own bid on the
   * job (independent of the booking's own status — e.g. a REJECTED bid on
   * an ACCEPTED booking means another worker was hired). Null everywhere
   * else (active/completed/cancelled/detail/new-jobs).
   */
  myBidStatus: BidStatus | null;
  /** My Jobs → Applied/Bids only — this worker's own bid amount. */
  myBidAmount: number | null;
}
