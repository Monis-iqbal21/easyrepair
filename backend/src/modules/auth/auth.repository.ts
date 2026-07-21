import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { PasswordResetOtp, Role, User } from '@prisma/client';

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
    passwordHash: string;
    firstName: string;
    lastName: string;
    role: Role;
    /** WORKER only — the single main skill picked at registration. */
    categoryId?: string;
  }): Promise<User> {
    return this.prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          phone: data.phone,
          passwordHash: data.passwordHash,
          role: data.role,
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

  async updateClientAvatarUrl(userId: string, avatarUrl: string): Promise<void> {
    await this.prisma.clientProfile.update({
      where: { userId },
      data: { avatarUrl },
    });
  }

  async updateWorkerAvatarUrl(userId: string, avatarUrl: string): Promise<void> {
    await this.prisma.workerProfile.update({
      where: { userId },
      data: { avatarUrl },
    });
  }

  async updateClientAvatar(userId: string, avatarUrl: string, avatarStorageKey: string): Promise<void> {
    await this.prisma.clientProfile.update({
      where: { userId },
      data: { avatarUrl, avatarStorageKey },
    });
  }

  async updateWorkerAvatar(userId: string, avatarUrl: string, avatarStorageKey: string): Promise<void> {
    await this.prisma.workerProfile.update({
      where: { userId },
      data: { avatarUrl, avatarStorageKey },
    });
  }

  async getAvatarUrls(userId: string, role: Role): Promise<{ avatarUrl: string | null }> {
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

  async findUserByNormalizedPhone(normalizedPhone: string): Promise<User | null> {
    // Try exact match first (e.g. stored as +923001234567)
    const byExact = await this.prisma.user.findUnique({
      where: { phone: normalizedPhone },
    });
    if (byExact) return byExact;

    // Fallback: stored without country code (e.g. 03001234567)
    const local = normalizedPhone.replace(/^\+92/, '0');
    return this.prisma.user.findUnique({ where: { phone: local } });
  }

  async updatePassword(userId: string, passwordHash: string): Promise<void> {
    await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash },
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

  async findActiveOtp(userId: string, phone: string): Promise<PasswordResetOtp | null> {
    return this.prisma.passwordResetOtp.findFirst({
      where: { userId, phone, consumedAt: null, expiresAt: { gt: new Date() } },
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
