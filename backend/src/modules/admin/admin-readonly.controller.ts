import {
  Controller,
  Get,
  Param,
  Query,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { ListComplaintsQueryDto } from '../complaints/dto/support-complaint.dto';
import { AdminReadonlyAuditInterceptor } from './admin-readonly-audit.interceptor';
import {
  ADMIN_READONLY_SCOPES,
  AdminReadonlyScopes,
} from './admin-readonly.constants';
import { AdminReadonlyGuard } from './admin-readonly.guard';
import { AdminReadonlyService } from './admin-readonly.service';
import {
  ListAdminBookingsQueryDto,
  ListCollectionsQueryDto,
  ListSettlementCasesQueryDto,
} from './dto/admin-operations.dto';
import { ListClientsQueryDto } from './dto/list-clients-query.dto';
import { ListWorkersQueryDto } from './dto/list-workers-query.dto';

/**
 * Machine-to-machine read surface. This controller intentionally contains
 * GET handlers only and never accepts an ADMIN user JWT as authorization.
 */
@Controller('admin-readonly')
@UseGuards(AdminReadonlyGuard)
@UseInterceptors(AdminReadonlyAuditInterceptor)
export class AdminReadonlyController {
  constructor(private readonly service: AdminReadonlyService) {}

  @Get('stats')
  @AdminReadonlyScopes(ADMIN_READONLY_SCOPES.STATS)
  getStats() {
    return this.service.getStats();
  }

  @Get('bookings')
  @AdminReadonlyScopes(ADMIN_READONLY_SCOPES.BOOKINGS)
  listBookings(@Query() query: ListAdminBookingsQueryDto) {
    return this.service.listBookings(query);
  }

  @Get('bookings/:bookingId')
  @AdminReadonlyScopes(ADMIN_READONLY_SCOPES.BOOKINGS)
  getBooking(@Param('bookingId') bookingId: string) {
    return this.service.getBooking(bookingId);
  }

  @Get('settlement-cases')
  @AdminReadonlyScopes(ADMIN_READONLY_SCOPES.SETTLEMENTS)
  listSettlementCases(@Query() query: ListSettlementCasesQueryDto) {
    return this.service.listSettlementCases(query);
  }

  @Get('settlement-cases/:caseId')
  @AdminReadonlyScopes(ADMIN_READONLY_SCOPES.SETTLEMENTS)
  getSettlementCase(@Param('caseId') caseId: string) {
    return this.service.getSettlementCase(caseId);
  }

  @Get('commission-collections')
  @AdminReadonlyScopes(ADMIN_READONLY_SCOPES.SETTLEMENTS)
  listCollections(@Query() query: ListCollectionsQueryDto) {
    return this.service.listCollections(query);
  }

  @Get('workers')
  @AdminReadonlyScopes(ADMIN_READONLY_SCOPES.WORKERS)
  listWorkers(@Query() query: ListWorkersQueryDto) {
    return this.service.listWorkers(query);
  }

  @Get('workers/:workerProfileId')
  @AdminReadonlyScopes(ADMIN_READONLY_SCOPES.WORKERS)
  getWorker(@Param('workerProfileId') workerProfileId: string) {
    return this.service.getWorker(workerProfileId);
  }

  @Get('clients')
  @AdminReadonlyScopes(ADMIN_READONLY_SCOPES.CLIENTS)
  listClients(@Query() query: ListClientsQueryDto) {
    return this.service.listClients(query);
  }

  @Get('clients/:clientProfileId')
  @AdminReadonlyScopes(ADMIN_READONLY_SCOPES.CLIENTS)
  getClient(@Param('clientProfileId') clientProfileId: string) {
    return this.service.getClient(clientProfileId);
  }

  @Get('complaints')
  @AdminReadonlyScopes(ADMIN_READONLY_SCOPES.COMPLAINTS)
  listComplaints(@Query() query: ListComplaintsQueryDto) {
    return this.service.listComplaints(query);
  }

  @Get('complaints/:complaintId')
  @AdminReadonlyScopes(ADMIN_READONLY_SCOPES.COMPLAINTS)
  getComplaint(@Param('complaintId') complaintId: string) {
    return this.service.getComplaint(complaintId);
  }
}
