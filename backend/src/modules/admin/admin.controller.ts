import {
  Controller,
  Get,
  Patch,
  Param,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { AdminService } from './admin.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';

@Controller('admin/workers')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  /** GET /admin/workers/pending — list worker profiles awaiting verification. */
  @Get('pending')
  getPendingWorkers() {
    return this.adminService.getPendingWorkers();
  }

  /** PATCH /admin/workers/:workerProfileId/approve */
  @Patch(':workerProfileId/approve')
  @HttpCode(HttpStatus.OK)
  approveWorker(@Param('workerProfileId') workerProfileId: string) {
    return this.adminService.approveWorker(workerProfileId);
  }

  /** PATCH /admin/workers/:workerProfileId/reject */
  @Patch(':workerProfileId/reject')
  @HttpCode(HttpStatus.OK)
  rejectWorker(@Param('workerProfileId') workerProfileId: string) {
    return this.adminService.rejectWorker(workerProfileId);
  }
}
