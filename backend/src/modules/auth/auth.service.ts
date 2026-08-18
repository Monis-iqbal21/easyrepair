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
import { WorkersService } from '../workers/workers.service';
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
  maskPhone,
} from '../../common/utils/phone.util';
import {
  encryptOtp,
  OtpEncryptionKeyError,
} from '../../common/utils/otp-encryption.util';

const OTP_EXPIRY_MS = 5 * 60 * 1000;
const OTP_RESEND_COOLDOWN_MS = 60 * 1000;
const OTP_MAX_ATTEMPTS = 5;
const OTP_MAX_PER_PHONE_PER_WINDOW = 5;

/**
 * How long a just-rotated refresh token stays honourable after being
 * superseded. Exists purely to recover a client that crashed/was killed
 * between this backend committing a rotation and Flutter persisting the new
 * pair locally — see AuthService.refreshTokens. Deliberately short: reusing
 * a superseded token within this window never grants anything beyond what
 * the rotation that already happened granted (no new refresh token is
 * issued, only a fresh access token bound to the existing replacement), so
 * it does not meaningfully extend a stolen token's usefulness.
 */
const REFRESH_TOKEN_GRACE_MS = 60 * 1000;

const DURATION_UNIT_MS: Record<string, number> = {
  s: 1000,
  m: 60 * 1000,
  h: 60 * 60 * 1000,
  d: 24 * 60 * 60 * 1000,
  w: 7 * 24 * 60 * 60 * 1000,
  y: 365 * 24 * 60 * 60 * 1000,
};

/** Parses a duration string like '30d', '15m', '1y' into milliseconds. */
function parseDurationMs(value: string): number {
  const match = /^(\d+)\s*([smhdwy])$/i.exec(value.trim());
  if (!match) {
    throw new Error(`Invalid duration string: "${value}"`);
  }
  const [, amount, unit] = match;
  return Number(amount) * DURATION_UNIT_MS[unit.toLowerCase()];
}
/**
 * Abuse backstop only — the per-phone cap above is the precise control.
 *
 * Pakistani mobile carriers put large numbers of subscribers behind CGNAT, so
 * many unrelated Ustaads legitimately share one public IP. A cap tight enough
 * to be a per-user limit would lock those users out of registering at all.
 */
const OTP_MAX_PER_IP_PER_WINDOW = 60;
const OTP_RATE_WINDOW_MS = 30 * 60 * 1000;

/**
 * Whether [ip] identifies a single caller well enough to rate-limit on.
 *
 * Behind a proxy the socket address is the load balancer's, which is the same
 * for every user on the platform — counting those into one bucket turns a
 * per-IP abuse cap into a global outage. `trust proxy` in main.ts is what
 * makes the real client address available; this is the belt to that braces,
 * so a future proxy misconfiguration degrades to "per-phone limits only"
 * instead of locking out every Ustaad at once.
 */
