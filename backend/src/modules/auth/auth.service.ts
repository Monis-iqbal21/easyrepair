import {
  Injectable,
  ConflictException,
  UnauthorizedException,
  ForbiddenException,
  NotFoundException,
  BadRequestException,
  ServiceUnavailableException,
  Logger,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';
import { v4 as uuidv4 } from 'uuid';
import { AuthOtpPurpose, Prisma, Role } from '@prisma/client';
import { AuthRepository } from './auth.repository';
import { StorageService } from '../storage/storage.service';
import { isSupportPhone } from '../../common/utils/support-identity.util';
import { ChatService } from '../chat/chat.service';
import { SmsOtpService } from './sms-otp.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { AuthResponseDto } from './dto/auth-response.dto';
import { ForgotPasswordRequestDto } from './dto/forgot-password-request.dto';
import { ForgotPasswordResetDto } from './dto/forgot-password-reset.dto';
import {
  normalizePakistaniPhone,
  phoneLookupVariants,
} from '../../common/utils/phone.util';

const OTP_EXPIRY_MS = 5 * 60 * 1000;
const OTP_RESEND_COOLDOWN_MS = 60 * 1000;
const OTP_MAX_ATTEMPTS = 5;
const OTP_MAX_PER_PHONE_PER_WINDOW = 3;
const OTP_MAX_PER_IP_PER_WINDOW = 10;
const OTP_RATE_WINDOW_MS = 30 * 60 * 1000;

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly authRepository: AuthRepository,
    private readonly jwtService: JwtService,
    private readonly config: ConfigService,
    private readonly storageService: StorageService,
    private readonly smsOtp: SmsOtpService,
    private readonly chatService: ChatService,
  ) {}

  /**
   * Refuses any authentication attempt for the "HandyGo Support" system
   * account.
   *
   * That account exists only to own support conversations and to be the
   * sender of admin replies — it is provisioned without credentials and must
   * never be signable-in through ANY path (password login, OTP request, OTP
   * verification, or password reset). The message is deliberately the same
   * generic one used for unknown numbers so the reserved number cannot be
   * probed.
   */
  private _assertNotSupportAccount(phone: string): void {
    const supportPhone = this.config.get<string>('support.userPhone');
    if (isSupportPhone(phone, supportPhone)) {
      throw new UnauthorizedException('Invalid phone number');
    }
  }

  private _normalizePhone(phone: string): string {
    // Forgot-password's DTO already enforces the Pakistani-mobile shape, so
    // this always succeeds here — kept as a thin wrapper over the shared,
    // authoritative normalizer so both call sites stay in sync.
    return normalizePakistaniPhone(phone) ?? phone;
  }

  /** First word -> firstName, remaining words -> lastName (possibly ''). */
  private _splitFullName(fullName: string): {
    firstName: string;
    lastName: string;
  } {
    const parts = fullName.trim().split(/\s+/).filter(Boolean);
    return {
      firstName: parts[0] ?? '',
      lastName: parts.slice(1).join(' '),
    };
  }

  async register(dto: RegisterDto): Promise<AuthResponseDto> {
    this._assertNotSupportAccount(dto.phone);
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
    this._assertNotSupportAccount(dto.phone);
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

    // Every successful login/registration funnels through here, so this is
    // the one place that guarantees a support thread exists from the very
    // first session. Idempotent (DB-enforced), CLIENT/WORKER only, and
    // fire-and-forget with its own internal catch — it can never fail auth.
    void this.chatService.ensureSupportConversation(userId, role);

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

  /**
   * POST /auth/forgot-password/request — WORKER password recovery only;
   * Clients never have a password to reset. The response shape (including
   * `expiresAt`) is always identical regardless of whether the number is
   * registered, is a Worker, is rate-limited, or hit the resend cooldown —
   * this must never become a way to probe which phone numbers exist.
   */
  async forgotPasswordRequest(
    dto: ForgotPasswordRequestDto,
  ): Promise<{ message: string; expiresAt: string }> {
    this._assertNotSupportAccount(dto.phone);
    return this._passwordResetRequestForRole(dto.phone, Role.WORKER, {
      surfaceSmsFailure: false,
    });
  }

  /**
   * POST /auth/client/forgot-password/request — same PasswordResetOtp model
   * and rate-limit/cooldown rules as the Worker flow above (a phone can only
   * ever belong to one role, so sharing the model has no cross-contamination
   * risk), gated to CLIENT instead of WORKER. Unlike the Worker flow, a
   * genuine VeevoTech send failure is surfaced (not swallowed) — see
   * `_passwordResetRequestForRole` for why this doesn't weaken
   * enumeration-safety.
   */
  async clientForgotPasswordRequest(
    dto: ForgotPasswordRequestDto,
  ): Promise<{ message: string; expiresAt: string }> {
    this._assertNotSupportAccount(dto.phone);
    return this._passwordResetRequestForRole(dto.phone, Role.CLIENT, {
      surfaceSmsFailure: true,
    });
  }

  /**
   * Shared body for the Worker and Client "forgot password" OTP request —
   * the response shape (including `expiresAt`) is always identical
   * regardless of whether the number is registered, belongs to [role], is
   * rate-limited, or hit the resend cooldown, so this must never become a
   * way to probe which phone numbers exist or what role they are.
   *
   * [options.surfaceSmsFailure] is the one behavioral difference between
   * callers: when true, a *genuine* VeevoTech send failure (checked only
   * after the number is confirmed eligible — i.e. only for a real [role]
   * account that isn't rate-limited/on cooldown) throws a distinguishable
   * error instead of being swallowed. This is safe for enumeration purposes
   * because a provider outage is phone-independent information — it would
   * fail identically for any eligible number — so surfacing it never leaks
   * whether *this specific* phone has an account.
   */
  private async _passwordResetRequestForRole(
    rawPhone: string,
    role: Role,
    options: { surfaceSmsFailure: boolean },
  ): Promise<{ message: string; expiresAt: string }> {
    const normalized = this._normalizePhone(rawPhone);
    const fallbackExpiresAt = new Date(Date.now() + OTP_EXPIRY_MS);
    const safeResponse = {
      message: 'If this number is registered, a reset code will be sent.',
      expiresAt: fallbackExpiresAt.toISOString(),
    };

    const user =
      await this.authRepository.findUserByNormalizedPhone(normalized);
    if (!user || user.role !== role) return safeResponse;

    // Rate limit: max 3 requests per phone in last 30 minutes
    const since = new Date(Date.now() - 30 * 60 * 1000);
    const recentCount = await this.authRepository.countRecentOtpRequests(
      normalized,
      since,
    );
    if (recentCount >= 3) {
      this.logger.warn(`Password-reset OTP rate limit hit for ${normalized}`);
      return safeResponse;
    }

    // 60s resend cooldown — reuse the still-valid OTP's real expiry instead
    // of sending another SMS, but keep the response shape identical.
    const mostRecent = await this.authRepository.findMostRecentPasswordResetOtp(
      user.id,
      normalized,
    );
    if (
      mostRecent &&
      Date.now() - mostRecent.createdAt.getTime() < OTP_RESEND_COOLDOWN_MS
    ) {
      return { ...safeResponse, expiresAt: mostRecent.expiresAt.toISOString() };
    }

    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const otpHash = await bcrypt.hash(otp, 10);
    const expiresAt = fallbackExpiresAt;

    await this.authRepository.invalidatePreviousOtps(user.id, normalized);
    await this.authRepository.createPasswordResetOtp({
      userId: user.id,
      phone: normalized,
      otpHash,
      expiresAt,
    });

    const sendFailureError = new ServiceUnavailableException({
      message: 'SMS bhejne mein masla hua. Dobara koshish karein.',
      error: 'SMS_SEND_FAILED',
    });

    if (this.smsOtp.isConfigured) {
      const sent = await this.smsOtp.sendOtp(normalized, otp);
      if (!sent) {
        this.logger.warn(`Password-reset SMS OTP send failed for ${normalized}`);
        if (options.surfaceSmsFailure) throw sendFailureError;
      }
    } else if (process.env.NODE_ENV !== 'production') {
      this.logger.log(`[DEV OTP] phone=${normalized} code=${otp}`);
    } else {
      this.logger.warn(
        'SMS OTP not configured — forgot password OTP not sent',
      );
      if (options.surfaceSmsFailure) throw sendFailureError;
    }

    return safeResponse;
  }

  async forgotPasswordReset(
    dto: ForgotPasswordResetDto,
  ): Promise<{ message: string }> {
    this._assertNotSupportAccount(dto.phone);
    const normalized = this._normalizePhone(dto.phone);
    const invalidError = new UnauthorizedException(
      'Invalid or expired reset code.',
    );

    const user =
      await this.authRepository.findUserByNormalizedPhone(normalized);
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
      await this.authRepository.updateClientAvatar(
        userId,
        uploaded.url,
        uploaded.key,
      );
    } else {
      await this.authRepository.updateWorkerAvatar(
        userId,
        uploaded.url,
        uploaded.key,
      );
    }

    return { avatarUrl: uploaded.url };
  }

  // ── SMS OTP login/registration ──────────────────────────────────────────

  /** POST /auth/otp/request — public, purpose-scoped, rate-limited. */
  async requestOtp(
    rawPhone: string,
    purpose: AuthOtpPurpose,
    ip: string,
  ): Promise<{ expiresAt: string }> {
    this._assertNotSupportAccount(rawPhone);
    const normalized = normalizePakistaniPhone(rawPhone);
    if (!normalized) {
      throw new BadRequestException({
        message: 'Sahi Pakistani mobile number likhein.',
        error: 'INVALID_PHONE',
      });
    }

    const since = new Date(Date.now() - OTP_RATE_WINDOW_MS);
    const [byPhone, byIp] = await Promise.all([
      this.authRepository.countRecentAuthOtpByPhone(normalized, purpose, since),
      this.authRepository.countRecentAuthOtpByIp(ip, since),
    ]);
    if (byPhone >= OTP_MAX_PER_PHONE_PER_WINDOW || byIp >= OTP_MAX_PER_IP_PER_WINDOW) {
      throw new BadRequestException({
        message: 'Bohat zyada koshishein. Thori dair baad dobara koshish karein.',
        error: 'OTP_RATE_LIMITED',
      });
    }

    const mostRecent = await this.authRepository.mostRecentAuthOtp(
      normalized,
      purpose,
    );
    if (
      mostRecent &&
      Date.now() - mostRecent.createdAt.getTime() < OTP_RESEND_COOLDOWN_MS
    ) {
      throw new BadRequestException({
        message: 'Thori dair intezaar karein, phir dobara code mangwayein.',
        error: 'OTP_RESEND_TOO_SOON',
      });
    }

    const otp = crypto.randomInt(100000, 1000000).toString();
    const otpHash = await bcrypt.hash(otp, 10);
    const expiresAt = new Date(Date.now() + OTP_EXPIRY_MS);

    await this.authRepository.invalidatePreviousAuthOtps(normalized, purpose);
    await this.authRepository.createAuthOtp({
      phone: normalized,
      purpose,
      otpHash,
      expiresAt,
      requestIp: ip || null,
    });

    if (this.smsOtp.isConfigured) {
      const sent = await this.smsOtp.sendOtp(normalized, otp);
      if (!sent) {
        throw new ServiceUnavailableException({
          message: 'SMS bhejne mein masla hua. Dobara koshish karein.',
          error: 'SMS_SEND_FAILED',
        });
      }
    } else if (process.env.NODE_ENV !== 'production') {
      this.logger.log(`[DEV OTP] phone=${normalized} purpose=${purpose} code=${otp}`);
    } else {
      throw new ServiceUnavailableException({
        message: 'SMS bhejne mein masla hua. Dobara koshish karein.',
        error: 'SMS_SEND_FAILED',
      });
    }

    return { expiresAt: expiresAt.toISOString() };
  }

  /**
   * Verifies the active OTP for phone+purpose. Throws a purpose-scoped,
   * attempt/expiry-aware error on any failure; returns silently on success
   * (the OTP is consumed either way once it's checked).
   */
  private async _verifyAuthOtp(
    normalizedPhone: string,
    purpose: AuthOtpPurpose,
    otp: string,
  ): Promise<void> {
    const expiredError = new BadRequestException({
      message: 'Code expire ho gaya hai. Naya code mangwayein.',
      error: 'OTP_EXPIRED',
    });

    const record = await this.authRepository.findActiveAuthOtp(
      normalizedPhone,
      purpose,
    );
    if (!record) throw expiredError;

    if (record.attempts >= OTP_MAX_ATTEMPTS) {
      await this.authRepository.consumeAuthOtp(record.id);
      throw new BadRequestException({
        message: 'Bohat zyada ghalat koshishein. Naya code mangwayein.',
        error: 'OTP_ATTEMPTS_EXCEEDED',
      });
    }

    const valid = await bcrypt.compare(otp, record.otpHash);
    if (!valid) {
      await this.authRepository.incrementAuthOtpAttempts(record.id);
      throw new BadRequestException({
        message: 'OTP ghalat hai.',
        error: 'OTP_INVALID',
      });
    }

    await this.authRepository.consumeAuthOtp(record.id);
  }

  /**
   * POST /auth/client/otp-login — the backend (not Flutter) decides whether
   * this is a login or a registration: existing CLIENT -> login (name
   * untouched), no account -> create CLIENT + login, existing WORKER ->
   * reject (this is not the Worker login surface).
   */
  async clientOtpLoginOrRegister(
    fullName: string,
    rawPhone: string,
    otp: string,
  ): Promise<AuthResponseDto> {
    this._assertNotSupportAccount(rawPhone);
    const normalized = normalizePakistaniPhone(rawPhone);
    if (!normalized) {
      throw new BadRequestException({
        message: 'Sahi Pakistani mobile number likhein.',
        error: 'INVALID_PHONE',
      });
    }

    await this._verifyAuthOtp(normalized, AuthOtpPurpose.CLIENT_LOGIN_REGISTER, otp);

    const variants = phoneLookupVariants(normalized);
    const existing = await this.authRepository.findUserByPhoneVariants(variants);

    if (existing) {
      if (existing.role === Role.WORKER) {
        throw new ConflictException({
          message:
            'Ye mobile number Ustaad account ke saath registered hai. Ustaad Login use karein.',
          error: 'PHONE_IS_WORKER',
        });
      }
      // A successful OTP verification just proved control of this phone
      // right now, regardless of how the account was originally created.
      await this.authRepository.markPhoneVerified(existing.id);
      const profile = await this._getProfileName(existing.id, existing.role);
      return this._buildAuthResponse(
        existing.id,
        existing.phone,
        existing.role,
        profile.firstName,
        profile.lastName,
        profile.verificationStatus,
      );
    }

    const { firstName, lastName } = this._splitFullName(fullName);
    let user;
    try {
      user = await this.authRepository.createUserWithProfile({
        phone: normalized,
        passwordHash: null,
        firstName,
        lastName,
        role: Role.CLIENT,
        phoneVerified: true,
      });
    } catch (err) {
      // Two concurrent OTP verifications for the same brand-new number both
      // reaching this point — the `phone` unique constraint lets exactly one
      // insert win; the loser just logs into the account the winner created,
      // instead of failing, so no duplicate account and no user-facing error.
      if (
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === 'P2002'
      ) {
        const winner = await this.authRepository.findUserByPhoneVariants(variants);
        if (winner) {
          await this.authRepository.markPhoneVerified(winner.id);
          const profile = await this._getProfileName(winner.id, winner.role);
          return this._buildAuthResponse(
            winner.id,
            winner.phone,
            winner.role,
            profile.firstName,
            profile.lastName,
            profile.verificationStatus,
          );
        }
      }
      throw err;
    }

    return this._buildAuthResponse(user.id, user.phone, user.role, firstName, lastName);
  }

  // ── Client password fallback (alongside the OTP flow above) ────────────

  /**
   * POST /auth/client/phone-check — drives which sub-form the Client auth
   * page shows (login / register / Ustaad-redirect) before any password is
   * typed. Deliberately not enumeration-safe: telling the UI "this number
   * already has an account" is the entire point, exactly like the OTP flow
   * already reveals the same classification after verification — this just
   * does it a step earlier, without requiring OTP possession first.
   */
  async checkClientPhoneStatus(
    rawPhone: string,
  ): Promise<{ status: 'CLIENT' | 'WORKER' | 'NEW' }> {
    this._assertNotSupportAccount(rawPhone);
    const normalized = normalizePakistaniPhone(rawPhone);
    if (!normalized) {
      throw new BadRequestException({
        message: 'Sahi Pakistani mobile number likhein.',
        error: 'INVALID_PHONE',
      });
    }
    const user = await this.authRepository.findUserByPhoneVariants(
      phoneLookupVariants(normalized),
    );
    if (!user) return { status: 'NEW' };
    return { status: user.role === Role.WORKER ? 'WORKER' : 'CLIENT' };
  }

  /** POST /auth/client/password-login — existing CLIENT only. */
  async clientPasswordLogin(
    rawPhone: string,
    password: string,
  ): Promise<AuthResponseDto> {
    this._assertNotSupportAccount(rawPhone);
    const normalized = normalizePakistaniPhone(rawPhone);
    if (!normalized) {
      throw new BadRequestException({
        message: 'Sahi Pakistani mobile number likhein.',
        error: 'INVALID_PHONE',
      });
    }

    const user = await this.authRepository.findUserByPhoneVariants(
      phoneLookupVariants(normalized),
    );
    if (!user || user.deletedAt !== null) {
      throw new UnauthorizedException('Invalid phone number or password');
    }
    if (user.role === Role.WORKER) {
      throw new ConflictException({
        message:
          'Ye mobile number Ustaad account ke saath registered hai. Ustaad Login use karein.',
        error: 'PHONE_IS_WORKER',
      });
    }
    if (!user.isActive) {
      throw new ForbiddenException('Account is deactivated');
    }

    const passwordMatch = await bcrypt.compare(
      password,
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

  /**
   * POST /auth/client/password-register — new CLIENT only. The account is
   * created `phoneVerified: false` (schema default, not passed explicitly)
   * since no OTP was ever verified for this phone — never claim otherwise.
   */
  async clientPasswordRegister(
    fullName: string,
    rawPhone: string,
    password: string,
  ): Promise<AuthResponseDto> {
    this._assertNotSupportAccount(rawPhone);
    const normalized = normalizePakistaniPhone(rawPhone);
    if (!normalized) {
      throw new BadRequestException({
        message: 'Sahi Pakistani mobile number likhein.',
        error: 'INVALID_PHONE',
      });
    }

    const variants = phoneLookupVariants(normalized);
    const existing = await this.authRepository.findUserByPhoneVariants(variants);
    if (existing) {
      if (existing.role === Role.WORKER) {
        throw new ConflictException({
          message:
            'Ye mobile number Ustaad account ke saath registered hai. Ustaad Login use karein.',
          error: 'PHONE_IS_WORKER',
        });
      }
      throw new ConflictException({
        message: 'Ye number pehle se Client account ke saath registered hai. Login karein.',
        error: 'PHONE_IS_CLIENT',
      });
    }

    const { firstName, lastName } = this._splitFullName(fullName);
    const passwordHash = await bcrypt.hash(password, 12);

    let user;
    try {
      user = await this.authRepository.createUserWithProfile({
        phone: normalized,
        passwordHash,
        firstName,
        lastName,
        role: Role.CLIENT,
      });
    } catch (err) {
      // Same concurrent-registration race as clientOtpLoginOrRegister: the
      // loser logs into whichever account won the insert instead of
      // failing, so two near-simultaneous registrations never produce a
      // duplicate account or a user-facing error.
      if (
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === 'P2002'
      ) {
        const winner = await this.authRepository.findUserByPhoneVariants(variants);
        if (winner) {
          const profile = await this._getProfileName(winner.id, winner.role);
          return this._buildAuthResponse(
            winner.id,
            winner.phone,
            winner.role,
            profile.firstName,
            profile.lastName,
            profile.verificationStatus,
          );
        }
      }
      throw err;
    }

    return this._buildAuthResponse(user.id, user.phone, user.role, firstName, lastName);
  }

  /** POST /auth/worker/otp-register — OTP-verified Ustaad registration. */
  async workerOtpRegister(
    fullName: string,
    rawPhone: string,
    otp: string,
    password: string,
    categoryId: string,
  ): Promise<AuthResponseDto> {
    this._assertNotSupportAccount(rawPhone);
    const normalized = normalizePakistaniPhone(rawPhone);
    if (!normalized) {
      throw new BadRequestException({
        message: 'Sahi Pakistani mobile number likhein.',
        error: 'INVALID_PHONE',
      });
    }

    await this._verifyAuthOtp(normalized, AuthOtpPurpose.WORKER_REGISTER, otp);

    const variants = phoneLookupVariants(normalized);
    const existing = await this.authRepository.findUserByPhoneVariants(variants);
    if (existing) {
      if (existing.role === Role.WORKER) {
        throw new ConflictException({
          message: 'Is number ka Ustaad account pehle se mojood hai. Login karein.',
          error: 'PHONE_IS_WORKER',
        });
      }
      throw new ConflictException({
        message: 'Ye number Client account ke saath registered hai.',
        error: 'PHONE_IS_CLIENT',
      });
    }

    const { firstName, lastName } = this._splitFullName(fullName);
    const passwordHash = await bcrypt.hash(password, 12);

    let user;
    try {
      user = await this.authRepository.createUserWithProfile({
        phone: normalized,
        passwordHash,
        firstName,
        lastName,
        role: Role.WORKER,
        categoryId,
        phoneVerified: true,
      });
    } catch (err) {
      if (
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === 'P2002'
      ) {
        throw new ConflictException({
          message: 'Is number ka Ustaad account pehle se mojood hai. Login karein.',
          error: 'PHONE_IS_WORKER',
        });
      }
      throw err;
    }

    return this._buildAuthResponse(
      user.id,
      user.phone,
      user.role,
      firstName,
      lastName,
      'PENDING',
    );
  }

  /** POST /auth/worker/otp-login — existing Ustaad, OTP instead of password. */
  async workerOtpLogin(rawPhone: string, otp: string): Promise<AuthResponseDto> {
    this._assertNotSupportAccount(rawPhone);
    const normalized = normalizePakistaniPhone(rawPhone);
    if (!normalized) {
      throw new BadRequestException({
        message: 'Sahi Pakistani mobile number likhein.',
        error: 'INVALID_PHONE',
      });
    }

    await this._verifyAuthOtp(normalized, AuthOtpPurpose.WORKER_LOGIN, otp);

    const variants = phoneLookupVariants(normalized);
    const user = await this.authRepository.findUserByPhoneVariants(variants);
    if (!user || user.role !== Role.WORKER || user.deletedAt !== null) {
      throw new UnauthorizedException({
        message: 'Is number ka Ustaad account nahi mila.',
        error: 'WORKER_NOT_FOUND',
      });
    }
    if (!user.isActive) {
      throw new ForbiddenException('Account is deactivated');
    }

    await this.authRepository.markPhoneVerified(user.id);
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
}
