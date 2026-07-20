import {
  BookingStatus,
  BookingUrgency,
  BookingLane,
  TimeSlot,
  UrgentWindow,
  AttachmentType,
} from '@prisma/client';

export class BookingStandardServiceItemDto {
  id: string;
  standardServiceId: string | null;
  nameSnapshot: string;
  priceSnapshot: number;
  quantity: number;
}

export class BookingWorkerExclusionDto {
  workerProfileId: string;
  workerName: string | null;
  reason: string | null;
  createdAt: string;
}

export class NearbyWorkerDto {
  id: string;
  firstName: string;
  lastName: string;
  avatarUrl: string | null;
  rating: number;
  completedJobs: number;
  reviewsCount: number;
  cancellationRate: number;
  distanceKm: number;
  skills: string[];
  recommended: boolean;
}

export class NearbyWorkersResponseDto {
  workers: NearbyWorkerDto[];
  /** Largest radius that was searched before the pool target was reached. */
  searchedRadiusKm: number;
  /** Total unique workers returned. */
  totalFound: number;
  /** True when the pool reached the TARGET_POOL size before exhausting the ladder. */
  searchCompleted: boolean;
}

export class WorkerSummaryDto {
  id: string;
  firstName: string;
  lastName: string;
  rating: number;
  avatarUrl: string | null;
  currentLat: number | null;
  currentLng: number | null;
  phone: string | null;
}

export class BookingReviewDto {
  id: string;
  rating: number;
  comment: string | null;
  createdAt: string;
}

export class BookingAttachmentDto {
  id: string;
  type: AttachmentType;
  url: string;
  storageKey: string | null;
  fileName: string | null;
  mimeType: string | null;
  sizeBytes: number | null;
  durationSeconds: number | null;
  thumbnailUrl: string | null;
  createdAt: string;
}

export class BookingResponseDto {
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
  standardServiceId: string | null;
  standardServiceNameSnapshot: string | null;
  standardServicePriceSnapshot: number | null;
  standardServiceItems: BookingStandardServiceItemDto[];
  inspectionFeeSnapshot: number | null;
  estimatedPrice: number | null;
  finalPrice: number | null;
  address: string;
  city: string;
  latitude: number;
  longitude: number;
  acceptedAt: string | null;
  enRouteAt: string | null;
  arrivedAt: string | null;
  startedAt: string | null;
  completedAt: string | null;
  cancellationReason: string | null;
  cancelledByRole: 'CLIENT' | 'WORKER' | null;
  expiresAt: string | null;
  liveStartedAt: string | null;
  relistedAt: string | null;
  worker: WorkerSummaryDto | null;
  availableWorkersCount: number | null;
  attachments: BookingAttachmentDto[];
  review: BookingReviewDto | null;
  acceptedBidAmount: number | null;
  workerExclusions: BookingWorkerExclusionDto[];
  /** Convenience: reason the most recently assigned worker cancelled, if any — for the client's "Previous Ustaad cancelled: ..." strip. */
  lastWorkerCancellationReason: string | null;
  /** Convenience: name of the most recently assigned worker who cancelled, if any. */
  lastWorkerCancellationWorkerName: string | null;
  /** INSPECTION lane: true once the assigned worker has submitted their report. */
  inspectionReportSubmitted: boolean;
  /** INSPECTION lane: null until a report exists, then tracks the client's decision. */
  inspectionDecisionStatus:
    | 'PENDING_CLIENT_DECISION'
    | 'ACCEPTED_REPAIR'
    | 'CLOSED_AFTER_INSPECTION'
    | null;
  inspectionReportSubmittedAt: string | null;
}
