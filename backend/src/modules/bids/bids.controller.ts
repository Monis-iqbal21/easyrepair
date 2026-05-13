import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { BidsService } from './bids.service';
import { BidWithRelations } from './bids.repository';
import { CreateBidDto } from './dto/create-bid.dto';
import { EditBidDto } from './dto/edit-bid.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Role } from '../../common/enums/role.enum';

@Controller()
@UseGuards(JwtAuthGuard, RolesGuard)
export class BidsController {
  constructor(private readonly bidsService: BidsService) {}

  // ── Worker endpoints ─────────────────────────────────────────────────────

  /**
   * POST /bookings/:id/bids
   * Worker places a bid on a PENDING booking.
   */
  @Post('bookings/:id/bids')
  @Roles(Role.WORKER)
  @HttpCode(HttpStatus.CREATED)
  createBid(
    @CurrentUser() user: { id: string },
    @Param('id') bookingId: string,
    @Body() dto: CreateBidDto,
  ): Promise<BidWithRelations> {
    return this.bidsService.createBid(user.id, bookingId, dto.amount, dto.message);
  }

  /**
   * GET /bookings/:id/bids/my
   * Worker retrieves their own bid on a booking.
   * Must be defined BEFORE /bookings/:id/bids to avoid route clash.
   */
  @Get('bookings/:id/bids/my')
  @Roles(Role.WORKER)
  getMyBid(
    @CurrentUser() user: { id: string },
    @Param('id') bookingId: string,
  ): Promise<BidWithRelations> {
    return this.bidsService.getMyBid(user.id, bookingId);
  }

  /**
   * PATCH /bids/:id
   * Worker edits their bid (once only, booking must still be PENDING).
   */
  @Patch('bids/:id')
  @Roles(Role.WORKER)
  @HttpCode(HttpStatus.OK)
  editBid(
    @CurrentUser() user: { id: string },
    @Param('id') bidId: string,
    @Body() dto: EditBidDto,
  ): Promise<BidWithRelations> {
    return this.bidsService.editBid(user.id, bidId, dto.amount, dto.message);
  }

  // ── Client endpoints ─────────────────────────────────────────────────────

  /**
   * GET /bookings/:id/bids
   * Client lists all bids on their booking (sorted lowest-amount first).
   * Worker lists the live bid feed for an eligible job (sorted newest first).
   */
  @Get('bookings/:id/bids')
  @Roles(Role.CLIENT, Role.WORKER)
  getBidsForBooking(
    @CurrentUser() user: { id: string; role: string },
    @Param('id') bookingId: string,
  ) {
    if (user.role === Role.WORKER) {
      return this.bidsService.getBidsForBookingAsWorker(user.id, bookingId);
    }
    return this.bidsService.getBidsForBooking(user.id, bookingId);
  }

  /**
   * POST /bids/:id/accept
   * Client accepts a bid — assigns the worker and transitions booking to ACCEPTED.
   */
  @Post('bids/:id/accept')
  @Roles(Role.CLIENT)
  @HttpCode(HttpStatus.OK)
  acceptBid(
    @CurrentUser() user: { id: string },
    @Param('id') bidId: string,
  ) {
    return this.bidsService.acceptBid(user.id, bidId);
  }
}
