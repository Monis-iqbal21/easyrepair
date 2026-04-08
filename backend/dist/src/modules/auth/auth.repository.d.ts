import { PrismaService } from '../../prisma/prisma.service';
import { Role, User } from '@prisma/client';
export declare class AuthRepository {
    private readonly prisma;
    constructor(prisma: PrismaService);
    findUserByPhone(phone: string): Promise<User | null>;
    findUserById(id: string): Promise<User | null>;
    createUserWithProfile(data: {
        phone: string;
        passwordHash: string;
        firstName: string;
        lastName: string;
        role: Role;
    }): Promise<User>;
    createRefreshToken(userId: string, token: string, expiresAt: Date): Promise<void>;
    findRefreshToken(token: string): Promise<{
        id: string;
        createdAt: Date;
        token: string;
        expiresAt: Date;
        userId: string;
    } | null>;
    deleteRefreshToken(token: string): Promise<void>;
    deleteAllRefreshTokens(userId: string): Promise<void>;
    findClientProfile(userId: string): Promise<{
        firstName: string;
        lastName: string;
    } | null>;
    findWorkerProfile(userId: string): Promise<{
        firstName: string;
        lastName: string;
        verificationStatus: import(".prisma/client").$Enums.VerificationStatus;
    } | null>;
    saveFcmToken(userId: string, token: string): Promise<void>;
}
