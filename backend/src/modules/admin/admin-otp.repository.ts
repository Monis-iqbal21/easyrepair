import { Injectable } from '@nestjs/common';
import { AuthOtp, AuthOtpPurpose, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { ListOtpQueryDto } from './dto/list-otp-query.dto';
import { normalizePakistaniPhone } from '../../common/utils/phone.util';

@Injectable()
export class AdminOtpRepository {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * GET /admin/otp — paginated, searchable, filterable OTP Diagnostics feed.
   * Returns full AuthOtp rows (including otpHash/otpCiphertext/iv/tag) —
   * AdminOtpService is responsible for stripping those before they ever
   * leave the service layer.
   */
  async findPaginated(
    query: ListOtpQueryDto,
  ): Promise<{ items: AuthOtp[]; total: number }> {
    const where: Prisma.AuthOtpWhereInput = {
      createdAt: { gte: new Date(Date.now() - query.sinceMinutes * 60 * 1000) },
    };

    if (query.purpose) where.purpose = query.purpose;

    const now = new Date();
    if (query.status === 'ACTIVE') {
      where.consumedAt = null;
      where.expiresAt = { gt: now };
    } else if (query.status === 'CONSUMED') {
      where.consumedAt = { not: null };
    } else if (query.status === 'EXPIRED') {
      where.consumedAt = null;
      where.expiresAt = { lte: now };
    }

    const term = query.search?.trim();
    if (term) {
      // Same canonical normalization as auth — 0310..., 310..., 92310...,
      // +92310... all resolve to the one stored E.164 format. Falls back to
      // a partial-digit match for a still-being-typed search box.
      const normalized = normalizePakistaniPhone(term);
      where.phone = normalized
        ? normalized
        : { contains: term.replace(/\D/g, '') || term };
    }

    const page = query.page ?? 1;
    const pageSize = query.pageSize ?? 20;

    const [items, total] = await Promise.all([
      this.prisma.authOtp.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
      this.prisma.authOtp.count({ where }),
    ]);

    return { items, total };
  }

  /** Full row (including encryption fields) — used only by the reveal flow. */
  async findByIdForReveal(id: string): Promise<AuthOtp | null> {
    return this.prisma.authOtp.findUnique({ where: { id } });
  }

  async createRevealAuditLog(data: {
    adminUserId: string;
    authOtpId: string;
    targetPhone: string;
    purpose: AuthOtpPurpose;
    ipAddress: string | null;
    userAgent: string | null;
  }): Promise<void> {
    await this.prisma.otpRevealAuditLog.create({ data });
  }
}
