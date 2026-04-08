"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthService = void 0;
const common_1 = require("@nestjs/common");
const jwt_1 = require("@nestjs/jwt");
const config_1 = require("@nestjs/config");
const bcrypt = __importStar(require("bcrypt"));
const uuid_1 = require("uuid");
const client_1 = require("@prisma/client");
const auth_repository_1 = require("./auth.repository");
let AuthService = class AuthService {
    constructor(authRepository, jwtService, config) {
        this.authRepository = authRepository;
        this.jwtService = jwtService;
        this.config = config;
    }
    async register(dto) {
        const existing = await this.authRepository.findUserByPhone(dto.phone);
        if (existing) {
            throw new common_1.ConflictException('Phone number is already registered');
        }
        const passwordHash = await bcrypt.hash(dto.password, 12);
        const user = await this.authRepository.createUserWithProfile({
            phone: dto.phone,
            passwordHash,
            firstName: dto.firstName,
            lastName: dto.lastName,
            role: dto.role,
        });
        const verificationStatus = dto.role === client_1.Role.WORKER ? 'PENDING' : undefined;
        return this._buildAuthResponse(user.id, user.phone, user.role, dto.firstName, dto.lastName, verificationStatus);
    }
    async login(dto) {
        const user = await this.authRepository.findUserByPhone(dto.phone);
        if (!user) {
            throw new common_1.UnauthorizedException('Invalid phone number or password');
        }
        if (!user.isActive) {
            throw new common_1.ForbiddenException('Account is deactivated');
        }
        const passwordMatch = await bcrypt.compare(dto.password, user.passwordHash ?? '');
        if (!passwordMatch) {
            throw new common_1.UnauthorizedException('Invalid phone number or password');
        }
        const profile = await this._getProfileName(user.id, user.role);
        return this._buildAuthResponse(user.id, user.phone, user.role, profile.firstName, profile.lastName, profile.verificationStatus);
    }
    async refreshTokens(dto) {
        const stored = await this.authRepository.findRefreshToken(dto.refreshToken);
        if (!stored || stored.expiresAt < new Date()) {
            throw new common_1.UnauthorizedException('Invalid or expired refresh token');
        }
        const user = await this.authRepository.findUserById(stored.userId);
        if (!user || !user.isActive) {
            throw new common_1.UnauthorizedException('User not found or inactive');
        }
        await this.authRepository.deleteRefreshToken(dto.refreshToken);
        const profile = await this._getProfileName(user.id, user.role);
        return this._buildAuthResponse(user.id, user.phone, user.role, profile.firstName, profile.lastName, profile.verificationStatus);
    }
    async logout(userId, refreshToken) {
        if (refreshToken) {
            await this.authRepository
                .deleteRefreshToken(refreshToken)
                .catch(() => { });
        }
        else {
            await this.authRepository.deleteAllRefreshTokens(userId);
        }
    }
    async getMe(userId) {
        const user = await this.authRepository.findUserById(userId);
        if (!user) {
            throw new common_1.UnauthorizedException('User not found');
        }
        const profile = await this._getProfileName(user.id, user.role);
        return {
            id: user.id,
            phone: user.phone,
            role: user.role,
            firstName: profile.firstName,
            lastName: profile.lastName,
            verificationStatus: profile.verificationStatus,
        };
    }
    async _getProfileName(userId, role) {
        if (role === client_1.Role.CLIENT) {
            const p = await this.authRepository.findClientProfile(userId);
            return p ?? { firstName: '', lastName: '' };
        }
        else {
            const p = await this.authRepository.findWorkerProfile(userId);
            if (!p)
                return { firstName: '', lastName: '' };
            return {
                firstName: p.firstName,
                lastName: p.lastName,
                verificationStatus: p.verificationStatus,
            };
        }
    }
    async _buildAuthResponse(userId, phone, role, firstName, lastName, verificationStatus) {
        const accessToken = this.jwtService.sign({ sub: userId, phone, role }, {
            expiresIn: this.config.getOrThrow('jwt.accessExpires'),
        });
        const refreshToken = (0, uuid_1.v4)();
        const expiresAt = new Date();
        expiresAt.setDate(expiresAt.getDate() + 30);
        await this.authRepository.createRefreshToken(userId, refreshToken, expiresAt);
        return {
            accessToken,
            refreshToken,
            user: {
                id: userId,
                phone,
                role,
                firstName,
                lastName,
                verificationStatus,
            },
        };
    }
    async saveFcmToken(userId, token) {
        await this.authRepository.saveFcmToken(userId, token);
    }
};
exports.AuthService = AuthService;
exports.AuthService = AuthService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [auth_repository_1.AuthRepository,
        jwt_1.JwtService,
        config_1.ConfigService])
], AuthService);
//# sourceMappingURL=auth.service.js.map