import { Injectable } from '@nestjs/common';
import { Prisma, Role, BookingStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { ListClientsQueryDto } from './dto/list-clients-query.dto';
import { normalizePakistaniPhone } from '../../common/utils/phone.util';

const CLIENT_ROW_SELECT = {
  id: true,
  role: true,
  phone: true,
  phoneVerified: true,
  accountStatus: true,
  isActive: true,
  deletedAt: true,
  createdAt: true,
  updatedAt: true,
  clientProfile: {
    select: {
      id: true,
      firstName: true,
      lastName: true,
      avatarUrl: true,
      updatedAt: true,
      _count: { select: { bookings: true } },
    },
  },
} satisfies Prisma.UserSelect;

export type ClientUserRow = Prisma.UserGetPayload<{ select: typeof CLIENT_ROW_SELECT }>;

const CLIENT_DETAIL_SELECT = {
  id: true,
  role: true,
  phone: true,
  phoneVerified: true,
  accountStatus: true,
  isActive: true,
  deletedAt: true,
  clientProfile: {
    select: {
      id: true,
      firstName: true,
      lastName: true,
      avatarUrl: true,
      createdAt: true,
      updatedAt: true,
    },
  },
} satisfies Prisma.UserSelect;

export type ClientDetailRow = Prisma.UserGetPayload<{ select: typeof CLIENT_DETAIL_SELECT }>;

@Injectable()
export class AdminClientsRepository {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * GET /admin/clients — paginated, searchable, filterable Clients List.
   * CLIENT-only (Worker/Admin rows are structurally excluded by the `role`
   * filter) and soft-deleted accounts are excluded from the list by default.
   */
  async findPaginated(
    query: ListClientsQueryDto,
  ): Promise<{ items: ClientUserRow[]; total: number }> {
    const where: Prisma.UserWhereInput = {
      role: Role.CLIENT,
      deletedAt: null,
      clientProfile: { isNot: null },
    };

    if (query.accountStatus) where.accountStatus = query.accountStatus;
    if (query.phoneVerified === 'VERIFIED') where.phoneVerified = true;
    if (query.phoneVerified === 'NOT_VERIFIED') where.phoneVerified = false;

    const term = query.search?.trim();
    if (term) {
      const normalized = normalizePakistaniPhone(term);
      if (normalized) {
        where.phone = normalized;
      } else {
        where.OR = [
          { phone: { contains: term.replace(/\D/g, '') || term } },
          { clientProfile: { firstName: { contains: term, mode: 'insensitive' } } },
          { clientProfile: { lastName: { contains: term, mode: 'insensitive' } } },
        ];
      }
    }

    const orderBy: Prisma.UserOrderByWithRelationInput =
      query.sort === 'OLDEST'
        ? { createdAt: 'asc' }
        : query.sort === 'NAME'
          ? { clientProfile: { firstName: 'asc' } }
          : { createdAt: 'desc' };

    const page = query.page ?? 1;
    const pageSize = query.pageSize ?? 20;

    const [items, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        orderBy,
        skip: (page - 1) * pageSize,
        take: pageSize,
        select: CLIENT_ROW_SELECT,
      }),
      this.prisma.user.count({ where }),
    ]);

    return { items, total };
  }

  /**
   * One additional query for the whole page (not per-row) — the latest
   * booking createdAt per clientProfileId, used for "Last Activity".
   */
  async findLatestBookingDates(
    clientProfileIds: string[],
  ): Promise<Map<string, Date>> {
    if (clientProfileIds.length === 0) return new Map();

    const rows = await this.prisma.booking.groupBy({
      by: ['clientProfileId'],
      where: { clientProfileId: { in: clientProfileIds } },
      _max: { createdAt: true },
    });

    const map = new Map<string, Date>();
    for (const row of rows) {
      if (row._max.createdAt) map.set(row.clientProfileId, row._max.createdAt);
    }
    return map;
  }

  async findByClientProfileId(clientProfileId: string): Promise<ClientDetailRow | null> {
    return this.prisma.user.findFirst({
      where: { clientProfile: { id: clientProfileId } },
      select: CLIENT_DETAIL_SELECT,
    });
  }

  /** One groupBy query — booking counts by status for a single client. */
  async getBookingStatusCounts(
    clientProfileId: string,
  ): Promise<Partial<Record<BookingStatus, number>>> {
    const rows = await this.prisma.booking.groupBy({
      by: ['status'],
      where: { clientProfileId },
      _count: { _all: true },
    });

    const counts: Partial<Record<BookingStatus, number>> = {};
    for (const row of rows) counts[row.status] = row._count._all;
    return counts;
  }

  async findRecentBookings(clientProfileId: string, limit: number) {
    return this.prisma.booking.findMany({
      where: { clientProfileId },
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: {
        id: true,
        status: true,
        createdAt: true,
        category: { select: { name: true } },
        workerProfile: { select: { firstName: true, lastName: true } },
      },
    });
  }

  async updateProfile(
    clientProfileId: string,
    data: Prisma.ClientProfileUpdateInput,
  ): Promise<void> {
    await this.prisma.clientProfile.update({
      where: { id: clientProfileId },
      data,
    });
  }
}
