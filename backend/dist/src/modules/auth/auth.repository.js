"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthRepository = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../../prisma/prisma.service");
const client_1 = require("@prisma/client");
let AuthRepository = class AuthRepository {
    constructor(prisma) {
        this.prisma = prisma;
    }
    async findUserByPhone(phone) {
        return this.prisma.user.findUnique({ where: { phone } });
    }
    async findUserById(id) {
        return this.prisma.user.findUnique({ where: { id } });
    }
    async createUserWithProfile(data) {
        return this.prisma.$transaction(async (tx) => {
            const user = await tx.user.create({
                data: {
                    phone: data.phone,
                    passwordHash: data.passwordHash,
                    role: data.role,
                },
            });
            if (data.role === client_1.Role.CLIENT) {
                await tx.clientProfile.create({
                    data: {
                        userId: user.id,
                        firstName: data.firstName,
                        lastName: data.lastName,
                    },
                });
            }
            else if (data.role === client_1.Role.WORKER) {
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
    async createRefreshToken(userId, token, expiresAt) {
        await this.prisma.refreshToken.create({
            data: { userId, token, expiresAt },
        });
    }
    async findRefreshToken(token) {
        return this.prisma.refreshToken.findUnique({ where: { token } });
    }
    async deleteRefreshToken(token) {
        await this.prisma.refreshToken.delete({ where: { token } });
    }
    async deleteAllRefreshTokens(userId) {
        await this.prisma.refreshToken.deleteMany({ where: { userId } });
    }
    async findClientProfile(userId) {
        return this.prisma.clientProfile.findUnique({
            where: { userId },
            select: { firstName: true, lastName: true },
        });
    }
    async findWorkerProfile(userId) {
        return this.prisma.workerProfile.findUnique({
            where: { userId },
            select: { firstName: true, lastName: true, verificationStatus: true },
        });
    }
    async saveFcmToken(userId, token) {
        await this.prisma.user.update({
            where: { id: userId },
            data: { fcmToken: token },
        });
    }
};
exports.AuthRepository = AuthRepository;
exports.AuthRepository = AuthRepository = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], AuthRepository);
//# sourceMappingURL=auth.repository.js.map