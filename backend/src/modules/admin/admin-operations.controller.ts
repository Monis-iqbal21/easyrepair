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
import { TokenPayload } from '../auth/entities/token-payload.entity';
import { AdminOperationsService } from './admin-operations.service';
import {
  AddContactAttemptDto,
  AddSettlementCaseNoteDto,
  CorrectSettlementDto,
  CreateSettlementDto,
  ListAdminBookingsQueryDto,
  ListCollectionsQueryDto,
  ListSettlementCasesQueryDto,
  RunNightlyCollectionDto,
  UpdateCollectionDto,
  UpdateSettlementCaseDto,
} from './dto/admin-operations.dto';

@Controller('admin/bookings')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminBookingOperationsController {
  constructor(private readonly service: AdminOperationsService) {}

  @Get()
  listBookings(@Query() query: ListAdminBookingsQueryDto) {
    return this.service.listBookings(query);
  }

  @Get(':bookingId')
  getBooking(@Param('bookingId') bookingId: string) {
    return this.service.getBooking(bookingId);
  }

  @Post(':bookingId/settlements')
  createSettlement(
    @Param('bookingId') bookingId: string,
    @Body() dto: CreateSettlementDto,
    @CurrentUser() user: TokenPayload,
  ) {
    return this.service.createSettlement(bookingId, dto, user.sub);
  }

  @Post(':bookingId/settlements/corrections')
  correctSettlement(
    @Param('bookingId') bookingId: string,
    @Body() dto: CorrectSettlementDto,
    @CurrentUser() user: TokenPayload,
  ) {
    return this.service.correctSettlement(bookingId, dto, user.sub);
  }
}

@Controller('admin/settlement-cases')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminSettlementCasesController {
  constructor(private readonly service: AdminOperationsService) {}

  @Get()
  listCases(@Query() query: ListSettlementCasesQueryDto) {
    return this.service.listCases(query);
  }

  @Get(':caseId')
  getCase(@Param('caseId') caseId: string) {
    return this.service.getCase(caseId);
  }

  @Patch(':caseId')
  updateCase(
    @Param('caseId') caseId: string,
    @Body() dto: UpdateSettlementCaseDto,
    @CurrentUser() user: TokenPayload,
  ) {
    return this.service.updateCase(caseId, dto, user.sub);
  }

  @Post(':caseId/notes')
  addNote(
    @Param('caseId') caseId: string,
    @Body() dto: AddSettlementCaseNoteDto,
    @CurrentUser() user: TokenPayload,
  ) {
    return this.service.addNote(caseId, dto, user.sub);
  }

  @Post(':caseId/contact-attempts')
  addContact(
    @Param('caseId') caseId: string,
    @Body() dto: AddContactAttemptDto,
    @CurrentUser() user: TokenPayload,
  ) {
    return this.service.addContact(caseId, dto, user.sub);
  }
}

@Controller('admin/commission-collections')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminCommissionCollectionsController {
  constructor(private readonly service: AdminOperationsService) {}

  @Post('nightly')
  @HttpCode(HttpStatus.OK)
  runNightly(
    @Body() dto: RunNightlyCollectionDto,
    @CurrentUser() user: TokenPayload,
  ) {
    return this.service.runNightly(dto, user.sub);
  }

  @Get()
  listCollections(@Query() query: ListCollectionsQueryDto) {
    return this.service.listCollections(query);
  }

  @Patch(':collectionId')
  updateCollection(
    @Param('collectionId') collectionId: string,
    @Body() dto: UpdateCollectionDto,
  ) {
    return this.service.updateCollection(collectionId, dto);
  }
}
