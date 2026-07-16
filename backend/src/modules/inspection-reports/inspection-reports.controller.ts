import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { InspectionReportsService } from './inspection-reports.service';
import { CreateInspectionReportDto } from './dto/create-inspection-report.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Role } from '../../common/enums/role.enum';

const ALLOWED_PHOTO_MIME_TYPES = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
];
const MAX_PHOTO_SIZE = 15 * 1024 * 1024; // 15 MB per photo
const MAX_PHOTOS = 6;

@Controller('bookings/:bookingId/inspection-report')
@UseGuards(JwtAuthGuard, RolesGuard)
export class InspectionReportsController {
  constructor(
    private readonly inspectionReportsService: InspectionReportsService,
  ) {}

  /**
   * POST /bookings/:bookingId/inspection-report
   * Multipart form: field "payload" is a JSON string of CreateInspectionReportDto,
   * field "photos" is 0-6 image files.
   */
  @Post()
  @Roles(Role.WORKER)
  @HttpCode(HttpStatus.CREATED)
  @UseInterceptors(
    FilesInterceptor('photos', MAX_PHOTOS, {
      limits: { fileSize: MAX_PHOTO_SIZE },
      fileFilter: (_req, file, cb) => {
        if (ALLOWED_PHOTO_MIME_TYPES.includes(file.mimetype)) {
          cb(null, true);
        } else {
          cb(
            new BadRequestException(
              `Unsupported photo type: ${file.mimetype}.`,
            ),
            false,
          );
        }
      },
    }),
  )
  async submitReport(
    @CurrentUser() user: { id: string },
    @Param('bookingId') bookingId: string,
    @Body('payload') payloadRaw: string,
    @UploadedFiles() photos: Express.Multer.File[] = [],
  ) {
    if (!payloadRaw) {
      throw new BadRequestException('Missing report payload.');
    }
    let parsed: unknown;
    try {
      parsed = JSON.parse(payloadRaw);
    } catch {
      throw new BadRequestException('Report payload must be valid JSON.');
    }

    const dto = plainToInstance(CreateInspectionReportDto, parsed);
    const errors = await validate(dto, { whitelist: true });
    if (errors.length > 0) {
      const messages = errors.flatMap((e) => Object.values(e.constraints ?? {}));
      throw new BadRequestException(messages);
    }

    return this.inspectionReportsService.submitReport(
      user.id,
      bookingId,
      dto,
      photos,
    );
  }

  /** GET /bookings/:bookingId/inspection-report — client (owner), assigned worker, or admin. */
  @Get()
  @Roles(Role.CLIENT, Role.WORKER, Role.ADMIN)
  getReport(
    @CurrentUser() user: { id: string; role: string },
    @Param('bookingId') bookingId: string,
  ) {
    return this.inspectionReportsService.getReport(
      user.id,
      user.role,
      bookingId,
    );
  }

  /** POST /bookings/:bookingId/inspection-report/accept — client only. */
  @Post('accept')
  @Roles(Role.CLIENT)
  acceptQuote(
    @CurrentUser() user: { id: string },
    @Param('bookingId') bookingId: string,
  ) {
    return this.inspectionReportsService.acceptQuote(user.id, bookingId);
  }

  /** POST /bookings/:bookingId/inspection-report/close — client only. */
  @Post('close')
  @Roles(Role.CLIENT)
  closeAfterInspection(
    @CurrentUser() user: { id: string },
    @Param('bookingId') bookingId: string,
  ) {
    return this.inspectionReportsService.closeAfterInspection(
      user.id,
      bookingId,
    );
  }
}
