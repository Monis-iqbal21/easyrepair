import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma, Role } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { isSupportPhone } from '../../common/utils/support-identity.util';

/**
 * Resolves (and, on first use, provisions) the single "HandyGo Support"
 * system user.
 *
 * WHY A USER ROW: `Conversation` is hard-wired to two NOT NULL participants
 * (`clientUserId` + `workerUserId`) and `Message.senderUserId` is a NOT NULL
 * FK. A support thread therefore needs a real counterpart row. Using ONE
 * shared identity — rather than each admin's own account — also means users
 * always see a single consistent "HandyGo Support" and can never message an
 * individual admin directly.
 *
 * WHY NO MIGRATION: `User.phone` is already `@unique`, so find-or-create by a
 * reserved phone is idempotent and concurrency-safe via the P2002 retry
 * below — exactly the pattern `ChatRepository.createConversation` uses.
 *
 * THIS ACCOUNT CANNOT LOG IN. It is created with `passwordHash: null` and
 * `phoneVerified: false`, and [isSupportPhone] lets the auth layer reject it
 * explicitly from both password and OTP flows.
 */
@Injectable()
export class SupportUserService {
  private readonly logger = new Logger(SupportUserService.name);

  /** Cached after first resolve — the row never changes. */
  private cachedId: string | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  /** Reserved phone that identifies the support account. */
  get supportPhone(): string {
    return (
      this.config.get<string>('support.userPhone') ?? '+920000000000'
    );
  }

  get displayName(): string {
    return this.config.get<string>('support.displayName') ?? 'HandyGo Support';
  }

  /**
   * True when this phone belongs to the support system account.
   *
   * The auth layer MUST consult this and refuse to issue OTPs or accept a
   * password login for it — the account exists only to own support
   * conversations and must never be signed into.
   */
  isSupportPhone(phone: string | null | undefined): boolean {
    return isSupportPhone(phone, this.supportPhone);
  }

  /** True when this userId is the support system account. */
  async isSupportUserId(userId: string): Promise<boolean> {
    if (!userId) return false;
    return userId === (await this.getSupportUserId());
  }

  /** Cached id, provisioning the row on first use. */
  async getSupportUserId(): Promise<string> {
    if (this.cachedId) return this.cachedId;
    const user = await this._findOrCreate();
    this.cachedId = user.id;
    return user.id;
  }

  private async _findOrCreate(): Promise<{ id: string }> {
    const phone = this.supportPhone;

    const existing = await this.prisma.user.findUnique({
      where: { phone },
      select: { id: true },
    });
    if (existing) return existing;

    try {
      const created = await this.prisma.user.create({
        data: {
          phone,
          // ADMIN keeps it out of every CLIENT/WORKER query in the app —
          // it has no clientProfile or workerProfile, so it can never appear
          // in worker matching, nearby-worker results, or booking flows.
          role: Role.ADMIN,
          // No credentials: this account is not signable-in by construction,
          // independently of the auth-layer guard.
          passwordHash: null,
          phoneVerified: false,
        },
        select: { id: true },
      });
      this.logger.log(`Provisioned HandyGo Support system user (${phone})`);
      return created;
    } catch (err) {
      // Concurrent first-use — another request won the insert.
      if (
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === 'P2002'
      ) {
        const winner = await this.prisma.user.findUnique({
          where: { phone },
          select: { id: true },
        });
        if (winner) return winner;
      }
      throw err;
    }
  }

}
