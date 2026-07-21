import {
  Injectable,
  ConflictException,
  UnauthorizedException,
  ForbiddenException,
  NotFoundException,
  Logger,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { v4 as uuidv4 } from 'uuid';
import { Role } from '@prisma/client';
import { AuthRepository } from './auth.repository';
import { StorageService } from '../storage/storage.service';
import { WhatsappOtpService } from './whatsapp-otp.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { AuthResponseDto } from './dto/auth-response.dto';
import { ForgotPasswordRequestDto } from './dto/forgot-password-request.dto';
import { ForgotPasswordResetDto } from './dto/forgot-password-reset.dto';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly authRepository: AuthRepository,
    private readonly jwtService: JwtService,
    private readonly config: ConfigService,
    private readonly storageService: StorageService,
    private readonly whatsappOtp: WhatsappOtpService,
  ) {}

  private _normalizePhone(phone: string): string {
    const digits = phone.replace(/\D/g, '');
    if (digits.startsWith('92') && digits.length === 12) return `+${digits}`;
    if (digits.startsWith('0') && digits.length === 11) return `+92${digits.slice(1)}`;
    if (digits.length === 10 && digits.startsWith('3')) return `+92${digits}`;
    return phone; // already E.164 or unknown format — pass through
  }

  async register(dto: RegisterDto): Promise<AuthResponseDto> {
    const existing = await this.authRepository.findUserByPhone(dto.phone);
    if (existing) {
      throw new ConflictException('Phone number is already registered');
    }

    const passwordHash = await bcrypt.hash(dto.password, 12);

    const user = await this.authRepository.createUserWithProfile({
      phone: dto.phone,
      passwordHash,
      firstName: dto.firstName,
      lastName: dto.lastName,
      role: dto.role as Role,
      categoryId: dto.categoryId,
    });

    // New workers always start as PENDING verification
    const verificationStatus =
      (dto.role as Role) === Role.WORKER ? 'PENDING' : undefined;
    return this._buildAuthResponse(
      user.id,
      user.phone,
      user.role,
      dto.firstName,
      dto.lastName,
      verificationStatus,
    );
  }

  async login(dto: LoginDto): Promise<AuthResponseDto> {
    const user = await this.authRepository.findUserByPhone(dto.phone);
    if (!user || user.deletedAt !== null) {
      throw new UnauthorizedException('Invalid phone number or password');
    }

    if (!user.isActive) {
      throw new ForbiddenException('Account is deactivated');
    }

    const passwordMatch = await bcrypt.compare(
      dto.password,
      user.passwordHash ?? '',
    );
    if (!passwordMatch) {
      throw new UnauthorizedException('Invalid phone number or password');
    }

    const profile = await this._getProfileName(user.id, user.role);

    return this._buildAuthResponse(
      user.id,
      user.phone,
      user.role,
      profile.firstName,
      profile.lastName,
      profile.verificationStatus,
    );
  }

  async refreshTokens(dto: RefreshTokenDto): Promise<AuthResponseDto> {
    const stored = await this.authRepository.findRefreshToken(dto.refreshToken);
    if (!stored || stored.expiresAt < new Date()) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    const user = await this.authRepository.findUserById(stored.userId);
    if (!user || !user.isActive) {
      throw new UnauthorizedException('User not found or inactive');
    }

    await this.authRepository.deleteRefreshToken(dto.refreshToken);

    const profile = await this._getProfileName(user.id, user.role);

    return this._buildAuthResponse(
      user.id,
      user.phone,
      user.role,
      profile.firstName,
      profile.lastName,
      profile.verificationStatus,
    );
  }

  async logout(userId: string, refreshToken?: string): Promise<void> {
    if (refreshToken) {
      await this.authRepository
        .deleteRefreshToken(refreshToken)
        .catch(() => {});
    } else {
      await this.authRepository.deleteAllRefreshTokens(userId);
    }
  }

  async getMe(userId: string): Promise<AuthResponseDto['user']> {
    const user = await this.authRepository.findUserById(userId);
    if (!user) {
      throw new UnauthorizedException('User not found');
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

  private async _getProfileName(
    userId: string,
    role: Role,
  ): Promise<{
    firstName: string;
    lastName: string;
    verificationStatus?: string;
  }> {
    if (role === Role.CLIENT) {
      const p = await this.authRepository.findClientProfile(userId);
      return p ?? { firstName: '', lastName: '' };
    } else {
      const p = await this.authRepository.findWorkerProfile(userId);
      if (!p) return { firstName: '', lastName: '' };
      return {
        firstName: p.firstName,
        lastName: p.lastName,
        verificationStatus: p.verificationStatus,
      };
    }
  }

  private async _buildAuthResponse(
    userId: string,
    phone: string,
    role: Role,
    firstName: string,
    lastName: string,
    verificationStatus?: string,
  ): Promise<AuthResponseDto> {
    const accessToken = this.jwtService.sign(
      { sub: userId, phone, role } as object,
      {
        expiresIn: this.config.getOrThrow<string>('jwt.accessExpires') as
          | `${number}${'s' | 'm' | 'h' | 'd' | 'w' | 'y'}`
          | number,
      },
    );

    const refreshToken = uuidv4();
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30);

    await this.authRepository.createRefreshToken(
      userId,
      refreshToken,
      expiresAt,
    );

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

  async saveFcmToken(userId: string, token: string): Promise<void> {
    await this.authRepository.saveFcmToken(userId, token);
  }

  /** Get the current avatar URL for any user (client or worker). */
  async getAvatarUrl(userId: string): Promise<{ avatarUrl: string | null }> {
    const user = await this.authRepository.findUserById(userId);
    if (!user) throw new NotFoundException('User not found');
    return this.authRepository.getAvatarUrls(userId, user.role);
  }

  async forgotPasswordRequest(dto: ForgotPasswordRequestDto): Promise<{ message: string }> {
    const normalized = this._normalizePhone(dto.phone);
    const safeResponse = { message: 'If this number is registered, a reset code will be sent.' };

    const user = await this.authRepository.findUserByNormalizedPhone(normalized);
    if (!user) return safeResponse;

    // Rate limit: max 3 requests per phone in last 30 minutes
    const since = new Date(Date.now() - 30 * 60 * 1000);
    const recentCount = await this.authRepository.countRecentOtpRequests(normalized, since);
    if (recentCount >= 3) {
      this.logger.warn(`OTP rate limit hit for ${normalized}`);
      return safeResponse;
    }

    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const otpHash = await bcrypt.hash(otp, 10);
    const expiresAt = new Date(Date.now() + 30 * 60 * 1000);

    await this.authRepository.invalidatePreviousOtps(user.id, normalized);
    await this.authRepository.createPasswordResetOtp({ userId: user.id, phone: normalized, otpHash, expiresAt });

    if (this.whatsappOtp.isConfigured) {
      try {
        await this.whatsappOtp.sendOtp(normalized, otp);
      } catch (err) {
        this.logger.warn(`WhatsApp OTP send failed for ${normalized}: ${(err as Error).message}`);
      }
    } else if (process.env.NODE_ENV !== 'production') {
      this.logger.log(`[DEV OTP] phone=${normalized} code=${otp}`);
    } else {
      this.logger.warn('WhatsApp OTP not configured — forgot password OTP not sent');
    }

    return safeResponse;
  }

  async forgotPasswordReset(dto: ForgotPasswordResetDto): Promise<{ message: string }> {
    const normalized = this._normalizePhone(dto.phone);
    const invalidError = new UnauthorizedException('Invalid or expired reset code.');

    const user = await this.authRepository.findUserByNormalizedPhone(normalized);
    if (!user) throw invalidError;

    const record = await this.authRepository.findActiveOtp(user.id, normalized);

    if (!record) {
      // Dev fallback: allow FORGOT_PASSWORD_DEV_OTP if non-production and env set
      if (process.env.NODE_ENV !== 'production') {
        const devOtp = this.config.get<string>('forgotPassword.devOtp');
        if (devOtp && dto.otp === devOtp) {
          const passwordHash = await bcrypt.hash(dto.newPassword, 12);
          await this.authRepository.updatePassword(user.id, passwordHash);
          return { message: 'Password reset successfully.' };
        }
      }
      throw invalidError;
    }

    if (record.attempts >= 5) {
      await this.authRepository.consumeOtp(record.id);
      throw invalidError;
    }

    const valid = await bcrypt.compare(dto.otp, record.otpHash);
    if (!valid) {
      await this.authRepository.incrementOtpAttempts(record.id);
      throw invalidError;
    }

    const passwordHash = await bcrypt.hash(dto.newPassword, 12);
    await this.authRepository.updatePassword(user.id, passwordHash);
    await this.authRepository.consumeAllActiveOtps(user.id, normalized);
    return { message: 'Password reset successfully.' };
  }

  async deleteAccount(userId: string): Promise<{ message: string }> {
    const user = await this.authRepository.findUserById(userId);
    if (!user) throw new UnauthorizedException('User not found');
    await this.authRepository.softDeleteUser(userId);
    return { message: 'Account deleted successfully.' };
  }

  /** Upload a new profile picture and persist the URL for the user. */
  async uploadAvatar(
    userId: string,
    buffer: Buffer,
    originalName: string,
    mimeType: string,
  ): Promise<{ avatarUrl: string }> {
    const user = await this.authRepository.findUserById(userId);
    if (!user) throw new NotFoundException('User not found');

    const uploaded = await this.storageService.uploadFile(
      buffer,
      originalName,
      mimeType,
      `uploads/avatars/${userId}`,
    );

    if (user.role === Role.CLIENT) {
      await this.authRepository.updateClientAvatar(userId, uploaded.url, uploaded.key);
    } else {
      await this.authRepository.updateWorkerAvatar(userId, uploaded.url, uploaded.key);
    }

    return { avatarUrl: uploaded.url };
  }
}
