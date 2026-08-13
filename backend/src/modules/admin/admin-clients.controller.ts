import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AdminClientsService } from './admin-clients.service';
import { ListClientsQueryDto } from './dto/list-clients-query.dto';
import { UpdateClientProfileDto } from './dto/update-client-profile.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';

/**
 * Client management — list/detail/profile. Same base path as
 * AdminClientAgreementsController ('admin/clients'); routes don't collide
 * (that controller only owns the `:clientProfileId/agreements*` sub-paths).
 * Account-status changes are NOT here — they reuse the existing
 * PATCH /admin/users/:userId/account-status (AdminUsersController) rather
 * than duplicating that mechanism.
 */
@Controller('admin/clients')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminClientsController {
  constructor(private readonly adminClientsService: AdminClientsService) {}

  /** GET /admin/clients — Clients List. Never returns passwordHash/refreshTokens/fcmToken. */
  @Get()
  list(@Query() query: ListClientsQueryDto) {
    return this.adminClientsService.list(query);
  }

  /**
   * GET /admin/clients/:clientProfileId — full detail, booking summary, and
   * recent bookings for one client.
   */
  @Get(':clientProfileId')
  getDetail(@Param('clientProfileId') clientProfileId: string) {
    return this.adminClientsService.getDetail(clientProfileId);
  }

  /** PATCH /admin/clients/:clientProfileId/profile — operational field edits only (never phone). */
  @Patch(':clientProfileId/profile')
  @HttpCode(HttpStatus.OK)
  updateProfile(
    @Param('clientProfileId') clientProfileId: string,
    @Body() dto: UpdateClientProfileDto,
  ) {
    return this.adminClientsService.updateProfile(clientProfileId, dto);
  }
}
