import {
  Controller,
  Post,
  Get,
  Patch,
  Delete,
  Body,
  Ip,
  Req,
  HttpCode,
  HttpStatus,
  UseGuards,
  UploadedFile,
  UseInterceptors,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Request } from 'express';
import { AuthService } from './auth.service';
import { maskPhone } from '../../common/utils/phone.util';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { ForgotPasswordRequestDto } from './dto/forgot-password-request.dto';
import { ForgotPasswordResetDto } from './dto/forgot-password-reset.dto';
import { RequestOtpDto } from './dto/request-otp.dto';
import { ClientOtpLoginDto } from './dto/client-otp-login.dto';
import { WorkerOtpRegisterDto } from './dto/worker-otp-register.dto';
import { WorkerOtpVerifyDto } from './dto/worker-otp-verify.dto';
import { ClientPhoneCheckDto } from './dto/client-phone-check.dto';
import { ClientPasswordLoginDto } from './dto/client-password-login.dto';
import { ClientPasswordRegisterDto } from './dto/client-password-register.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { BypassClientSuspension } from '../../common/decorators/bypass-client-suspension.decorator';
import { SaveFcmTokenDto } from './dto/save-fcm-token.dto';
import { Role } from '../../common/enums/role.enum';

const ACCOUNT_DELETE_CONFIRMATION = 'DELETE_MY_ACCOUNT';

type AccountDeleteAuditOutcome =
  | 'ATTEMPT_ACCEPTED'
  | 'ATTEMPT_REJECTED'
  | 'DELETION_SUCCESS';

@Controller('auth')
export class AuthController {
  private readonly logger = new Logger(AuthController.name);

  constructor(private readonly authService: AuthService) {}

