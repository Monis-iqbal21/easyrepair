import {
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';
import { AdminOtpService } from './admin-otp.service';
import { ListOtpQueryDto } from './dto/list-otp-query.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

/**
 * OTP Diagnostics — HIGH RISK. Independently enforces Role.ADMIN (never
 * relies on the admin web hiding this page from the sidebar): a Worker or
 * Client token is rejected by RolesGuard before either handler runs.
 */
@Controller('admin/otp')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminOtpController {
  constructor(private readonly adminOtpService: AdminOtpService) {}

  /** GET /admin/otp — recent OTP activity. Never returns otpHash or any encryption field. */
  @Get()
  list(@Query() query: ListOtpQueryDto) {
    return this.adminOtpService.list(query);
  }

  /**
   * POST /admin/otp/:id/reveal — decrypts and returns ONE still-active OTP.
   * POST (not GET) because this is a sensitive, audited action: it must
   * never sit in a URL, browser history, proxy access log, or be prefetched.
   * Every call — success or not — is evaluated against the OTP's current
   * status server-side; every successful reveal writes an audit row.
   */
  @Post(':id/reveal')
  reveal(
    @Param('id') id: string,
    @CurrentUser() admin: { id: string },
    @Req() req: Request,
  ) {
    const userAgent = (req.headers['user-agent'] as string) ?? null;
    return this.adminOtpService.reveal(
      id,
      admin.id,
      req.ip ?? null,
      userAgent,
    );
  }
}
