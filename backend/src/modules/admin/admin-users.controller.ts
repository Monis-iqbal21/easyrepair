import { Body, Controller, HttpCode, HttpStatus, Param, Patch, UseGuards } from '@nestjs/common';
import { AdminService } from './admin.service';
import { UpdateAccountStatusDto } from './dto/update-account-status.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';

/**
 * Separate controller (base path 'admin/users') so this doesn't collide
 * with AdminController's 'admin/workers/:workerProfileId' param route.
 * ADMIN-only. Prepared now for the future admin web — no admin UI ships in
 * this chunk, only the backend capability it will call.
 */
@Controller('admin/users')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminUsersController {
  constructor(private readonly adminService: AdminService) {}

  /**
   * PATCH /admin/users/:userId/account-status
   * Suspend/reactivate a CLIENT account. Rejects any non-CLIENT target —
   * Worker suspension is a separate, existing mechanism (WorkerStatus) this
   * endpoint never touches.
   */
  @Patch(':userId/account-status')
  @HttpCode(HttpStatus.OK)
  updateAccountStatus(
    @Param('userId') userId: string,
    @Body() dto: UpdateAccountStatusDto,
  ) {
    return this.adminService.updateClientAccountStatus(userId, dto.status);
  }
}
