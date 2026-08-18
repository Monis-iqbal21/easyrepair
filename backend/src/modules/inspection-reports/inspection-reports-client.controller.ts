import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { InspectionReportsService } from './inspection-reports.service';
import { AttachableInspectionReportDto } from './dto/attachable-inspection-report.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Role } from '../../common/enums/role.enum';

/**
 * Client-scoped inspection-report routes that aren't tied to one booking.
 *
 * Separate from InspectionReportsController only because that controller is
 * mounted under `bookings/:bookingId/inspection-report`; the listing below
 * is account-wide, so it needs its own base path. Same module, same service.
 */
@Controller('inspection-reports')
@UseGuards(JwtAuthGuard, RolesGuard)
export class InspectionReportsClientController {
  constructor(
    private readonly inspectionReportsService: InspectionReportsService,
  ) {}

  /**
   * GET /inspection-reports/client/available?categoryId=…
   *
   * The authenticated client's own past inspections whose report they may
   * attach to a new BIDDING job. Scoped to the caller by their JWT — the
   * client id is never taken from the request. [categoryId] narrows to the
   * service being posted; omitting it returns every eligible report.
   */
  @Get('client/available')
  @Roles(Role.CLIENT)
  listAttachable(
    @CurrentUser() user: { id: string },
    @Query('categoryId') categoryId?: string,
  ): Promise<AttachableInspectionReportDto[]> {
    return this.inspectionReportsService.listAttachableForClient(
      user.id,
      categoryId,
    );
  }
}
