import {
  Controller,
  Get,
  Patch,
  Put,
  Body,
  Param,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { WorkersService } from './workers.service';
import { UpdateAvailabilityDto } from './dto/update-availability.dto';
import { UpdateSkillsDto } from './dto/update-skills.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Role } from '../../common/enums/role.enum';

@Controller('workers')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.WORKER)
export class WorkersController {
  constructor(private readonly workersService: WorkersService) {}

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

  /** PUT /workers/skills — replace all skills */
  @Put('skills')
  @HttpCode(HttpStatus.OK)
  updateSkills(
    @CurrentUser() user: { id: string },
    @Body() dto: UpdateSkillsDto,
  ) {
    return this.workersService.updateSkills(user.id, dto);
  }

  // ── Worker jobs ──────────────────────────────────────────────────────────

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

  /** PATCH /workers/jobs/:id/complete — mark an active job as COMPLETED */
  @Patch('jobs/:id/complete')
  @HttpCode(HttpStatus.OK)
  completeJob(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
  ) {
    return this.workersService.completeJob(user.id, id);
  }
}
