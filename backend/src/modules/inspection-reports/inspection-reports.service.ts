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
import {
  InspectionReportResponseDto,
  SanitizedInspectionReportResponseDto,
} from './dto/inspection-report-response.dto';
import { StorageService } from '../storage/storage.service';
import { NotificationsService } from '../notifications/notifications.service';
import { BookingsService } from '../bookings/bookings.service';
import { assertEligibleForInspectionBidding } from '../../common/utils/inspection-bidder-eligibility.util';

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
    if (!workerProfile)
      throw new ForbiddenException('Worker profile not found');

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
        ? (dto.voiceNoteDurationSeconds ?? null)
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

  /**
   * GET /bookings/:id/inspection-report — client (owner), the inspecting
   * worker, admin, or (during/after "Find Other Ustaad") an eligible bidder
   * or the hired-but-different repair worker. Only the client, an admin, and
   * the ORIGINAL INSPECTING worker ever see the full report with pricing —
   * a hired different worker or a not-yet-hired bidder always gets the
   * sanitized view, since neither should see the inspector's original
   * quote/prices.
   */
  async getReport(
    userId: string,
    role: string,
    bookingId: string,
  ): Promise<
    InspectionReportResponseDto | SanitizedInspectionReportResponseDto
  > {
    let booking = await this.repository.findBookingContext(bookingId);
    if (!booking) throw new NotFoundException('Booking not found');

    // A linked repair booking has no report of its own — the report always
    // lives on the source inspection booking, so "Inspection Report Dekhein"
    // works with either id.
    if (booking.sourceInspectionBookingId) {
      const source = await this.repository.findBookingContext(
        booking.sourceInspectionBookingId,
      );
      if (source) booking = source;
    }

    if (role === 'CLIENT' && booking.clientProfile?.userId !== userId) {
      throw new ForbiddenException('Not your booking');
    }

    if (role === 'WORKER') {
      const workerProfile =
        await this.repository.findWorkerProfileByUserId(userId);
      const report = await this.repository.findByBookingId(booking.id);

      // The original inspector always sees their own full report — even
      // long after Booking.workerProfileId has moved to a different Ustaad
      // (e.g. opening it from their own completed-jobs history). Checked
      // before the "currently assigned" branch below, otherwise this exact
      // case would incorrectly fall into the bidder path and get rejected
      // by that path's own-inspector exclusion.
      if (report && workerProfile?.id === report.workerProfileId) {
        return this._toDto(report, booking);
      }

      // "Assigned" means assigned to this inspection booking (old-style
      // same-row reassignment) or to its linked repair booking (new flow).
      const isAssignedHere = booking.workerProfile?.userId === userId;
      const isAssignedOnLinkedRepair =
        booking.repairBooking?.workerProfile?.userId === userId;
      if (!isAssignedHere && !isAssignedOnLinkedRepair) {
        // Not assigned and not the inspector — may still be an eligible
        // bidder while the repair job is open via "Find Other Ustaad".
        return this._getSanitizedReportForBidder(userId, booking);
      }

      if (!report) {
        throw new NotFoundException(
          'No inspection report for this booking yet.',
        );
      }
      // Assigned to perform the repair, but inspected by someone else —
      // still never expose that worker's original quote/prices.
      return this._toSanitizedDto(report);
    }

    // CLIENT / ADMIN
    const report = await this.repository.findByBookingId(booking.id);
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
      updated.labourCost,
    );

    if (booking.workerProfile?.userId) {
      void this.notificationsService.notify({
        userId: booking.workerProfile.userId,
        eventKey: 'booking.inspection.quote_accepted',
        title: 'Quote accept ho gaya hai',
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

  /**
   * POST /bookings/:id/inspection-report/find-other-ustaad — client only.
   * Third inspection outcome: atomically completes the inspector's work unit
   * (the original booking stays COMPLETED on the inspector forever, earning
   * the inspection fee exactly once) and spawns a linked BIDDING-lane child
   * booking for the repair, pre-filled from the report.
   *
   * Idempotent: a retry/double-tap with the report already in
   * FIND_OTHER_USTAAD returns the same linkedRepairBookingId as a success
   * (no duplicate booking/history/earnings/notifications) — only a genuinely
   * different decision (ACCEPTED_REPAIR / CLOSED_AFTER_INSPECTION) rejects.
   */
  async findOtherUstaad(
    userId: string,
    bookingId: string,
  ): Promise<InspectionReportResponseDto> {
    const booking = await this.repository.findBookingContext(bookingId);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.clientProfile?.userId !== userId) {
      throw new ForbiddenException('Not your booking');
    }
    const report = await this.repository.findByBookingId(bookingId);
    if (!report) {
      throw new NotFoundException('No inspection report for this booking yet.');
    }
    if (
      report.decisionStatus === 'ACCEPTED_REPAIR' ||
      report.decisionStatus === 'CLOSED_AFTER_INSPECTION'
    ) {
      throw new BadRequestException(
        `This report has already been decided (${report.decisionStatus}).`,
      );
    }

    // The child booking's problem description comes straight from the
    // report's findings — the client never re-enters anything.
    const composedDescription = [report.issueFound, report.recommendedRepair]
      .filter((s): s is string => !!s && s.trim().length > 0)
      .join('\n\n');

    // PENDING_CLIENT_DECISION and FIND_OTHER_USTAAD (retry) both go through
    // the same atomic method — its transactional guard is the authoritative
    // arbiter, even under a concurrent duplicate request.
    await this.bookingsService.closeInspectionAndOpenRepairBidding({
      reportId: report.id,
      originalBookingId: bookingId,
      inspectingWorkerProfileId: report.workerProfileId,
      clientProfileId: booking.clientProfileId,
      categoryId: booking.categoryId,
      title: booking.title,
      description:
        composedDescription.length > 0
          ? composedDescription
          : booking.description,
      addressLine: booking.addressLine,
      city: booking.city,
      latitude: booking.latitude,
      longitude: booking.longitude,
    });

    const freshBooking = await this.repository.findBookingContext(bookingId);
    const freshReport = await this.repository.findByBookingId(bookingId);
    if (!freshBooking || !freshReport) {
      throw new NotFoundException('Booking not found');
    }
    return this._toDto(freshReport, freshBooking);
  }

  /**
   * POST /bookings/:id/inspection-report/hire-inspector — client only.
   * Customer changed their mind during "Find Other Ustaad" and re-hires the
   * original inspecting worker using their already-submitted report/quote —
   * collapses back into the same outcome as "Accept Quote & Continue
   * Repair" (decisionStatus reverts to ACCEPTED_REPAIR), so completion and
   * earnings logic need no special-casing for this sub-case.
   */
  async hireInspectingWorker(
    userId: string,
    bookingId: string,
  ): Promise<InspectionReportResponseDto> {
    const ctx = await this.repository.findBookingContext(bookingId);
    if (!ctx) throw new NotFoundException('Booking not found');
    // Accept either the linked repair booking's id (new flow) or the
    // original inspection booking's id (old-style rows) — the report always
    // lives on the inspection booking.
    const booking = ctx.sourceInspectionBookingId
      ? await this.repository.findBookingContext(ctx.sourceInspectionBookingId)
      : ctx;
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.clientProfile?.userId !== userId) {
      throw new ForbiddenException('Not your booking');
    }
    const report = await this.repository.findByBookingId(booking.id);
    if (!report) {
      throw new NotFoundException('No inspection report for this booking yet.');
    }
    if (report.decisionStatus !== 'FIND_OTHER_USTAAD') {
      throw new BadRequestException(
        `This action is only available while finding another Ustaad (current: ${report.decisionStatus}).`,
      );
    }

    // New model: the open repair job is the linked child booking; old-style
    // rows are themselves the open booking.
    const targetBookingId = booking.repairBooking?.id ?? booking.id;

    // Atomic re-assignment (double-hire safe, with a fresh INSPECTOR_BUSY
    // availability check) lives in BookingsService, reusing the exact same
    // labour-only commission math as a normal accepted quote.
    await this.bookingsService.rehireInspectingWorker(
      userId,
      targetBookingId,
      report.workerProfileId,
      report.repairQuoteTotal,
      report.labourCost,
    );

    let updated = report;
    if (!booking.repairBooking) {
      // Old-style same-row flow only: collapses back into ACCEPTED_REPAIR.
      // The new linked flow must NOT do this — the completed inspection's
      // earning derives from decisionStatus staying FIND_OTHER_USTAAD
      // (inspection-fee base, see commission.util.ts); the rehired repair
      // is tracked entirely by the child booking.
      updated = await this.repository.markAccepted(report.id);
    }

    const freshBooking = await this.repository.findBookingContext(booking.id);
    if (!freshBooking) throw new NotFoundException('Booking not found');
    return this._toDto(updated, freshBooking);
  }

  private async _getSanitizedReportForBidder(
    userId: string,
    booking: InspectionBookingContext,
  ): Promise<SanitizedInspectionReportResponseDto> {
    const workerProfile =
      await this.repository.findWorkerProfileWithSkillsByUserId(userId);
    if (!workerProfile)
      throw new ForbiddenException('Worker profile not found');

    const report = await this.repository.findByBookingId(booking.id);
    if (!report) {
      throw new NotFoundException('No inspection report for this booking yet.');
    }
    if (report.decisionStatus !== 'FIND_OTHER_USTAAD') {
      throw new ForbiddenException('This job is no longer open for bidding.');
    }

    // Full approved/active/profile-completed/online/category/radius/fresh-GPS
    // gate, plus exclusion of the original inspecting worker — same standard
    // enforced at bid-creation time, so viewing the report can't be used to
    // sidestep the eligibility rules that gate bidding itself. When a linked
    // repair booking exists (new flow), the bidder is bidding on THAT
    // booking, so eligibility is checked against its category/location/
    // exclusions; old-style rows are themselves the open job.
    const biddingBooking = booking.repairBooking ?? booking;
    assertEligibleForInspectionBidding(
      workerProfile,
      biddingBooking,
      report.workerProfileId,
    );

    return this._toSanitizedDto(report);
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
        | 'CLOSED_AFTER_INSPECTION'
        | 'FIND_OTHER_USTAAD',
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
      linkedRepairBookingId: booking.repairBooking?.id ?? null,
    };
  }

  /** No labourCost/partsTotal/repairQuoteTotal/part-prices — bidder-safe view. */
  private _toSanitizedDto(
    report: InspectionReportWithRelations,
  ): SanitizedInspectionReportResponseDto {
    return {
      id: report.id,
      bookingId: report.bookingId,
      issueFound: report.issueFound,
      recommendedRepair: report.recommendedRepair,
      notes: report.notes ?? null,
      voiceNoteUrl: report.voiceNoteUrl ?? null,
      voiceNoteMimeType: report.voiceNoteMimeType ?? null,
      voiceNoteDurationSeconds: report.voiceNoteDurationSeconds ?? null,
      partsNeeded: report.partsNeeded,
      decisionStatus: report.decisionStatus as 'FIND_OTHER_USTAAD',
      parts: report.parts.map((p) => ({
        id: p.id,
        name: p.name,
        quantity: p.quantity,
        warranty: p.warranty ?? null,
      })),
      photos: report.photos.map((ph) => ({
        id: ph.id,
        url: ph.url,
        createdAt: ph.createdAt.toISOString(),
      })),
      createdAt: report.createdAt.toISOString(),
    };
  }
}