function isUsableClientIp(ip: string | null | undefined): boolean {
  if (!ip) return false;
  const bare = ip.replace(/^::ffff:/, '').trim();
  if (!bare || bare === '::1' || bare === '127.0.0.1') return false;
  if (/^10\./.test(bare)) return false;
  if (/^192\.168\./.test(bare)) return false;
  if (/^172\.(1[6-9]|2[0-9]|3[01])\./.test(bare)) return false;
  if (/^fc00:|^fd00:/i.test(bare)) return false;
  return true;
}

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
    private readonly workersService: WorkersService,
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

    // New workers always start as PENDING verification and ACTIVE status
    // (WorkerProfile.status schema default) — hardcoded here rather than
    // re-queried, since createUserWithProfile just created exactly that row.
    const verificationStatus =
      (dto.role as Role) === Role.WORKER ? 'PENDING' : undefined;
    const workerStatus =
      (dto.role as Role) === Role.WORKER ? 'ACTIVE' : undefined;
    return this._buildAuthResponse(
      user.id,
      user.phone,
      user.role,
      dto.firstName,
      dto.lastName,
      verificationStatus,
      workerStatus,
    );
  }

  /**
   * POST /auth/login — Worker password login. This is the only real caller
   * of this endpoint (the Worker login page's password field); scoped to
   * WORKER only so a Client's correct phone+password can never silently
   * authenticate through the Worker screen. A Client-owned or genuinely
   * nonexistent phone gets the same role-privacy-safe rejection as every
   * other login path — see `_phoneNotRegisteredError`.
   */
  async login(dto: LoginDto): Promise<AuthResponseDto> {
    this._assertNotSupportAccount(dto.phone);
    const user = await this.authRepository.findUserByPhone(dto.phone);
    if (!user || user.deletedAt !== null || user.role !== Role.WORKER) {
      throw this._phoneNotRegisteredError();
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
      profile.workerStatus,
      user.accountStatus,
    );
  }
  /**
   * POST /auth/admin/login — Admin web password login only.
   *
   * This endpoint is intentionally separate from the Worker password-login
   * endpoint so Client/Worker role-privacy rules remain unchanged.
   */
  async adminLogin(dto: LoginDto): Promise<AuthResponseDto> {
    this._assertNotSupportAccount(dto.phone);

    const user = await this.authRepository.findUserByPhone(dto.phone);

    if (!user || user.deletedAt !== null || user.role !== Role.ADMIN) {
      throw this._phoneNotRegisteredError();
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

    return this._buildAuthResponse(
      user.id,
      user.phone,
      user.role,
      '',
      '',
      undefined,
      undefined,
      user.accountStatus,
    );
  }
  async refreshTokens(dto: RefreshTokenDto): Promise<AuthResponseDto> {
    const stored = await this.authRepository.findRefreshToken(dto.refreshToken);
    if (!stored) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    // This exact token was already rotated away by an earlier refresh.
    // Within a short grace window this almost always means the client
    // crashed/was killed after we committed that rotation but before it
    // could persist the new pair locally — resolve to the already-issued
    // replacement instead of rejecting, so the retry recovers the session
    // instead of stranding the device. Outside the grace window (or if the
    // chain has nowhere further to go), this is a genuine rejection.
    if (stored.replacedByToken) {
      return this._reissueFromGraceWindow(
        stored.replacedByToken,
        stored.supersededAt,
      );
    }

    if (stored.expiresAt < new Date()) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    const user = await this.authRepository.findUserById(stored.userId);
    if (!user || !user.isActive) {
      throw new UnauthorizedException('User not found or inactive');
    }

    const profile = await this._getProfileName(user.id, user.role);
    const accessToken = this._signAccessToken(user.id, user.phone, user.role);
    const newRefreshToken = uuidv4();

    await this.authRepository.rotateRefreshToken(
      stored.token,
      newRefreshToken,
      user.id,
      this._refreshTokenExpiresAt(),
    );

    void this.chatService.ensureSupportConversation(user.id, user.role);

    return {
      accessToken,
      refreshToken: newRefreshToken,
      user: {
        id: user.id,
        phone: user.phone,
        role: user.role,
        firstName: profile.firstName,
        lastName: profile.lastName,
        verificationStatus: profile.verificationStatus,
        workerStatus: profile.workerStatus,
        accountStatus: user.accountStatus,
      },
    };
  }

  /**
   * Re-resolves a refresh call that presented an already-superseded token.
   * Never rotates again here — that would let a retry loop keep spawning
   * new tokens from one stale presentation. Only ever hands back a fresh
   * access token bound to the SAME replacement token that a successful
   * first attempt would already have produced.
   */
  private async _reissueFromGraceWindow(
    replacedByToken: string,
    supersededAt: Date | null,
  ): Promise<AuthResponseDto> {
    const withinGrace =
      supersededAt !== null &&
      Date.now() - supersededAt.getTime() < REFRESH_TOKEN_GRACE_MS;
    if (!withinGrace) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    const replacement =
      await this.authRepository.findRefreshToken(replacedByToken);
    if (!replacement || replacement.expiresAt < new Date()) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    const user = await this.authRepository.findUserById(replacement.userId);
    if (!user || !user.isActive) {
      throw new UnauthorizedException('User not found or inactive');
    }

    const profile = await this._getProfileName(user.id, user.role);
    const accessToken = this._signAccessToken(user.id, user.phone, user.role);

    return {
      accessToken,
      refreshToken: replacement.token,
      user: {
        id: user.id,
        phone: user.phone,
        role: user.role,
        firstName: profile.firstName,
        lastName: profile.lastName,
        verificationStatus: profile.verificationStatus,
        workerStatus: profile.workerStatus,
        accountStatus: user.accountStatus,
      },
    };
  }

  /**
   * Authoritative server-side session cleanup. Order matters: the FCM token
   * is detached BEFORE any forced-offline notification is created, so that
   * notification is persisted (for the account's history) but never pushed
   * to the device that just logged out — NotificationsService reads the
   * token fresh from the DB at send time. CLIENT accounts pass through
   * `handleWorkerLogout` as a no-op (no WorkerProfile to act on).
   */
  async logout(userId: string, refreshToken?: string): Promise<void> {
    await this.authRepository.clearFcmToken(userId).catch(() => {});

    if (refreshToken) {
      await this.authRepository
        .deleteRefreshToken(refreshToken)
        .catch(() => {});
    } else {
      await this.authRepository.deleteAllRefreshTokens(userId);
    }

    await this.workersService.handleWorkerLogout(userId).catch((err) => {
      this.logger.warn(
        `[logout] worker presence cleanup failed for userId=${userId}: ${(err as Error)?.message}`,
      );
    });
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
      workerStatus: profile.workerStatus,
      accountStatus: user.accountStatus,
    };
  }

  private async _getProfileName(
    userId: string,
    role: Role,
  ): Promise<{
    firstName: string;
    lastName: string;
    verificationStatus?: string;
    /** Only ever set for WORKER — the central Worker-suspension routing gate
     * in the app reads this on every login/session-restore/refresh. */
    workerStatus?: string;
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
        workerStatus: p.status,
      };
    }
  }

  /**
   * Stable, role-privacy-safe rejection for a login attempt against a phone
   * that either doesn't exist at all or belongs to the OPPOSITE role. These
   * two cases must be indistinguishable to the caller — see the class doc
   * above `clientPasswordLogin` for why. `message` is deliberately empty:
   * Flutter's `failureCodeMessage()` renders `error` through
   * `AppLocalizations` instead, so the same rejection reads correctly in
   * English, Urdu and Roman Urdu rather than a single hardcoded sentence.
   */
  private _phoneNotRegisteredError(): UnauthorizedException {
    return new UnauthorizedException({
      message: '',
      error: 'PHONE_NOT_REGISTERED',
    });
  }

  /**
   * Stable, role-privacy-safe rejection for a registration attempt against a
   * phone that already has an account — regardless of which role owns it.
   * `User.phone` is globally unique, so this is also what a same-role
   * duplicate hits. See `_phoneNotRegisteredError` for the empty-message
   * reasoning.
   */
  private _phoneAlreadyRegisteredError(): ConflictException {
    return new ConflictException({
      message: '',
      error: 'PHONE_ALREADY_REGISTERED',
    });
  }

  private _signAccessToken(userId: string, phone: string, role: Role): string {
    return this.jwtService.sign({ sub: userId, phone, role } as object, {
      expiresIn: this.config.getOrThrow<string>('jwt.accessExpires') as
        | `${number}${'s' | 'm' | 'h' | 'd' | 'w' | 'y'}`
        | number,
    });
  }

  /** Refresh-token lifetime, driven by JWT_REFRESH_EXPIRES (default 30d). */
  private _refreshTokenExpiresAt(): Date {
    const raw = this.config.getOrThrow<string>('jwt.refreshExpires');
    return new Date(Date.now() + parseDurationMs(raw));
  }

  private async _buildAuthResponse(
    userId: string,
    phone: string,
    role: Role,
    firstName: string,
    lastName: string,
    verificationStatus?: string,
    workerStatus?: string,
    // Defaults to ACTIVE — every call site that just created a brand-new
    // user relies on this (accountStatus's schema default is ACTIVE too),
    // so only call sites logging into an already-existing user pass their
    // actual current value explicitly.
    accountStatus: string = 'ACTIVE',
  ): Promise<AuthResponseDto> {
    const accessToken = this._signAccessToken(userId, phone, role);

    const refreshToken = uuidv4();
    await this.authRepository.createRefreshToken(
      userId,
      refreshToken,
      this._refreshTokenExpiresAt(),
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
        workerStatus,
        accountStatus,
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
      this.logger.warn(
        `Password-reset OTP rate limit hit for ${maskPhone(normalized)}`,
      );
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
        this.logger.warn(
          `Password-reset SMS OTP send failed for ${maskPhone(normalized)}`,
        );
        if (options.surfaceSmsFailure) throw sendFailureError;
      }
    } else if (process.env.NODE_ENV !== 'production') {
      this.logger.log(
        `[DEV OTP] phone=${maskPhone(normalized)} code=***${otp.slice(-2)}`,
      );
    } else {
      this.logger.warn('SMS OTP not configured — forgot password OTP not sent');
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

  /**
   * Soft-delete only — see AuthRepository.softDeleteUser for exactly what
   * gets written and why legal/business records are never touched.
   *
   * Deleted-phone reuse policy: `User.phone` is `@unique` and this delete
   * never clears/changes it, so the number stays permanently reserved by
   * the deleted row — a repeat registration attempt with the same number
   * hits the unique constraint and gets the standard "already registered"
   * rejection, never a fresh account. This is the existing, unchanged
   * architecture (true for every account, not something this chunk
   * introduces) — reported here per the Chunk 4 audit requirement, not
   * altered. Every login path (including the CLIENT OTP combined
   * login-or-register flow, fixed alongside this) rejects a soft-deleted
   * account with the same privacy-safe "not registered" message a
   * genuinely nonexistent number gets.
   */
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
    const trackableIp = isUsableClientIp(ip) ? ip : null;
    const [byPhone, byIp] = await Promise.all([
      this.authRepository.countRecentAuthOtpByPhone(normalized, purpose, since),
      trackableIp
        ? this.authRepository.countRecentAuthOtpByIp(trackableIp, since)
        : Promise.resolve(0),
    ]);
    if (
      byPhone >= OTP_MAX_PER_PHONE_PER_WINDOW ||
      byIp >= OTP_MAX_PER_IP_PER_WINDOW
    ) {
      throw new BadRequestException({
        message:
          'Bohat zyada koshishein. Thori dair baad dobara koshish karein.',
        error: 'OTP_RATE_LIMITED',
      });
    }

    const mostRecent = await this.authRepository.mostRecentAuthOtp(
      normalized,
      purpose,
    );
    if (mostRecent) {
      const elapsedMs = Date.now() - mostRecent.createdAt.getTime();
      if (elapsedMs < OTP_RESEND_COOLDOWN_MS) {
        // Ceil, never 0: the client's countdown must never show "0s left"
        // while the backend would still reject an immediate resend.
        const retryAfterSeconds = Math.ceil(
          (OTP_RESEND_COOLDOWN_MS - elapsedMs) / 1000,
        );
        throw new BadRequestException({
          message: 'Thori dair intezaar karein, phir dobara code mangwayein.',
          error: 'OTP_RESEND_TOO_SOON',
          retryAfterSeconds,
        });
      }
    }

    const otp = crypto.randomInt(100000, 1000000).toString();
    const otpHash = await bcrypt.hash(otp, 10);
    const expiresAt = new Date(Date.now() + OTP_EXPIRY_MS);

    // Admin-reveal copy only — never read by verification. Encryption
    // failure (key unset/malformed) must never block a real OTP request, so
    // this degrades to "not revealable" rather than throwing.
    let encrypted: { ciphertext: string; iv: string; tag: string } | null =
      null;
    try {
      encrypted = encryptOtp(
        otp,
        this.config.get<string>('otpAdmin.encryptionKey'),
      );
    } catch (err) {
      if (err instanceof OtpEncryptionKeyError) {
        this.logger.warn(
          `[requestOtp] admin-reveal unavailable: ${err.message}`,
        );
      } else {
        throw err;
      }
    }

    await this.authRepository.invalidatePreviousAuthOtps(normalized, purpose);
    const otpId = await this.authRepository.createAuthOtp({
      phone: normalized,
      purpose,
      otpHash,
      expiresAt,
      requestIp: trackableIp,
      otpCiphertext: encrypted?.ciphertext ?? null,
      otpCipherIv: encrypted?.iv ?? null,
      otpCipherTag: encrypted?.tag ?? null,
    });

    if (this.smsOtp.isConfigured) {
      const sent = await this.smsOtp.sendOtp(normalized, otp);
      if (!sent) {
        // The Ustaad never got this code, so it must not sit there burning
        // their 60s resend cooldown and their 5-per-30-minutes quota. Without
        // this, repeated provider hiccups lock a real user out for half an
        // hour over codes that were never delivered.
        await this.authRepository.deleteAuthOtp(otpId).catch(() => undefined);
        throw new ServiceUnavailableException({
          message: 'SMS bhejne mein masla hua. Dobara koshish karein.',
          error: 'SMS_SEND_FAILED',
        });
      }
      // Diagnostics only — never blocks the response either way.
      await this.authRepository.markSmsDispatched(otpId).catch(() => undefined);
    } else if (process.env.NODE_ENV !== 'production') {
      this.logger.log(
        `[DEV OTP] phone=${maskPhone(normalized)} purpose=${purpose} code=***${otp.slice(-2)}`,
      );
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

    await this._verifyAuthOtp(
      normalized,
      AuthOtpPurpose.CLIENT_LOGIN_REGISTER,
      otp,
    );

    const variants = phoneLookupVariants(normalized);
    const existing =
      await this.authRepository.findUserByPhoneVariants(variants);

    if (existing) {
      if (existing.role === Role.WORKER) {
        // checkClientPhoneStatus already classified this phone as 'NEW' to
        // the Client auth page (see below), so from the app's perspective
        // this OTP verification is a registration attempt that just
        // discovered the phone already has an account — same rejection a
        // genuine same-role duplicate gets, never revealing it's a Worker.
        throw this._phoneAlreadyRegisteredError();
      }
      // A soft-deleted CLIENT account must not be able to log back in via
      // OTP — same privacy-safe rejection every other login path gives a
      // deleted/nonexistent number. Phone numbers are deliberately reserved
      // (User.phone stays unique/occupied) rather than freed for reuse —
      // see the class-level note on deleted-phone reuse policy.
      if (existing.deletedAt !== null) {
        throw this._phoneNotRegisteredError();
      }
      if (!existing.isActive) {
        throw new ForbiddenException('Account is deactivated');
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
        profile.workerStatus,
        existing.accountStatus,
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
        const winner =
          await this.authRepository.findUserByPhoneVariants(variants);
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
            profile.workerStatus,
            winner.accountStatus,
          );
        }
      }
      throw err;
    }

    return this._buildAuthResponse(
      user.id,
      user.phone,
      user.role,
      firstName,
      lastName,
    );
  }

  // ── Client password fallback (alongside the OTP flow above) ────────────

  /**
   * POST /auth/client/phone-check — drives which sub-form the Client auth
   * page shows (login vs. register) before any password is typed.
   *
   * Role-privacy safe: a Worker-owned phone is reported exactly like a
   * genuinely new number ('NEW'), never as its own classification — the
   * Client page then shows the registration sub-form, and the actual
   * registration attempt correctly rejects with the generic "already
   * registered" outcome once it hits the real account (see
   * `clientPasswordRegister`). This intentionally reveals only whether a
   * CLIENT account already exists, never whether the number belongs to a
   * Worker.
   */
  async checkClientPhoneStatus(
    rawPhone: string,
  ): Promise<{ status: 'CLIENT' | 'NEW' }> {
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
    if (!user || user.role === Role.WORKER) return { status: 'NEW' };
    return { status: 'CLIENT' };
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
    // Wrong role and genuinely nonexistent are indistinguishable — both get
    // the same rejection. Only a real CLIENT account continues to a
    // password check, so "wrong password" (below) never gets conflated with
    // "this phone has no CLIENT account".
    if (!user || user.deletedAt !== null || user.role === Role.WORKER) {
      throw this._phoneNotRegisteredError();
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
      profile.workerStatus,
      user.accountStatus,
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
    const existing =
      await this.authRepository.findUserByPhoneVariants(variants);
    if (existing) {
      // Same rejection regardless of which role already owns the number —
      // User.phone is globally unique, so this is the only outcome that
      // never reveals whether the existing account is a Client or a Worker.
      throw this._phoneAlreadyRegisteredError();
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
        const winner =
          await this.authRepository.findUserByPhoneVariants(variants);
        if (winner) {
          const profile = await this._getProfileName(winner.id, winner.role);
          return this._buildAuthResponse(
            winner.id,
            winner.phone,
            winner.role,
            profile.firstName,
            profile.lastName,
            profile.verificationStatus,
            profile.workerStatus,
            winner.accountStatus,
          );
        }
      }
      throw err;
    }

    return this._buildAuthResponse(
      user.id,
      user.phone,
      user.role,
      firstName,
      lastName,
    );
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
    const existing =
      await this.authRepository.findUserByPhoneVariants(variants);
    if (existing) {
      // Same rejection regardless of which role already owns the number —
      // never reveals whether it's a Client or an existing Worker account.
      throw this._phoneAlreadyRegisteredError();
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
        throw this._phoneAlreadyRegisteredError();
      }
      throw err;
    }

    // New workers always start ACTIVE (WorkerProfile.status schema default)
    // — hardcoded rather than re-queried, since createUserWithProfile just
    // created exactly that row.
    return this._buildAuthResponse(
      user.id,
      user.phone,
      user.role,
      firstName,
      lastName,
      'PENDING',
      'ACTIVE',
    );
  }

  /** POST /auth/worker/otp-login — existing Ustaad, OTP instead of password. */
  async workerOtpLogin(
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

    await this._verifyAuthOtp(normalized, AuthOtpPurpose.WORKER_LOGIN, otp);

    const variants = phoneLookupVariants(normalized);
    const user = await this.authRepository.findUserByPhoneVariants(variants);
    // Wrong role and nonexistent are indistinguishable — same rejection as
    // every other login path, never revealing this phone belongs to a Client.
    if (!user || user.role !== Role.WORKER || user.deletedAt !== null) {
      throw this._phoneNotRegisteredError();
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
      profile.workerStatus,
      user.accountStatus,
    );
  }
}
