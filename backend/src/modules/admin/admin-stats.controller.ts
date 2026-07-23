import { Controller, Get, UseGuards } from '@nestjs/common';
import { AdminService } from './admin.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';

/**
 * Separate controller (base path 'admin', not 'admin/workers') so this
 * doesn't collide with AdminController's `:workerProfileId` param route.
 */
@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminStatsController {
  constructor(private readonly adminService: AdminService) {}

  /** GET /admin/stats — dashboard counters for the admin panel. */
  @Get('stats')
  getStats() {
    return this.adminService.getStats();
  }
}