  @Post('register')
  @HttpCode(HttpStatus.CREATED)
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }
  @Post('admin/login')
  @HttpCode(HttpStatus.OK)
  adminLogin(@Body() dto: LoginDto) {
    return this.authService.adminLogin(dto);
  }
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refreshTokens(dto);
  }

  @Post('logout')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  @BypassClientSuspension()
  logout(
    @CurrentUser() user: { id: string },
    @Body('refreshToken') refreshToken?: string,
  ) {
    return this.authService.logout(user.id, refreshToken);
  }

  /** A suspended CLIENT must still be able to identify their own restricted
   * state — this is how the app's router even learns to show the
   * restricted-account screen in the first place. */
  @Get('me')
  @UseGuards(JwtAuthGuard)
  @BypassClientSuspension()
  getMe(@CurrentUser() user: { id: string }) {
    return this.authService.getMe(user.id);
  }

  /** POST /auth/fcm-token — save device FCM token for push notifications */
  @Post('fcm-token')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  saveFcmToken(
    @CurrentUser() user: { id: string },
    @Body() dto: SaveFcmTokenDto,
  ) {
    return this.authService.saveFcmToken(user.id, dto.token, dto.locale);
  }

  /** POST /auth/otp/request — public, purpose-scoped OTP for the SMS flows below. */
  @Post('otp/request')
  @HttpCode(HttpStatus.OK)
  requestOtp(@Body() dto: RequestOtpDto, @Req() req: Request) {
    // Opt-in structured debug logging for the resolved rate-limit IP — off
    // by default so it never spams production, toggled with OTP_IP_DEBUG=true
    // to verify `trust proxy` is resolving the real client address after a
    // deploy without needing a code change. Deliberately carries no OTP and
    // no full phone number.
    if (process.env.OTP_IP_DEBUG === 'true') {
      this.logger.debug(
        `OTP IP check ip=${req.ip} xff=${req.headers['x-forwarded-for'] ?? ''} ` +
          `phone=${maskPhone(dto.phone)} purpose=${dto.purpose}`,
      );
    }

    return this.authService.requestOtp(dto.phone, dto.purpose, req.ip ?? '');
  }

  /**
   * POST /auth/client/otp-login — Client LOGIN by one-time code.
   *
   * Authentication only: existing CLIENT accounts. It never creates a user and
   * never accepts a name — registration owns both (see client/password-register
   * below). An unknown number, a Worker-owned number and a deleted account all
   * get the same privacy-safe rejection.
   */
  @Post('client/otp-login')
  @HttpCode(HttpStatus.OK)
  clientOtpLogin(@Body() dto: ClientOtpLoginDto) {
    return this.authService.clientOtpLogin(dto.phone, dto.otp);
  }

  /**
   * POST /auth/worker/otp-verify — Step 2 of Ustaad registration.
   *
   * Consumes the registration code and returns a short-lived token that
   * authorises finishing the registration. Creates nothing: no user, no
   * profile, no session, and the token cannot authenticate any other request.
   */
  @Post('worker/otp-verify')
  @HttpCode(HttpStatus.OK)
  workerOtpVerify(@Body() dto: WorkerOtpVerifyDto) {
    return this.authService.workerOtpVerify(dto.phone, dto.otp);
  }

  /** POST /auth/worker/otp-register — creates the Ustaad account. */
  @Post('worker/otp-register')
  @HttpCode(HttpStatus.CREATED)
  workerOtpRegister(@Body() dto: WorkerOtpRegisterDto) {
    return this.authService.workerOtpRegister(
      dto.fullName,
      dto.phone,
      dto.otp,
      dto.password,
      dto.categoryId,
      dto.registrationToken,
    );
  }

  // POST /auth/worker/otp-login was REMOVED.
  //
  // Ustaad login is phone + password only (POST /auth/login, which already
  // bcrypt-compares the password and issues the normal tokens). That route let
  // an Ustaad authenticate with an SMS code and NO password, so leaving it
  // routed would have kept a password-free login path reachable by any API
  // client or older app build — the exact thing removing login OTP is meant to
  // stop.
  //
  // OTP itself is untouched everywhere else: Client login/registration
  // (/auth/client/otp-login), Ustaad REGISTRATION (/auth/worker/otp-register)
  // and password reset (/auth/forgot-password/*) all still require it.

  @Post('forgot-password/request')
  @HttpCode(HttpStatus.OK)
  forgotPasswordRequest(@Body() dto: ForgotPasswordRequestDto) {
    return this.authService.forgotPasswordRequest(dto);
  }

  @Post('forgot-password/reset')
  @HttpCode(HttpStatus.OK)
  forgotPasswordReset(@Body() dto: ForgotPasswordResetDto) {
    return this.authService.forgotPasswordReset(dto);
  }

  /**
   * POST /auth/client/phone-check — tells the Client auth page's password
   * mode which sub-form to show before any password is entered.
   */
  @Post('client/phone-check')
  @HttpCode(HttpStatus.OK)
  checkClientPhoneStatus(@Body() dto: ClientPhoneCheckDto) {
    return this.authService.checkClientPhoneStatus(dto.phone);
  }

  /** POST /auth/client/password-login — existing Client, password fallback. */
  @Post('client/password-login')
  @HttpCode(HttpStatus.OK)
  clientPasswordLogin(@Body() dto: ClientPasswordLoginDto) {
    return this.authService.clientPasswordLogin(dto.phone, dto.password);
  }

  /** POST /auth/client/password-register — new Client, password fallback. */
  @Post('client/password-register')
  @HttpCode(HttpStatus.CREATED)
  clientPasswordRegister(@Body() dto: ClientPasswordRegisterDto) {
    return this.authService.clientPasswordRegister(
      dto.fullName,
      dto.phone,
      dto.password,
      dto.otp,
    );
  }

  /** POST /auth/client/forgot-password/request — Client-only password reset OTP. */
  @Post('client/forgot-password/request')
  @HttpCode(HttpStatus.OK)
  clientForgotPasswordRequest(@Body() dto: ForgotPasswordRequestDto) {
    return this.authService.clientForgotPasswordRequest(dto);
  }

  /**
   * POST /auth/client/forgot-password/reset — reuses the same
   * `forgotPasswordReset` as the Worker flow: it's already scoped purely by
   * the OTP row's `userId` (established at request time), so no role
   * parameter is needed here.
   */
  @Post('client/forgot-password/reset')
  @HttpCode(HttpStatus.OK)
  clientForgotPasswordReset(@Body() dto: ForgotPasswordResetDto) {
    return this.authService.forgotPasswordReset(dto);
  }

  private logAccountDeleteAudit(
    user: { id: string; role: Role },
    request: Request,
    outcome: AccountDeleteAuditOutcome,
  ): void {
    const rawUserAgent = request.headers['user-agent'];
    const userAgent =
      typeof rawUserAgent === 'string'
        ? rawUserAgent.replace(/[\r\n]/g, ' ').slice(0, 256)
        : null;
    const entry = {
      userId: user.id,
      role: user.role,
      timestamp: new Date().toISOString(),
      ip: request.ip ?? null,
      userAgent,
      path: request.path || request.url.split('?')[0],
      outcome,
    };

    const message = JSON.stringify(entry);
    if (outcome === 'ATTEMPT_REJECTED') {
      this.logger.warn(message);
    } else {
      this.logger.log(message);
    }
  }

  /**
   * DELETE /auth/account — soft-delete the authenticated user's account.
   *
   * The literal confirmation body is deliberately checked here, before the
   * service can be reached. Older app builds send a bare DELETE and therefore
   * fail closed instead of being able to delete an account silently.
   */
  @Delete('account')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  async deleteAccount(
    @CurrentUser() user: { id: string; role: Role },
    @Body() body: unknown,
    @Req() request: Request,
  ) {
    const confirmed =
      typeof body === 'object' &&
      body !== null &&
      (body as Record<string, unknown>).confirmation ===
        ACCOUNT_DELETE_CONFIRMATION;

    this.logAccountDeleteAudit(
      user,
      request,
      confirmed ? 'ATTEMPT_ACCEPTED' : 'ATTEMPT_REJECTED',
    );

    if (!confirmed) {
      throw new BadRequestException({
        message: 'Explicit account-deletion confirmation is required.',
        error: 'ACCOUNT_DELETE_CONFIRMATION_REQUIRED',
      });
    }

    const result = await this.authService.deleteAccount(user.id);
    this.logAccountDeleteAudit(user, request, 'DELETION_SUCCESS');
    return result;
  }

  /** GET /auth/avatar — fetch current profile avatar URL */
  @Get('avatar')
  @UseGuards(JwtAuthGuard)
  getAvatarUrl(@CurrentUser() user: { id: string }) {
    return this.authService.getAvatarUrl(user.id);
  }

  /** PATCH /auth/avatar — upload a new profile picture (multipart, max 5 MB) */
  @Patch('avatar')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: 5 * 1024 * 1024 },
      fileFilter: (_req, file, cb) => {
        const allowed = ['image/jpeg', 'image/png', 'image/webp', 'image/heic'];
        if (allowed.includes(file.mimetype)) {
          cb(null, true);
        } else {
          cb(
            new BadRequestException(
              `Unsupported avatar type: ${file.mimetype}. Allowed: jpeg, png, webp, heic.`,
            ),
            false,
          );
        }
      },
    }),
  )
  uploadAvatar(
    @CurrentUser() user: { id: string },
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) throw new BadRequestException('No file uploaded');
    return this.authService.uploadAvatar(
      user.id,
      file.buffer,
      file.originalname,
      file.mimetype,
    );
  }
}
