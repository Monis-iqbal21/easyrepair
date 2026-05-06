import {
  Controller,
  Post,
  Get,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { BookingsService } from './bookings.service';
import { CreateBookingDto } from './dto/create-booking.dto';
import { UpdateBookingDto } from './dto/update-booking.dto';
import { CreateReviewDto } from './dto/create-review.dto';
import { AssignWorkerDto } from './dto/assign-worker.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Role } from '../../common/enums/role.enum';

const ALLOWED_MIME_TYPES = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
  'video/mp4',
  'video/quicktime',
  'video/3gpp',
  'audio/mpeg',
  'audio/mp4',
  'audio/aac',
  'audio/x-m4a',
  'audio/ogg',
  'audio/wav',
];

const MAX_FILE_SIZE = 50 * 1024 * 1024; // 50 MB

@Controller('bookings')
@UseGuards(JwtAuthGuard, RolesGuard)
export class BookingsController {
  constructor(private readonly bookingsService: BookingsService) {}

  /** POST /bookings — client creates a service request */
  @Post()
  @Roles(Role.CLIENT)
  @HttpCode(HttpStatus.CREATED)
  createBooking(
    @CurrentUser() user: { id: string },
    @Body() dto: CreateBookingDto,
  ) {
    return this.bookingsService.createBooking(user.id, dto);
  }

  /** GET /bookings/my — fetch all bookings for the logged-in client */
  @Get('my')
  @Roles(Role.CLIENT)
  getMyBookings(@CurrentUser() user: { id: string }) {
    return this.bookingsService.getClientBookings(user.id);
  }

  /** GET /bookings/:id — fetch a single booking by id */
  @Get(':id')
  @Roles(Role.CLIENT)
  getBookingById(
    @CurrentUser() user: { id: string },
    @Param('id') bookingId: string,
  ) {
    return this.bookingsService.getBookingById(user.id, bookingId);
  }

  /** PATCH /bookings/:id — client edits a PENDING booking (no worker assigned) */
  @Patch(':id')
  @Roles(Role.CLIENT)
  updateBooking(
    @CurrentUser() user: { id: string },
    @Param('id') bookingId: string,
    @Body() dto: UpdateBookingDto,
  ) {
    return this.bookingsService.updateBooking(user.id, bookingId, dto);
  }

  /** POST /bookings/:id/review — client submits review for a completed booking */
  @Post(':id/review')
  @Roles(Role.CLIENT)
  @HttpCode(HttpStatus.CREATED)
  submitReview(
    @CurrentUser() user: { id: string },
    @Param('id') bookingId: string,
    @Body() dto: CreateReviewDto,
  ) {
    return this.bookingsService.submitReview(user.id, bookingId, dto);
  }

  /** PATCH /bookings/:id/cancel — client cancels their booking */
  @Patch(':id/cancel')
  @Roles(Role.CLIENT)
  cancelBooking(
    @CurrentUser() user: { id: string },
    @Param('id') bookingId: string,
    @Body('reason') reason?: string,
  ) {
    return this.bookingsService.cancelBooking(user.id, bookingId, reason);
  }

  /**
   * GET /bookings/:id/nearby-workers?radiusKm=2
   * Return online workers near the booking location who match its category.
   * When radiusKm is provided only that radius is searched (frontend drives
   * progressive expansion); omitting it falls back to the full ladder.
   */
  @Get(':id/nearby-workers')
  @Roles(Role.CLIENT)
  getNearbyWorkers(
    @CurrentUser() user: { id: string },
    @Param('id') bookingId: string,
    @Query('radiusKm') radiusKm?: string,
  ) {
    const radiusKmNum =
      radiusKm !== undefined ? parseFloat(radiusKm) : undefined;
    return this.bookingsService.getNearbyWorkers(
      user.id,
      bookingId,
      radiusKmNum,
    );
  }

  /**
   * POST /bookings/:id/assign
   * Client picks a specific worker for their PENDING booking.
   * Transitions booking to ACCEPTED.
   */
  @Post(':id/assign')
  @Roles(Role.CLIENT)
  @HttpCode(HttpStatus.OK)
  assignWorker(
    @CurrentUser() user: { id: string },
    @Param('id') bookingId: string,
    @Body() dto: AssignWorkerDto,
  ) {
    return this.bookingsService.assignWorker(
      user.id,
      bookingId,
      dto.workerProfileId,
    );
  }

  /**
   * POST /bookings/:id/attachments
   * Upload one file (image / video / audio) to the booking.
   * Body: multipart/form-data with field "file".
   */
  @Post(':id/attachments')
  @Roles(Role.CLIENT)
  @HttpCode(HttpStatus.CREATED)
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: MAX_FILE_SIZE },
      fileFilter: (_req, file, cb) => {
        if (ALLOWED_MIME_TYPES.includes(file.mimetype)) {
          cb(null, true);
        } else {
          cb(
            new BadRequestException(
              `Unsupported file type: ${file.mimetype}. Allowed: image, video, or audio.`,
            ),
            false,
          );
        }
      },
    }),
  )
  uploadAttachment(
    @CurrentUser() user: { id: string },
    @Param('id') bookingId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) throw new BadRequestException('No file provided.');
    return this.bookingsService.uploadAttachment(user.id, bookingId, file);
  }

  /**
   * DELETE /bookings/:id/attachments/:attachmentId
   * Remove an existing attachment from a PENDING booking.
   */
  @Delete(':id/attachments/:attachmentId')
  @Roles(Role.CLIENT)
  async deleteAttachment(
    @CurrentUser() user: { id: string },
    @Param('id') bookingId: string,
    @Param('attachmentId') attachmentId: string,
  ) {
    await this.bookingsService.deleteAttachment(
      user.id,
      bookingId,
      attachmentId,
    );
    return { message: 'Attachment deleted.' };
  }
}
