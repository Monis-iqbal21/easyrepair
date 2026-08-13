import { AccountStatus } from '@prisma/client';

/**
 * One row of GET /admin/clients. Deliberately excludes passwordHash,
 * refreshTokens, fcmToken, and every OTP-related field — only ever
 * constructed field-by-field from a narrow Prisma `select`, never by
 * spreading a raw row.
 */
export class ClientListItemDto {
  /** ClientProfile.id — the id used by the detail/profile routes. */
  id: string;
  /** User.id — needed for the existing PATCH /admin/users/:userId/account-status endpoint. */
  userId: string;
  firstName: string;
  lastName: string;
  avatarUrl: string | null;
  phone: string;
  phoneVerified: boolean;
  accountStatus: AccountStatus;
  bookingsCount: number;
  createdAt: Date;
  /** Latest booking createdAt if any bookings exist, else ClientProfile.updatedAt — see AdminClientsService. */
  lastActivityAt: Date;
}

export class ClientPaginationMetaDto {
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
}

export class PaginatedClientsDto {
  items: ClientListItemDto[];
  meta: ClientPaginationMetaDto;
}
