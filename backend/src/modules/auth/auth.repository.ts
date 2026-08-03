import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import {
  AuthOtp,
  AuthOtpPurpose,
  PasswordResetOtp,
  Role,
  User,
} from '@prisma/client';
import { phoneLookupVariants } from '../../common/utils/phone.util';

@Injectable()
export class AuthRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findUserByPhone(phone: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { phone } });
  }

  async findUserById(id: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { id } });
  }

  async createUserWithProfile(data: {
    phone: string;
    /** null for passwordless CLIENT OTP registration. */
    passwordHash: string | null;
    firstName: string;
    lastName: string;
    role: Role;
    /** WORKER only — the single main skill picked at registration. */
    categoryId?: string;
    /**
     * Omit for password-based registration (schema default `false` applies
     * — "must be marked as phone-unverified"); pass `true` only from an
     * OTP-verified registration flow.
     */
    phoneVerified?: boolean;
  }): Promise<User> {
    return this.prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          phone: data.phone,
          passwordHash: data.passwordHash,
          role: data.role,
          ...(data.phoneVerified !== undefined && {
            phoneVerified: data.phoneVerified,
          }),
        },
      });

      if (data.role === Role.CLIENT) {
        await tx.clientProfile.create({
          data: {
            userId: user.id,
            firstName: data.firstName,
            lastName: data.lastName,
          },
        });
      } else if (data.role === Role.WORKER) {
        const workerProfile = await tx.workerProfile.create({
          data: {
            userId: user.id,
            firstName: data.firstName,
            lastName: data.lastName,
          },
        });

        if (data.categoryId) {
          await tx.workerSkill.create({
            data: {
              workerProfileId: workerProfile.id,
              categoryId: data.categoryId,
            },
          });
          // Mirrors WorkersRepository.replaceSkills — having exactly one
          // skill is what profileCompleted means.
          await tx.workerProfile.update({
            where: { id: workerProfile.id },
            data: { profileCompleted: true },
          });
        }
      }

      return user;
    });
  }

  async createRefreshToken(
    userId: string,
    token: string,
    expiresAt: Date,
  ): Promise<void> {
    await this.prisma.refreshToken.create({
      data: { userId, token, expiresAt },
    });
  }

  async findRefreshToken(token: string) {
    return this.prisma.refreshToken.findUnique({ where: { token } });
  }

  async deleteRefreshToken(token: string): Promise<void> {
    await this.prisma.refreshToken.delete({ where: { token } });
  }

  async deleteAllRefreshTokens(userId: string): Promise<void> {
    await this.prisma.refreshToken.deleteMany({ where: { userId } });
  }

  async findClientProfile(userId: string) {
    return this.prisma.clientProfile.findUnique({
      where: { userId },
      select: { firstName: true, lastName: true },
    });
  }

  async findWorkerProfile(userId: string) {
    return this.prisma.workerProfile.findUnique({
      where: { userId },
      select: { firstName: true, lastName: true, verificationStatus: true },
    });
  }

  async updateClientAvatarUrl(
    userId: string,
    avatarUrl: string,
  ): Promise<void> {
    await this.prisma.clientProfile.update({
      where: { userId },
      data: { avatarUrl },
    });
  }

  async updateWorkerAvatarUrl(
    userId: string,
    avatarUrl: string,
  ): Promise<void> {
    await this.prisma.workerProfile.update({
      where: { userId },
      data: { avatarUrl },
    });
  }

  async updateClientAvatar(
    userId: string,
    avatarUrl: string,
    avatarStorageKey: string,
  ): Promise<void> {
    await this.prisma.clientProfile.update({
      where: { userId },
      data: { avatarUrl, avatarStorageKey },
    });
  }

  async updateWorkerAvatar(
    userId: string,
    avatarUrl: string,
    avatarStorageKey: string,
  ): Promise<void> {
    await this.prisma.workerProfile.update({
      where: { userId },
      data: { avatarUrl, avatarStorageKey },
    });
  }

  async getAvatarUrls(
    userId: string,
    role: Role,
  ): Promise<{ avatarUrl: string | null }> {
    if (role === Role.CLIENT) {
      const p = await this.prisma.clientProfile.findUnique({
        where: { userId },
        select: { avatarUrl: true },
      });
      return { avatarUrl: p?.avatarUrl ?? null };
    }
    const p = await this.prisma.workerProfile.findUnique({
      where: { userId },
      select: { avatarUrl: true },
    });
    return { avatarUrl: p?.avatarUrl ?? null };
  }

  async saveFcmToken(userId: string, token: string): Promise<void> {
    await this.prisma.user.update({
      where: { id: userId },
      data: { fcmToken: token },
    });
  }

  async findUserByNormalizedPhone(
    normalizedPhone: string,
  ): Promise<User | null> {
    return this.findUserByPhoneVariants(phoneLookupVariants(normalizedPhone));
  }

  /**
   * Finds a user regardless of which historical raw-phone format they were
   * stored under (03..., 92..., +92..., 0092...) — pass the full variant
   * list from `phoneLookupVariants` so a number is never treated as two
   * different users just because of formatting.
   */
  async findUserByPhoneVariants(variants: string[]): Promise<User | null> {
    const matches = await this.prisma.user.findMany({
      where: { phone: { in: variants } },
      take: 1,
    });
    return matches[0] ?? null;
  }

  async updatePassword(userId: string, passwordHash: string): Promise<void> {
    await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash },
    });
  }

  /** Called after a successful OTP verification for an existing account. */
  async markPhoneVerified(userId: string): Promise<void> {
    await this.prisma.user.update({
      where: { id: userId },
      data: { phoneVerified: true },
    });
  }

  async countRecentOtpRequests(phone: string, since: Date): Promise<number> {
    return this.prisma.passwordResetOtp.count({
      where: { phone, createdAt: { gte: since } },
    });
  }

  async invalidatePreviousOtps(userId: string, phone: string): Promise<void> {
    await this.prisma.passwordResetOtp.updateMany({
      where: { userId, phone, consumedAt: null },
      data: { consumedAt: new Date() },
    });
  }

  async createPasswordResetOtp(data: {
    userId: string;
    phone: string;
    otpHash: string;
    expiresAt: Date;
  }): Promise<void> {
    await this.prisma.passwordResetOtp.create({ data });
  }

  async findActiveOtp(
    userId: string,
    phone: string,
  ): Promise<PasswordResetOtp | null> {
    return this.prisma.passwordResetOtp.findFirst({
      where: { userId, phone, consumedAt: null, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: 'desc' },
    });
  }

  /** Most recent request regardless of consumed/expired state — used only
   * for the 60-second resend cooldown check. */
  async findMostRecentPasswordResetOtp(
    userId: string,
    phone: string,
  ): Promise<PasswordResetOtp | null> {
    return this.prisma.passwordResetOtp.findFirst({
      where: { userId, phone },
      orderBy: { createdAt: 'desc' },
    });
  }

  async incrementOtpAttempts(id: string): Promise<void> {
    await this.prisma.passwordResetOtp.update({
      where: { id },
      data: { attempts: { increment: 1 } },
    });
  }

  async consumeOtp(id: string): Promise<void> {
    await this.prisma.passwordResetOtp.update({
      where: { id },
      data: { consumedAt: new Date() },
    });
  }

  async consumeAllActiveOtps(userId: string, phone: string): Promise<void> {
    await this.prisma.passwordResetOtp.updateMany({
      where: { userId, phone, consumedAt: null },
      data: { consumedAt: new Date() },
    });
  }

  // ── AuthOtp (SMS login/registration OTP — purpose-scoped, separate from
  // PasswordResetOtp) ─────────────────────────────────────────────────────

  async createAuthOtp(data: {
    phone: string;
    purpose: AuthOtpPurpose;
    otpHash: string;
    expiresAt: Date;
    requestIp: string | null;
  }): Promise<string> {
    const created = await this.prisma.authOtp.create({ data });
    return created.id;
  }

  /**
   * Removes an OTP row that was written but whose SMS the provider never
   * accepted. A code the Ustaad cannot possibly have received must not sit
   * there consuming their resend cooldown and per-phone quota.
   */
  async deleteAuthOtp(id: string): Promise<void> {
    await this.prisma.authOtp.deleteMany({ where: { id } });
  }

  async findActiveAuthOtp(
    phone: string,
    purpose: AuthOtpPurpose,
  ): Promise<AuthOtp | null> {
    return this.prisma.authOtp.findFirst({
      where: { phone, purpose, consumedAt: null, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: 'desc' },
    });
  }

  async mostRecentAuthOtp(
    phone: string,
    purpose: AuthOtpPurpose,
  ): Promise<AuthOtp | null> {
    return this.prisma.authOtp.findFirst({
      where: { phone, purpose },
      orderBy: { createdAt: 'desc' },
    });
  }

  async invalidatePreviousAuthOtps(
    phone: string,
    purpose: AuthOtpPurpose,
  ): Promise<void> {
    await this.prisma.authOtp.updateMany({
      where: { phone, purpose, consumedAt: null },
      data: { consumedAt: new Date() },
    });
  }

  async incrementAuthOtpAttempts(id: string): Promise<void> {
    await this.prisma.authOtp.update({
      where: { id },
      data: { attempts: { increment: 1 } },
    });
  }

  async consumeAuthOtp(id: string): Promise<void> {
    await this.prisma.authOtp.update({
      where: { id },
      data: { consumedAt: new Date() },
    });
  }

  async countRecentAuthOtpByPhone(
    phone: string,
    purpose: AuthOtpPurpose,
    since: Date,
  ): Promise<number> {
    return this.prisma.authOtp.count({
      where: { phone, purpose, createdAt: { gte: since } },
    });
  }

  async countRecentAuthOtpByIp(ip: string, since: Date): Promise<number> {
    return this.prisma.authOtp.count({
      where: { requestIp: ip, createdAt: { gte: since } },
    });
  }

  async softDeleteUser(userId: string): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: userId },
        data: { deletedAt: new Date(), isActive: false, fcmToken: null },
      });
      await tx.refreshToken.deleteMany({ where: { userId } });
    });
  }
}
