import {
  BookingStatus,
  BookingUrgency,
  TimeSlot,
  UrgentWindow,
  AttachmentType,
} from '@prisma/client';

export class NearbyWorkerDto {
  id: string;
  firstName: string;
  lastName: string;
  avatarUrl: string | null;
  rating: number;
  completedJobs: number;
  distanceKm: number;
  skills: string[];
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
  acceptedBidAmount: number | null;
}
