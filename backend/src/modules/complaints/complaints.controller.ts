import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { ComplaintsService } from './complaints.service';
import { CreateBookingComplaintDto } from './dto/create-booking-complaint.dto';
import {
  AssignComplaintDto,
  ChangeComplaintPriorityDto,
  ChangeComplaintStatusDto,
  ListComplaintsQueryDto,
} from './dto/support-complaint.dto';

@Controller('complaints')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.CLIENT)
export class ClientComplaintsController {
  constructor(private readonly service: ComplaintsService) {}

  @Post('booking/:bookingId')
  @HttpCode(HttpStatus.CREATED)
  createForBooking(
    @CurrentUser() user: { id: string },
    @Param('bookingId') bookingId: string,
    @Body() dto: CreateBookingComplaintDto,
  ) {
    return this.service.createForBooking(user.id, bookingId, dto);
  }

  @Get('booking/:bookingId')
  getForBooking(
    @CurrentUser() user: { id: string },
    @Param('bookingId') bookingId: string,
  ) {
    return this.service.getForBooking(user.id, bookingId);
  }

  @Post(':complaintId/human-request')
  @HttpCode(HttpStatus.OK)
  requestHuman(
    @CurrentUser() user: { id: string },
    @Param('complaintId') complaintId: string,
  ) {
    return this.service.requestHumanForReporter(user.id, complaintId);
  }
}

/**
 * Current authorization bridge: only the existing ADMIN role reaches these
 * permission-shaped routes. Complaint business logic itself is role-neutral,
 * so a future Role + Permission guard can replace this edge without a rewrite.
 */
@Controller('support/complaints')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class SupportComplaintsController {
  constructor(private readonly service: ComplaintsService) {}

  @Get()
  list(@Query() query: ListComplaintsQueryDto) {
    return this.service.list(query);
  }

  @Get(':complaintId')
  get(@Param('complaintId') complaintId: string) {
    return this.service.get(complaintId);
  }

  @Patch(':complaintId/status')
  changeStatus(
    @Param('complaintId') complaintId: string,
    @Body() dto: ChangeComplaintStatusDto,
    @CurrentUser() user: { id: string },
  ) {
    return this.service.changeStatus(complaintId, dto.status, user.id);
  }

  @Patch(':complaintId/priority')
  changePriority(
    @Param('complaintId') complaintId: string,
    @Body() dto: ChangeComplaintPriorityDto,
    @CurrentUser() user: { id: string },
  ) {
    return this.service.changePriority(complaintId, dto.priority, user.id);
  }

  @Patch(':complaintId/assignment')
  assign(
    @Param('complaintId') complaintId: string,
    @Body() dto: AssignComplaintDto,
    @CurrentUser() user: { id: string },
  ) {
    return this.service.assign(complaintId, dto.assignedToUserId, user.id);
  }

  @Post(':complaintId/human-request')
  @HttpCode(HttpStatus.OK)
  requestHuman(
    @Param('complaintId') complaintId: string,
    @CurrentUser() user: { id: string },
  ) {
    return this.service.requestHuman(complaintId, user.id);
  }
}
