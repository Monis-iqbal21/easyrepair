import { Body, Controller, HttpCode, HttpStatus, Param, Patch, UseGuards } from '@nestjs/common';
import { AdminService } from './admin.service';
import { UpdateCommissionStatusDto } from './dto/update-commission-status.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';

/**
 * Separate controller (base path 'admin/bookings') so this doesn't collide
 * with AdminController's 'admin/workers/:workerProfileId' param route.
 * ADMIN-only — neither the Worker who did the job nor the Client who booked
 * it can ever reach this.
 */
@Controller('admin/bookings')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminBookingsController {
  constructor(private readonly adminService: AdminService) {}

  /**
   * PATCH /admin/bookings/:bookingId/commission-status
   * Settlement tracking for HandyGo's 18% commission on one completed job.
   * The admin web UI that calls this is a future piece of work — this
   * endpoint exists now so that UI has something to call.
   */
  @Patch(':bookingId/commission-status')
  @HttpCode(HttpStatus.OK)
  updateCommissionStatus(
    @Param('bookingId') bookingId: string,
    @Body() dto: UpdateCommissionStatusDto,
  ) {
    return this.adminService.updateBookingCommissionStatus(bookingId, dto.status);
  }
}
