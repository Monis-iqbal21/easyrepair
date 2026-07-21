import {
  Controller,
  Get,
  Patch,
  Param,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { AdminService } from './admin.service';
import {
  RejectWorkerDto,
  RequestChangesDto,
  UpdateFaceMatchStatusDto,
  UpdateTrainingStatusDto,
} from './dto/admin-review-action.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';

@Controller('admin/workers')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  /** GET /admin/workers/pending — worker profiles submitted and awaiting review. */
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

  /** PATCH /admin/workers/:workerProfileId/reject — reason required. */
  @Patch(':workerProfileId/reject')
  @HttpCode(HttpStatus.OK)
  rejectWorker(
    @Param('workerProfileId') workerProfileId: string,
    @Body() dto: RejectWorkerDto,
  ) {
    return this.adminService.rejectWorker(workerProfileId, dto.reason);
  }

  /** PATCH /admin/workers/:workerProfileId/request-changes — reason required. */
  @Patch(':workerProfileId/request-changes')
  @HttpCode(HttpStatus.OK)
  requestChanges(
    @Param('workerProfileId') workerProfileId: string,
    @Body() dto: RequestChangesDto,
  ) {
    return this.adminService.requestChanges(workerProfileId, dto.reason);
  }

  /**
   * PATCH /admin/workers/:workerProfileId/face-match
   * Manual review only — no automatic face recognition. Admin compares the
   * CNIC photos against the live selfie and marks the outcome.
   */
  @Patch(':workerProfileId/face-match')
  @HttpCode(HttpStatus.OK)
  updateFaceMatchStatus(
    @Param('workerProfileId') workerProfileId: string,
    @Body() dto: UpdateFaceMatchStatusDto,
  ) {
    return this.adminService.updateFaceMatchStatus(workerProfileId, dto.status);
  }

  /** PATCH /admin/workers/:workerProfileId/training-status */
  @Patch(':workerProfileId/training-status')
  @HttpCode(HttpStatus.OK)
  updateTrainingStatus(
    @Param('workerProfileId') workerProfileId: string,
    @Body() dto: UpdateTrainingStatusDto,
  ) {
    return this.adminService.updateTrainingStatus(workerProfileId, dto.status);
  }
}
