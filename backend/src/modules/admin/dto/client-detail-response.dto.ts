import { AccountStatus, BookingStatus } from '@prisma/client';

export class ClientBookingSummaryDto {
  total: number;
  completed: number;
  /** PENDING/ACCEPTED/EN_ROUTE/ARRIVED/IN_PROGRESS — still live. */
  active: number;
  /** CANCELLED/REJECTED/EXPIRED — did not result in a completed job. */
  cancelled: number;
}

export class ClientRecentBookingDto {
  id: string;
  categoryName: string;
  status: BookingStatus;
  /** null when the booking has no assigned worker yet. */
  workerName: string | null;
  createdAt: Date;
}

/**
 * GET /admin/clients/:clientProfileId. Deliberately excludes passwordHash,
 * refreshTokens, fcmToken, and every OTP-related field — only ever
 * constructed field-by-field from a narrow Prisma `select`.
 */
export class ClientDetailResponseDto {
  id: string;
  userId: string;
  firstName: string;
  lastName: string;
  avatarUrl: string | null;
  phone: string;
  phoneVerified: boolean;
  accountStatus: AccountStatus;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
  bookingSummary: ClientBookingSummaryDto;
  recentBookings: ClientRecentBookingDto[];
}
