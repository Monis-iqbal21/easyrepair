import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  InspectionBookingContext,
  InspectionReportsRepository,
  InspectionReportWithRelations,
} from './inspection-reports.repository';
import { CreateInspectionReportDto } from './dto/create-inspection-report.dto';
import { InspectionReportResponseDto } from './dto/inspection-report-response.dto';
import { StorageService } from '../storage/storage.service';
import { NotificationsService } from '../notifications/notifications.service';
import { BookingsService } from '../bookings/bookings.service';

const MAX_PHOTOS = 6;

@Injectable()
export class InspectionReportsService {
  constructor(
    private readonly repository: InspectionReportsRepository,
    private readonly storageService: StorageService,
    private readonly notificationsService: NotificationsService,
    private readonly bookingsService: BookingsService,
  ) {}

  /** POST /bookings/:id/inspection-report — assigned worker only. */
  async submitReport(
    userId: string,
    bookingId: string,
    dto: CreateInspectionReportDto,
    photos: Express.Multer.File[],
    voiceNote?: Express.Multer.File,
  ): Promise<InspectionReportResponseDto> {
    const workerProfile =
      await this.repository.findWorkerProfileByUserId(userId);
    if (!workerProfile) throw new ForbiddenException('Worker profile not found');

    const booking = await this.repository.findBookingContext(bookingId);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.workerProfileId !== workerProfile.id) {
      throw new ForbiddenException('You are not assigned to this booking');
    }
    if (booking.lane !== 'INSPECTION') {
      throw new BadRequestException(
        'This booking is not an INSPECTION lane booking.',
      );
    }
    if (booking.status !== 'IN_PROGRESS') {
      throw new BadRequestException(
        'Start the inspection before submitting a report.',
      );
    }

    const existing = await this.repository.findByBookingId(bookingId);
    if (existing) {
      throw new ConflictException(
        'An inspection report has already been submitted for this booking.',
      );
    }

    if (photos.length > MAX_PHOTOS) {
      throw new BadRequestException(`Maximum ${MAX_PHOTOS} photos allowed.`);
    }

    const parts = dto.parts ?? [];
    if (dto.partsNeeded && parts.length === 0) {
      throw new BadRequestException(
        'Add at least one part when parts are needed.',
      );
    }
    const partsWithTotals = parts.map((p) => ({
      ...p,
      lineTotal: p.quantity * p.unitPrice,
    }));
    const partsTotal = partsWithTotals.reduce((sum, p) => sum + p.lineTotal, 0);
    // Deliberately NOT reduced by the inspection fee already paid — that is
    // shown as a separate informational line in the UI.
    const repairQuoteTotal = dto.labourCost + partsTotal;

    const [uploaded, uploadedVoiceNote] = await Promise.all([
      Promise.all(
        photos.map((file) =>
          this.storageService.uploadFile(
            file.buffer,
            file.originalname,
            file.mimetype,
            `uploads/bookings/${bookingId}/inspection-report`,
          ),
        ),
      ),
      voiceNote
        ? this.storageService.uploadFile(
            voiceNote.buffer,
            voiceNote.originalname,
            voiceNote.mimetype,
            `uploads/bookings/${bookingId}/inspection-report/voice`,
          )
        : Promise.resolve(null),
    ]);

    const report = await this.repository.createReport({
      bookingId,
      workerProfileId: workerProfile.id,
      issueFound: dto.issueFound ?? null,
      recommendedRepair: dto.recommendedRepair ?? null,
      labourCost: dto.labourCost,
      partsNeeded: dto.partsNeeded,
      partsTotal,
      repairQuoteTotal,
      notes: dto.notes,
      parts: partsWithTotals,
      photos: uploaded.map((u) => ({ url: u.url, storageKey: u.key })),
      voiceNoteUrl: uploadedVoiceNote?.url ?? null,
      voiceNoteStorageKey: uploadedVoiceNote?.key ?? null,
      voiceNoteMimeType: uploadedVoiceNote?.mimeType ?? null,
      voiceNoteDurationSeconds: uploadedVoiceNote
        ? dto.voiceNoteDurationSeconds ?? null
        : null,
    });

    if (booking.clientProfile?.userId) {
      void this.notificationsService.notify({
        userId: booking.clientProfile.userId,
        eventKey: 'booking.inspection.report_submitted',
        title: 'Inspection Report Ready',
        body: 'Ustaad ne inspection report submit kar di hai. Quote dekhein.',
        bookingId,
        route: `/client/booking/${bookingId}`,
        actorUserId: userId,
        actorRole: 'WORKER',
        entityType: 'booking',
        entityId: bookingId,
      });
    }

