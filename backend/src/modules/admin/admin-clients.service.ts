import { Injectable, NotFoundException } from '@nestjs/common';
import { BookingStatus, Role } from '@prisma/client';
import {
  AdminClientsRepository,
  ClientDetailRow,
  ClientUserRow,
} from './admin-clients.repository';
import { ListClientsQueryDto } from './dto/list-clients-query.dto';
import { ClientListItemDto, PaginatedClientsDto } from './dto/client-list-item.dto';
import {
  ClientBookingSummaryDto,
  ClientDetailResponseDto,
} from './dto/client-detail-response.dto';
import { UpdateClientProfileDto } from './dto/update-client-profile.dto';

/** Still a live, unfinished booking. */
const ACTIVE_BOOKING_STATUSES: readonly BookingStatus[] = [
  BookingStatus.PENDING,
  BookingStatus.ACCEPTED,
  BookingStatus.EN_ROUTE,
  BookingStatus.ARRIVED,
  BookingStatus.IN_PROGRESS,
];

/** Ended without a completed job. */
const CANCELLED_BOOKING_STATUSES: readonly BookingStatus[] = [
  BookingStatus.CANCELLED,
  BookingStatus.REJECTED,
  BookingStatus.EXPIRED,
];

const RECENT_BOOKINGS_LIMIT = 5;

/**
 * Partitions every BookingStatus value into exactly one of
 * completed/active/cancelled (COMPLETED is its own bucket) so `total`
 * always equals the sum of the three — nothing is silently dropped.
 */
export function summarizeBookingCounts(
  counts: Partial<Record<BookingStatus, number>>,
): ClientBookingSummaryDto {
  let total = 0;
  let completed = 0;
  let active = 0;
  let cancelled = 0;

  for (const [status, count] of Object.entries(counts) as [BookingStatus, number][]) {
    total += count;
    if (status === BookingStatus.COMPLETED) completed += count;
    else if (ACTIVE_BOOKING_STATUSES.includes(status)) active += count;
    else if (CANCELLED_BOOKING_STATUSES.includes(status)) cancelled += count;
  }

  return { total, completed, active, cancelled };
}

@Injectable()
export class AdminClientsService {
  constructor(private readonly repository: AdminClientsRepository) {}

  /** GET /admin/clients */
  async list(query: ListClientsQueryDto): Promise<PaginatedClientsDto> {
    const page = query.page ?? 1;
    const pageSize = query.pageSize ?? 20;
    const { items, total } = await this.repository.findPaginated(query);

    const clientProfileIds = items.map((r) => r.clientProfile!.id);
    const latestBookingDates =
      await this.repository.findLatestBookingDates(clientProfileIds);

    return {
      items: items.map((r) => this._toListItemDto(r, latestBookingDates)),
      meta: {
        page,
        pageSize,
        total,
        totalPages: Math.max(1, Math.ceil(total / pageSize)),
      },
    };
  }

  /** GET /admin/clients/:clientProfileId */
  async getDetail(clientProfileId: string): Promise<ClientDetailResponseDto> {
    const record = await this._findClientOrThrow(clientProfileId);

    const [statusCounts, recentBookings] = await Promise.all([
      this.repository.getBookingStatusCounts(record.clientProfile!.id),
      this.repository.findRecentBookings(record.clientProfile!.id, RECENT_BOOKINGS_LIMIT),
    ]);

    return {
      id: record.clientProfile!.id,
      userId: record.id,
      firstName: record.clientProfile!.firstName,
      lastName: record.clientProfile!.lastName,
      avatarUrl: record.clientProfile!.avatarUrl,
      phone: record.phone,
      phoneVerified: record.phoneVerified,
      accountStatus: record.accountStatus,
      isActive: record.isActive,
      createdAt: record.clientProfile!.createdAt,
      updatedAt: record.clientProfile!.updatedAt,
      bookingSummary: summarizeBookingCounts(statusCounts),
      recentBookings: recentBookings.map((b) => ({
        id: b.id,
        categoryName: b.category.name,
        status: b.status,
        workerName: b.workerProfile
          ? `${b.workerProfile.firstName} ${b.workerProfile.lastName}`.trim()
          : null,
        createdAt: b.createdAt,
      })),
    };
  }

  /**
   * PATCH /admin/clients/:clientProfileId/profile
   * Operational fields only — see UpdateClientProfileDto for exactly what's
   * excluded (phone, account status) and why.
   */
  async updateProfile(
    clientProfileId: string,
    dto: UpdateClientProfileDto,
  ): Promise<ClientDetailResponseDto> {
    await this._findClientOrThrow(clientProfileId);

    if (dto.firstName !== undefined || dto.lastName !== undefined) {
      await this.repository.updateProfile(clientProfileId, {
        ...(dto.firstName !== undefined ? { firstName: dto.firstName } : {}),
        ...(dto.lastName !== undefined ? { lastName: dto.lastName } : {}),
      });
    }

    return this.getDetail(clientProfileId);
  }

  /**
   * Scoped through ClientProfile, so a Worker's WorkerProfile id (or any
   * other non-client id) can never resolve here — it simply won't be found.
   * The explicit role check below is defense-in-depth on top of that
   * structural guarantee.
   */
  private async _findClientOrThrow(clientProfileId: string): Promise<ClientDetailRow> {
    const record = await this.repository.findByClientProfileId(clientProfileId);
    if (!record || record.deletedAt !== null) {
      throw new NotFoundException('Client not found');
    }
    if (record.role !== Role.CLIENT) {
      throw new NotFoundException('Client not found');
    }
    return record;
  }

  private _toListItemDto(
    r: ClientUserRow,
    latestBookingDates: Map<string, Date>,
  ): ClientListItemDto {
    const profile = r.clientProfile!;
    const lastActivityAt = latestBookingDates.get(profile.id) ?? profile.updatedAt;

    return {
      id: profile.id,
      userId: r.id,
      firstName: profile.firstName,
      lastName: profile.lastName,
      avatarUrl: profile.avatarUrl,
      phone: r.phone,
      phoneVerified: r.phoneVerified,
      accountStatus: r.accountStatus,
      bookingsCount: profile._count.bookings,
      createdAt: r.createdAt,
      lastActivityAt,
    };
  }
}
