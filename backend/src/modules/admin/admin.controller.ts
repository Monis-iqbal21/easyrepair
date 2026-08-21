import {
  Controller,
  Get,
  Patch,
  Param,
  Body,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
  Res,
  BadRequestException,
} from '@nestjs/common';
import { Response } from 'express';
import { AdminService, VerificationDocumentKind } from './admin.service';
import { sendPrivatePdf } from '../../common/utils/private-pdf-response.util';
import { sendPrivateFile } from '../../common/utils/private-file-response.util';
import {
  RejectWorkerDto,
  RequestChangesDto,
  UpdateFaceMatchStatusDto,
  UpdateTrainingStatusDto,
} from './dto/admin-review-action.dto';
import { ListWorkersQueryDto } from './dto/list-workers-query.dto';
import { UpdateWorkerStatusDto } from './dto/update-worker-status.dto';
import { UpdateWorkerProfileDto } from './dto/update-worker-profile.dto';
import { UpdateWorkerSkillsDto } from './dto/update-worker-skills.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';

@Controller('admin/workers')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  /**
   * GET /admin/workers — Ustaads List. Paginated, searchable (name / phone /
   * CNIC), filterable (status / onboarding / verification / skill).
   * Registered before ':workerProfileId' is irrelevant here since this route
   * has no path segment for Nest to confuse with a param — kept first only
   * for readability, matching 'pending' above.
   */
  @Get()
  getWorkers(@Query() query: ListWorkersQueryDto) {
    return this.adminService.getWorkers(query);
  }

  /** GET /admin/workers/pending — worker profiles submitted and awaiting review. */
  @Get('pending')
  getPendingWorkers() {
    return this.adminService.getPendingWorkers();
  }

  /**
   * GET /admin/workers/:workerProfileId — full detail for one worker.
   * Registered after the static 'pending' route so 'pending' is never
   * swallowed by this param route.
   */
  @Get(':workerProfileId')
  getWorkerById(@Param('workerProfileId') workerProfileId: string) {
    return this.adminService.getWorkerById(workerProfileId);
  }

  /** Admin-only proxy for CNIC front/back and the verification selfie. */
  @Get(':workerProfileId/verification-documents/:kind/download')
  async downloadVerificationDocument(
    @Param('workerProfileId') workerProfileId: string,
    @Param('kind') kind: string,
    @Res() res: Response,
  ) {
    if (!['cnic-front', 'cnic-back', 'selfie'].includes(kind)) {
      throw new BadRequestException('Invalid verification document kind');
    }
    const file = await this.adminService.downloadVerificationDocument(
      workerProfileId,
      kind as VerificationDocumentKind,
    );
    sendPrivateFile(res, file);
  }

  /** Admin-only proxy for legacy/general WorkerDocument records. */
  @Get(':workerProfileId/documents/:documentId/download')
  async downloadWorkerDocument(
    @Param('workerProfileId') workerProfileId: string,
    @Param('documentId') documentId: string,
    @Res() res: Response,
  ) {
    const file = await this.adminService.downloadWorkerDocument(
      workerProfileId,
      documentId,
    );
    sendPrivateFile(res, file);
  }

  /**
   * PATCH /admin/workers/:workerProfileId/status
   * The single mechanism that changes WorkerStatus (ACTIVE/INACTIVE/SUSPENDED).
   */
  @Patch(':workerProfileId/status')
  @HttpCode(HttpStatus.OK)
  updateWorkerStatus(
    @Param('workerProfileId') workerProfileId: string,
    @Body() dto: UpdateWorkerStatusDto,
  ) {
    return this.adminService.updateWorkerStatus(workerProfileId, dto.status);
  }

  /** PATCH /admin/workers/:workerProfileId — operational profile field edits. */
  @Patch(':workerProfileId')
  @HttpCode(HttpStatus.OK)
  updateWorkerProfile(
    @Param('workerProfileId') workerProfileId: string,
    @Body() dto: UpdateWorkerProfileDto,
  ) {
    return this.adminService.updateWorkerProfile(workerProfileId, dto);
  }

  /** PATCH /admin/workers/:workerProfileId/skills */
  @Patch(':workerProfileId/skills')
  @HttpCode(HttpStatus.OK)
  updateWorkerSkills(
    @Param('workerProfileId') workerProfileId: string,
    @Body() dto: UpdateWorkerSkillsDto,
  ) {
    return this.adminService.updateWorkerSkills(workerProfileId, dto);
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

  /**
   * GET /admin/workers/:workerProfileId/agreements
   * The three permanent legal audit records with their full evidence
   * (acceptance id, accepted language, trade, and the source/accepted/PDF
   * hashes). Admin-only, Customer documents excluded, no storage URL returned.
   */
  @Get(':workerProfileId/agreements')
  getWorkerAgreements(@Param('workerProfileId') workerProfileId: string) {
    return this.adminService.getWorkerAgreements(workerProfileId);
  }

  /**
   * GET /admin/workers/:workerProfileId/agreements/:acceptanceId/download
   * Streams one accepted PDF through this authenticated admin endpoint. The
   * acceptance must belong to the worker in the path.
   */
  @Get(':workerProfileId/agreements/:acceptanceId/download')
  async downloadWorkerAgreement(
    @Param('workerProfileId') workerProfileId: string,
    @Param('acceptanceId') acceptanceId: string,
    @Res() res: Response,
  ) {
    const pdf = await this.adminService.downloadWorkerAgreement(
      workerProfileId,
      acceptanceId,
    );
    sendPrivatePdf(res, pdf);
  }
}
