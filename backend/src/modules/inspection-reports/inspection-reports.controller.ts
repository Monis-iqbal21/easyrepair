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
import { FileFieldsInterceptor } from '@nestjs/platform-express';
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
const ALLOWED_VOICE_MIME_TYPES = [
  'audio/mpeg',
  'audio/mp4',
  'audio/aac',
  'audio/x-m4a',
  'audio/ogg',
  'audio/wav',
  'audio/webm',
];
const MAX_PHOTO_SIZE = 15 * 1024 * 1024; // 15 MB per photo
const MAX_VOICE_SIZE = 15 * 1024 * 1024; // 15 MB voice note
const MAX_PHOTOS = 6;

type InspectionReportFiles = {
  photos?: Express.Multer.File[];
  voiceNote?: Express.Multer.File[];
};

@Controller('bookings/:bookingId/inspection-report')
@UseGuards(JwtAuthGuard, RolesGuard)
export class InspectionReportsController {
  constructor(
    private readonly inspectionReportsService: InspectionReportsService,
  ) {}

  /**
   * POST /bookings/:bookingId/inspection-report
   * Multipart form: field "payload" is a JSON string of CreateInspectionReportDto,
   * field "photos" is 0-6 image files, field "voiceNote" is 0-1 audio file.
   * Either written findings (issueFound + recommendedRepair) or a voice note is required.
   */
  @Post()
  @Roles(Role.WORKER)
  @HttpCode(HttpStatus.CREATED)
  @UseInterceptors(
    FileFieldsInterceptor(
      [
        { name: 'photos', maxCount: MAX_PHOTOS },
        { name: 'voiceNote', maxCount: 1 },
      ],
      {
        limits: { fileSize: Math.max(MAX_PHOTO_SIZE, MAX_VOICE_SIZE) },
        fileFilter: (_req, file, cb) => {
          const allowed =
            file.fieldname === 'voiceNote'
              ? ALLOWED_VOICE_MIME_TYPES
              : ALLOWED_PHOTO_MIME_TYPES;
          if (allowed.includes(file.mimetype)) {
            cb(null, true);
          } else {
            cb(
              new BadRequestException(
                file.fieldname === 'voiceNote'
                  ? `Unsupported voice note type: ${file.mimetype}.`
                  : `Unsupported photo type: ${file.mimetype}.`,
              ),
              false,
            );
          }
        },
      },
    ),
  )
  async submitReport(
    @CurrentUser() user: { id: string },
    @Param('bookingId') bookingId: string,
    @Body('payload') payloadRaw: string,
    @UploadedFiles() files: InspectionReportFiles = {},
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

    const photos = files.photos ?? [];
    const voiceNote = files.voiceNote?.[0];

    const hasWrittenText = !!dto.issueFound?.trim() && !!dto.recommendedRepair?.trim();
    if (!hasWrittenText && !voiceNote) {
      throw new BadRequestException(
        'Provide written findings (issue found and recommended repair) or a voice note.',
      );
    }

    return this.inspectionReportsService.submitReport(
      user.id,
      bookingId,
      dto,
      photos,
      voiceNote,
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