    return this._toDto(report, booking);
  }

  /** GET /bookings/:id/inspection-report — client (owner), assigned worker, or admin. */
  async getReport(
    userId: string,
    role: string,
    bookingId: string,
  ): Promise<InspectionReportResponseDto> {
    const booking = await this.repository.findBookingContext(bookingId);
    if (!booking) throw new NotFoundException('Booking not found');

    if (role === 'CLIENT' && booking.clientProfile?.userId !== userId) {
      throw new ForbiddenException('Not your booking');
    }
    if (role === 'WORKER' && booking.workerProfile?.userId !== userId) {
      throw new ForbiddenException('You are not assigned to this booking');
    }

    const report = await this.repository.findByBookingId(bookingId);
    if (!report) {
      throw new NotFoundException('No inspection report for this booking yet.');
    }

    return this._toDto(report, booking);
  }

  /** POST /bookings/:id/inspection-report/accept — client only. */
  async acceptQuote(
    userId: string,
    bookingId: string,
  ): Promise<InspectionReportResponseDto> {
    const { booking, report } = await this._authorizeClientDecision(
      userId,
      bookingId,
    );
    const updated = await this.repository.markAccepted(report.id);

    // Inspection fee is waived once repair continues — the confirmed final
    // amount becomes the repair quote only (never combined with the fee).
    await this.bookingsService.setInspectionRepairPrice(
      bookingId,
      updated.repairQuoteTotal,
    );

    if (booking.workerProfile?.userId) {
      void this.notificationsService.notify({
        userId: booking.workerProfile.userId,
        eventKey: 'booking.inspection.quote_accepted',
        title: 'Quote Accepted',
        body: 'Client ne aap ka quote accept kar liya hai. Repair continue karein.',
        bookingId,
        route: `/worker/job/${bookingId}`,
        actorUserId: userId,
        actorRole: 'CLIENT',
        entityType: 'booking',
        entityId: bookingId,
      });
    }

    return this._toDto(updated, booking);
  }

  /** POST /bookings/:id/inspection-report/close — client only. */
  async closeAfterInspection(
    userId: string,
    bookingId: string,
  ): Promise<InspectionReportResponseDto> {
    const { booking, report } = await this._authorizeClientDecision(
      userId,
      bookingId,
    );
    const updated = await this.repository.markClosed(report.id);
    // Booking completion + client/worker notifications for the close path
    // live in BookingsService, reusing its existing completion write.
    await this.bookingsService.completeAfterInspectionClose(bookingId);

    return this._toDto(updated, booking);
  }

  private async _authorizeClientDecision(userId: string, bookingId: string) {
    const booking = await this.repository.findBookingContext(bookingId);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.clientProfile?.userId !== userId) {
      throw new ForbiddenException('Not your booking');
    }
    const report = await this.repository.findByBookingId(bookingId);
    if (!report) {
      throw new NotFoundException('No inspection report for this booking yet.');
    }
    if (report.decisionStatus !== 'PENDING_CLIENT_DECISION') {
      throw new BadRequestException(
        `This report has already been decided (${report.decisionStatus}).`,
      );
    }
    return { booking, report };
  }

  private _toDto(
    report: InspectionReportWithRelations,
    booking: InspectionBookingContext,
  ): InspectionReportResponseDto {
    return {
      id: report.id,
      bookingId: report.bookingId,
      workerProfileId: report.workerProfileId,
      issueFound: report.issueFound,
      recommendedRepair: report.recommendedRepair,
      labourCost: report.labourCost,
      partsNeeded: report.partsNeeded,
      partsTotal: report.partsTotal,
      repairQuoteTotal: report.repairQuoteTotal,
      inspectionFeeSnapshot: booking.inspectionFeeSnapshot ?? null,
      notes: report.notes ?? null,
      voiceNoteUrl: report.voiceNoteUrl ?? null,
      voiceNoteMimeType: report.voiceNoteMimeType ?? null,
      voiceNoteDurationSeconds: report.voiceNoteDurationSeconds ?? null,
      decisionStatus: report.decisionStatus as
        | 'PENDING_CLIENT_DECISION'
        | 'ACCEPTED_REPAIR'
        | 'CLOSED_AFTER_INSPECTION',
      parts: report.parts.map((p) => ({
        id: p.id,
        name: p.name,
        quantity: p.quantity,
        unitPrice: p.unitPrice,
        warranty: p.warranty ?? null,
        lineTotal: p.lineTotal,
      })),
      photos: report.photos.map((ph) => ({
        id: ph.id,
        url: ph.url,
        createdAt: ph.createdAt.toISOString(),
      })),
      createdAt: report.createdAt.toISOString(),
      acceptedAt: report.acceptedAt?.toISOString() ?? null,
      closedAt: report.closedAt?.toISOString() ?? null,
    };
  }
}
