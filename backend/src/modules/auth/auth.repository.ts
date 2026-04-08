import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { Role, User } from '@prisma/client';

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
        await tx.workerProfile.create({
          data: {
            userId: user.id,
            firstName: data.firstName,
            lastName: data.lastName,
          },
        });
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

  async saveFcmToken(userId: string, token: string): Promise<void> {
    await this.prisma.user.update({
      where: { id: userId },
      data: { fcmToken: token },
    });
  }
}
