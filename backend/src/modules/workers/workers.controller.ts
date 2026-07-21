import {
  Controller,
  Get,
  Post,
  Patch,
  Put,
  Body,
  Param,
  Query,
  Ip,
  Headers,
  UseGuards,
  HttpCode,
  HttpStatus,
  BadRequestException,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { BookingStatus } from '@prisma/client';
import { WorkersService } from './workers.service';
import { BidsService } from '../bids/bids.service';
import { UpdateAvailabilityDto } from './dto/update-availability.dto';
import { UpdateLocationDto } from './dto/update-location.dto';
import { UpdateSkillsDto } from './dto/update-skills.dto';
import { UpdateProfileCompletionDto } from './dto/update-profile-completion.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Role } from '../../common/enums/role.enum';

@Controller('workers')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.WORKER)
export class WorkersController {
  constructor(
    private readonly workersService: WorkersService,
    private readonly bidsService: BidsService,
  ) {}

  // ── Avatar upload ────────────────────────────────────────────────────────

  /** PATCH /workers/avatar — upload a new profile picture */
  @Patch('avatar')
  @HttpCode(HttpStatus.OK)
  @UseInterceptors(FileInterceptor('file'))
  uploadAvatar(
    @CurrentUser() user: { id: string },
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) throw new BadRequestException('No file uploaded');
    return this.workersService.uploadAvatar(
      user.id,
      file.buffer,
      file.originalname,
      file.mimetype,
    );
  }

  // ── Profile & availability ───────────────────────────────────────────────

  /** GET /workers/profile — full worker dashboard data */
  @Get('profile')
  getProfile(@CurrentUser() user: { id: string }) {
    return this.workersService.getProfile(user.id);
  }

  /** PATCH /workers/availability — toggle online/offline/busy */
  @Patch('availability')
  @HttpCode(HttpStatus.OK)
  updateAvailability(
    @CurrentUser() user: { id: string },
    @Body() dto: UpdateAvailabilityDto,
  ) {
    return this.workersService.updateAvailability(user.id, dto);
  }

  /**
   * PATCH /workers/location — periodic location-only ping.
   * Updates lat/lng only; never changes availabilityStatus.
   * Workers who are OFFLINE (including auto-offlined) are silently ignored.
   */
  @Patch('location')
  @HttpCode(HttpStatus.NO_CONTENT)
  updateLocation(
    @CurrentUser() user: { id: string },
    @Body() dto: UpdateLocationDto,
  ) {
    return this.workersService.updateLocation(user.id, dto);
  }

  /** PUT /workers/skills — replace all skills */
  @Put('skills')
  @HttpCode(HttpStatus.OK)
  updateSkills(
    @CurrentUser() user: { id: string },
    @Body() dto: UpdateSkillsDto,
  ) {
    return this.workersService.updateSkills(user.id, dto);
  }

  // ── Profile completion (Ustaad onboarding) ─────────────────────────────────

  /**
   * PATCH /workers/profile-completion
   * Partial update of the profile-completion text/checkbox fields. Only
   * allowed while onboardingStatus is DRAFT or CHANGES_REQUIRED.
   */
  @Patch('profile-completion')
  @HttpCode(HttpStatus.OK)
  updateProfileCompletion(
    @CurrentUser() user: { id: string },
    @Body() dto: UpdateProfileCompletionDto,
  ) {
    return this.workersService.updateProfileCompletion(user.id, dto);
  }

  /** POST /workers/profile-completion/cnic-front */
  @Post('profile-completion/cnic-front')
  @HttpCode(HttpStatus.OK)
  @UseInterceptors(FileInterceptor('file'))
  uploadCnicFront(
    @CurrentUser() user: { id: string },
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) throw new BadRequestException('No file uploaded');
    return this.workersService.uploadCnicFront(
      user.id,
      file.buffer,
      file.originalname,
      file.mimetype,
    );
  }

  /** POST /workers/profile-completion/cnic-back */
  @Post('profile-completion/cnic-back')
  @HttpCode(HttpStatus.OK)
  @UseInterceptors(FileInterceptor('file'))
  uploadCnicBack(
    @CurrentUser() user: { id: string },
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) throw new BadRequestException('No file uploaded');
    return this.workersService.uploadCnicBack(
      user.id,
      file.buffer,
      file.originalname,
      file.mimetype,
    );
  }

  /** POST /workers/profile-completion/selfie */
  @Post('profile-completion/selfie')
  @HttpCode(HttpStatus.OK)
  @UseInterceptors(FileInterceptor('file'))
  uploadLiveSelfie(
    @CurrentUser() user: { id: string },
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) throw new BadRequestException('No file uploaded');
    return this.workersService.uploadLiveSelfie(
      user.id,
      file.buffer,
      file.originalname,
      file.mimetype,
    );
  }

  /**
   * GET /workers/profile-completion/agreement-templates
   * Exact text/version of the agreements the worker is about to accept.
   */
  @Get('profile-completion/agreement-templates')
  getAgreementTemplates(@CurrentUser() user: { id: string }) {
    return this.workersService.getAgreementTemplates(user.id);
  }

  /**
   * GET /workers/profile-completion/agreements
   * Owner-only: this worker's own permanent agreement acceptance records
   * (with downloadable PDF URLs).
   */
  @Get('profile-completion/agreements')
  getMyAgreementAcceptances(@CurrentUser() user: { id: string }) {
    return this.workersService.getMyAgreementAcceptances(user.id);
  }

  /**
   * POST /workers/profile-completion/submit
   * Validates every required field is present, records permanent agreement
   * acceptances, then moves the profile to SUBMITTED_FOR_REVIEW. Rejects with
   * a list of missing fields otherwise.
   */
  @Post('profile-completion/submit')
  @HttpCode(HttpStatus.OK)
  submitProfileForReview(
    @CurrentUser() user: { id: string; phone: string },
    @Ip() ip: string,
    @Headers('user-agent') userAgent?: string,
  ) {
    return this.workersService.submitProfileForReview(
      user.id,
      user.phone,
      ip ?? null,
      userAgent ?? null,
    );
  }

  // ── Worker jobs ──────────────────────────────────────────────────────────

  /**
   * GET /workers/jobs/new
   * Returns all PENDING bookings matching the worker's skills — including ones
   * the worker already bid on. Each item includes hasMyBid so the frontend
   * can show a "Bid placed" badge. Sorted newest first.
   * Must be defined BEFORE /workers/jobs/:id so the router matches correctly.
   */
  @Get('jobs/new')
  getNewJobs(@CurrentUser() user: { id: string }) {
    return this.bidsService.getNewJobsForWorker(user.id);
  }

  /**
   * GET /workers/jobs?filter=active|completed|cancelled
   * Returns all bookings assigned to the authenticated worker.
   * Must be defined BEFORE /workers/jobs/:id so the router matches correctly.
   */
  @Get('jobs')
  getWorkerJobs(
    @CurrentUser() user: { id: string },
    @Query('filter') filter?: 'active' | 'completed' | 'cancelled',
  ) {
    return this.workersService.getWorkerJobs(user.id, filter);
  }

  /** GET /workers/jobs/:id — single job detail, scoped to the worker */
  @Get('jobs/:id')
  getWorkerJobById(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
  ) {
    return this.workersService.getWorkerJobById(user.id, id);
  }

  /**
   * PATCH /workers/jobs/:id/status
   * Transition an accepted job to EN_ROUTE or IN_PROGRESS.
   * Body: { status: 'EN_ROUTE' | 'IN_PROGRESS' }
   */
  @Patch('jobs/:id/status')
  @HttpCode(HttpStatus.OK)
  updateJobStatus(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
    @Body('status') status: string,
  ) {
    if (status !== BookingStatus.EN_ROUTE && status !== BookingStatus.IN_PROGRESS) {
      throw new BadRequestException(
        "status must be 'EN_ROUTE' or 'IN_PROGRESS'",
      );
    }
    return this.workersService.updateJobStatus(
      user.id,
      id,
      status as 'EN_ROUTE' | 'IN_PROGRESS',
    );
  }

  /**
   * PATCH /workers/jobs/:id/cancel
   * Worker cancels an accepted/en-route job.
   * Body: { reason?: string }
   */
  @Patch('jobs/:id/cancel')
  @HttpCode(HttpStatus.OK)
  cancelJob(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
    @Body('reason') reason?: string,
  ) {
    return this.workersService.cancelJob(user.id, id, reason);
  }

  /** PATCH /workers/jobs/:id/complete — mark an active job as COMPLETED */
  @Patch('jobs/:id/complete')
  @HttpCode(HttpStatus.OK)
  completeJob(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
  ) {
    return this.workersService.completeJob(user.id, id);
  }

  // ── Worker reviews ───────────────────────────────────────────────────────

  /**
   * GET /workers/reviews?limit=N
   * Returns reviews for this worker's completed bookings, sorted latest first.
   * Omit `limit` to get all reviews (used by the reviews page).
   * Pass `limit=2` for the dashboard preview.
   */
  @Get('reviews')
  getWorkerReviews(
    @CurrentUser() user: { id: string },
    @Query('limit') limit?: string,
  ) {
    const parsedLimit = limit !== undefined ? parseInt(limit, 10) : undefined;
    return this.workersService.getWorkerReviews(
      user.id,
      Number.isFinite(parsedLimit) ? parsedLimit : undefined,
    );
  }

  /** GET /workers/reviews/summary — aggregate rating + count */
  @Get('reviews/summary')
  getWorkerReviewSummary(@CurrentUser() user: { id: string }) {
    return this.workersService.getWorkerReviewSummary(user.id);
  }
}
