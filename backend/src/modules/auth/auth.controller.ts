import {
  Controller,
  Post,
  Get,
  Patch,
  Delete,
  Body,
  Ip,
  HttpCode,
  HttpStatus,
  UseGuards,
  UploadedFile,
  UseInterceptors,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { ForgotPasswordRequestDto } from './dto/forgot-password-request.dto';
import { ForgotPasswordResetDto } from './dto/forgot-password-reset.dto';
import { RequestOtpDto } from './dto/request-otp.dto';
import { ClientOtpLoginDto } from './dto/client-otp-login.dto';
import { WorkerOtpRegisterDto } from './dto/worker-otp-register.dto';
import { WorkerOtpLoginDto } from './dto/worker-otp-login.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('auth')
export class AuthController {
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

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refreshTokens(dto);
  }

  @Post('logout')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  logout(
    @CurrentUser() user: { id: string },
    @Body('refreshToken') refreshToken?: string,
  ) {
    return this.authService.logout(user.id, refreshToken);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  getMe(@CurrentUser() user: { id: string }) {
    return this.authService.getMe(user.id);
  }

  /** POST /auth/fcm-token — save device FCM token for push notifications */
  @Post('fcm-token')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  saveFcmToken(
    @CurrentUser() user: { id: string },
    @Body('token') token: string,
  ) {
    return this.authService.saveFcmToken(user.id, token);
  }

  /** POST /auth/otp/request — public, purpose-scoped OTP for the SMS flows below. */
  @Post('otp/request')
  @HttpCode(HttpStatus.OK)
  requestOtp(@Body() dto: RequestOtpDto, @Ip() ip: string) {
    return this.authService.requestOtp(dto.phone, dto.purpose, ip);
  }

  /**
   * POST /auth/client/otp-login — combined Client login/registration. The
   * backend (not Flutter) decides login vs. register vs. reject-as-Worker.
   */
  @Post('client/otp-login')
  @HttpCode(HttpStatus.OK)
  clientOtpLogin(@Body() dto: ClientOtpLoginDto) {
    return this.authService.clientOtpLoginOrRegister(
      dto.fullName,
      dto.phone,
      dto.otp,
    );
  }

  /** POST /auth/worker/otp-register — OTP-verified new Ustaad registration. */
  @Post('worker/otp-register')
  @HttpCode(HttpStatus.CREATED)
  workerOtpRegister(@Body() dto: WorkerOtpRegisterDto) {
    return this.authService.workerOtpRegister(
      dto.fullName,
      dto.phone,
      dto.otp,
      dto.password,
      dto.categoryId,
    );
  }

  /** POST /auth/worker/otp-login — existing Ustaad, OTP instead of password. */
  @Post('worker/otp-login')
  @HttpCode(HttpStatus.OK)
  workerOtpLogin(@Body() dto: WorkerOtpLoginDto) {
    return this.authService.workerOtpLogin(dto.phone, dto.otp);
  }

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

  /** DELETE /auth/account — soft-delete the authenticated user's account */
  @Delete('account')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  deleteAccount(@CurrentUser() user: { id: string }) {
    return this.authService.deleteAccount(user.id);
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
