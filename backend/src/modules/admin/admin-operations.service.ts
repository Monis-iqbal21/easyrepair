import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
  Optional,
  forwardRef,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  BookingLane,
  BookingStatus,
  CommissionCollectionStatus,
  InspectionDecisionStatus,
  SettlementCaseType,
  SettlementSource,
} from '@prisma/client';
import { settleBooking } from '../../common/utils/commission.util';
import {
  AdminOperationsRepository,
  CollectedCollectionImmutableError,
  SettlementAlreadyCollectedError,
  SettlementWriteConflictError,
} from './admin-operations.repository';
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
import type { ClientCashPaymentConfirmationDto } from '../bookings/dto/confirm-cash-payment.dto';
import type { UstaadPaymentReportDto } from '../workers/dto/report-received-payment.dto';
import {
  NOTIFICATION_KEYS,
  getNotificationTemplate,
} from '../notifications/notification-templates';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class AdminOperationsService {
  private readonly logger = new Logger(AdminOperationsService.name);

  constructor(
    private readonly repository: AdminOperationsRepository,
    @Optional() private readonly config?: ConfigService,
    // Optional + forwardRef: the settlement service sits underneath both the
    // Admin and the Booking/Worker routes, and NotificationsModule reaches
    // back here through Chat → Bookings. Optional also keeps the existing
    // unit tests constructing this service with the repository alone.
    @Optional()
    @Inject(forwardRef(() => NotificationsService))
    private readonly notifications?: NotificationsService,
  ) {}

  async listBookings(query: ListAdminBookingsQueryDto) {
    const result = await this.repository.listBookings(query);
    return { ...result, page: query.page, pageSize: query.pageSize };
  }

  async getBooking(id: string) {
    const booking = await this.repository.findBooking(id);
    if (!booking) throw new NotFoundException('Booking not found');
    return booking;
  }

  createSettlement(
    bookingId: string,
    dto: CreateSettlementDto,
    actorUserId: string,
  ) {
    return this.persistSettlement(bookingId, dto, actorUserId);
  }

  async confirmClientCashPayment(
    bookingId: string,
    receivedCashTotal: number,
    clientUserId: string,
  ): Promise<ClientCashPaymentConfirmationDto> {
    const booking = await this.repository.findBooking(bookingId);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.clientProfile?.user?.id !== clientUserId) {
      throw new ForbiddenException('Not your booking');
    }

    const current = booking.settlements.find((row) => row.isCurrent);
    if (current) {
      return this.resolveClientConfirmationRetry(
        current,
        receivedCashTotal,
        clientUserId,
      );
    }
    if (booking.status !== BookingStatus.COMPLETED) {
      throw new BadRequestException(
        'Cash payment can only be confirmed for a completed booking',
      );
    }

    try {
      const created = await this.persistSettlement(
        bookingId,
        {
          received: receivedCashTotal,
          source: SettlementSource.CLIENT,
        },
        clientUserId,
      );
      return this.toClientConfirmation(created);
    } catch (error) {
      // A concurrent mobile retry can lose the partial-unique-index race.
      // Resolve it against the winner and return it only when it is the exact
      // same CLIENT confirmation; all other changes require Admin correction.
      if (error instanceof ConflictException) {
        const refreshed = await this.repository.findBooking(bookingId);
        const winner = refreshed?.settlements.find((row) => row.isCurrent);
        if (winner) {
          return this.resolveClientConfirmationRetry(
            winner,
            receivedCashTotal,
            clientUserId,
          );
        }
      }
      throw error;
    }
  }

  /**
   * FIX 3 — "kam paisa mila". The assigned Ustaad declares the cash they
   * actually received for their own completed job.
   *
   * Deliberately the SAME `persistSettlement` path the Client confirmation
   * and the Admin correction use, only with `SettlementSource.USTAAD` (an
   * enum member the schema has always carried for exactly this). There is no
   * second payment model and no second place money is computed: the app posts
   * one fact, `settleBooking` allocates it, and the shortfall / settlement
   * case fall out of the same waterfall as before.
   *
   * Idempotent in the same shape as the Client path — a retry of the exact
   * same declaration returns the winning settlement instead of a conflict.
   */
  async reportUstaadCashPayment(
    bookingId: string,
    receivedCashTotal: number,
    workerUserId: string,
  ): Promise<UstaadPaymentReportDto> {
    const booking = await this.repository.findBooking(bookingId);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.workerProfile?.user?.id !== workerUserId) {
      throw new ForbiddenException('Not your job');
    }

    const current = booking.settlements.find((row) => row.isCurrent);
    if (current) {
      return this.resolveUstaadReportRetry(current, receivedCashTotal);
    }
    if (booking.status !== BookingStatus.COMPLETED) {
      throw new BadRequestException(
        'Payment can only be reported for a completed job',
      );
    }

    try {
      const created = await this.persistSettlement(
        bookingId,
        { received: receivedCashTotal, source: SettlementSource.USTAAD },
        workerUserId,
      );
      return this.toUstaadReport(created);
    } catch (error) {
      // Same partial-unique-index race the mobile Client path can lose.
      if (error instanceof ConflictException) {
        const refreshed = await this.repository.findBooking(bookingId);
        const winner = refreshed?.settlements.find((row) => row.isCurrent);
        if (winner) {
          return this.resolveUstaadReportRetry(winner, receivedCashTotal);
        }
      }
      throw error;
    }
  }

  private resolveUstaadReportRetry(
    settlement: any,
    receivedCashTotal: number,
  ): UstaadPaymentReportDto {
    if (settlement.received === receivedCashTotal) {
      // Same number, whoever recorded it first — the Ustaad's declaration is
      // already the truth on file, so the retry succeeds.
      return this.toUstaadReport(settlement);
    }
    throw new ConflictException(
      'This job already has a recorded payment of a different amount; Admin correction is required',
    );
  }

  private toUstaadReport(settlement: any): UstaadPaymentReportDto {
    return {
      settlementId: settlement.id,
      bookingId: settlement.bookingId,
      expectedTotal: settlement.expectedTotal,
      receivedCashTotal: settlement.received,
      partsPaid: settlement.partsPaid,
      labourPaid: settlement.labourPaid,
      feePaid: settlement.feePaid,
      commission: settlement.commission,
      munafa: settlement.munafa,
      shortfall: settlement.shortfall,
      recordedAt: settlement.settledAt,
      isCurrent: true,
    };
  }

  /**
   * FIX 2 — tell the Ustaad what the client actually paid.
   *
   * Fired only for a settlement the Ustaad did NOT record themselves (a
   * Client confirmation or an Admin correction); self-reporting "kam paisa
   * mila" must not push a notification back at the person who just typed it.
   *
   * Idempotency is the notification table's own, via
   * `wasAlreadyNotified(userId, bookingId, eventKey)` — the same dedupe every
   * other booking-lifecycle push uses. A retried client confirmation, a queue
   * redelivery or a double tap therefore all collapse to one push. Paid and
   * short are distinct event keys on purpose: a short payment later corrected
   * to paid-in-full is a genuinely new thing to say, and dedupes only against
   * its own key.
   *
   * Never throws — a settlement is authoritative money and must not fail
   * because a push did.
   */
  private async notifyWorkerOfPayment(
    booking: any,
    settlement: any,
  ): Promise<void> {
    const workerUserId = booking?.workerProfile?.user?.id;
    if (!this.notifications || !workerUserId) return;

    const shortfall = settlement?.shortfall ?? 0;
    const eventKey =
      shortfall > 0
        ? NOTIFICATION_KEYS.PAYMENT_SHORT
        : NOTIFICATION_KEYS.PAYMENT_RECEIVED;

    try {
      const already = await this.notifications.wasAlreadyNotified(
        workerUserId,
        booking.id,
        eventKey,
      );
      if (already) return;

      const { title, body } = getNotificationTemplate(eventKey, {
        received: settlement.received,
        shortfall,
        expected: settlement.expectedTotal,
      });

      await this.notifications.notify({
        userId: workerUserId,
        eventKey,
        title,
        body,
        bookingId: booking.id,
        // Same worker deep link every other job notification uses, so an old
        // APK that has never heard of these two event keys still lands on the
        // right screen.
        route: `/worker/job/${booking.id}`,
        entityType: 'booking',
        entityId: booking.id,
        payload: {
          receivedAmount: settlement.received,
          expectedAmount: settlement.expectedTotal,
          shortfall,
        },
      });
    } catch (err) {
      this.logger.warn(
        `Payment notification failed for bookingId=${booking.id}: ${err}`,
      );
    }
  }

  private resolveClientConfirmationRetry(
    settlement: any,
    receivedCashTotal: number,
    clientUserId: string,
  ): ClientCashPaymentConfirmationDto {
    if (
      settlement.source === SettlementSource.CLIENT &&
      settlement.settledByUserId === clientUserId &&
      settlement.received === receivedCashTotal
    ) {
      return this.toClientConfirmation(settlement);
    }
    throw new ConflictException(
      settlement.received === receivedCashTotal
        ? 'Booking already has a settlement; Admin correction is required'
        : 'Cash payment was already confirmed with a different amount; Admin correction is required',
    );
  }

  private toClientConfirmation(
    settlement: any,
  ): ClientCashPaymentConfirmationDto {
    return {
      settlementId: settlement.id,
      bookingId: settlement.bookingId,
      receivedCashTotal: settlement.received,
      expectedTotal: settlement.expectedTotal,
      shortfall: settlement.shortfall,
      recordedAt: settlement.settledAt,
      confirmationStatus: 'CONFIRMED',
      isCurrent: true,
    };
  }

  correctSettlement(
    bookingId: string,
    dto: CorrectSettlementDto,
    actorUserId: string,
  ) {
    return this.persistSettlement(
      bookingId,
      dto,
      actorUserId,
      dto.supersedesId,
    );
  }

  private async persistSettlement(
    bookingId: string,
    dto: CreateSettlementDto,
    actorUserId: string,
    supersedesId?: string,
  ) {
    const booking = await this.repository.findBooking(bookingId);
    if (!booking) throw new NotFoundException('Booking not found');
    const settleableStatuses: BookingStatus[] = [
      BookingStatus.COMPLETED,
      BookingStatus.AWAITING_CONFIRMATION,
      BookingStatus.SETTLED,
    ];
    if (!settleableStatuses.includes(booking.status)) {
      throw new BadRequestException('Only completed bookings can be settled');
    }
    if (!booking.workerProfileId)
      throw new BadRequestException('Booking has no assigned worker');

    const current = booking.settlements.find((row) => row.isCurrent);
    if (supersedesId) {
      if (!current || current.id !== supersedesId) {
        throw new ConflictException(
          'A correction must supersede the current settlement',
        );
      }
      if (current.collectionItems.length > 0) {
        throw new ConflictException(
          'A settlement cannot be corrected after commission collection',
        );
      }
    } else if (current) {
      throw new ConflictException(
        'Booking already has a current settlement; create a correction instead',
      );
    }

    const expected = this.expectedMoney(booking);
    let calculation;
    try {
      calculation = settleBooking({ ...expected, received: dto.received });
    } catch (error) {
      if (error instanceof RangeError) {
        throw new BadRequestException(error.message);
      }
      throw error;
    }
    const caseTypes = calculation.caseTypes.filter(
      (type): type is SettlementCaseType => type !== 'AUTO_SETTLE',
    );
    try {
      const settlement = await this.repository.createSettlement(
        {
          bookingId,
          workerProfileId: booking.workerProfileId,
          supersedesId,
          expectedParts: expected.quoteParts,
          expectedLabour: expected.quoteLabour,
          expectedFee: expected.inspectionFee,
          expectedTotal: calculation.expectedTotal,
          received: dto.received,
          source: dto.source,
          partsPaid: calculation.partsPaid,
          labourPaid: calculation.labourPaid,
          feePaid: calculation.feePaid,
          commission: calculation.commission,
          munafa: calculation.munafa,
          shortfall: calculation.shortfall,
          handygoPays: calculation.handygoPays,
          note: dto.note?.trim() || null,
          settledByUserId: actorUserId,
        },
        caseTypes,
        actorUserId,
      );
      // FIX 2 — one place every authoritative settlement write passes
      // through, so a Client confirmation and an Admin correction both tell
      // the Ustaad the same truth. Skipped when the Ustaad is the actor:
      // they are the one who just typed the amount.
      if (actorUserId !== booking.workerProfile?.user?.id) {
        await this.notifyWorkerOfPayment(booking, settlement);
      }
      return settlement;
    } catch (error: any) {
      if (
        error instanceof SettlementWriteConflictError ||
        error?.code === 'P2002'
      ) {
        throw new ConflictException(
          'The current settlement changed; reload before trying again',
        );
      }
      if (error instanceof SettlementAlreadyCollectedError) {
        throw new ConflictException(
          'A settlement cannot be corrected after commission collection',
        );
      }
      throw error;
    }
  }

  private expectedMoney(booking: any) {
    if (booking.lane !== BookingLane.INSPECTION) {
      if (booking.finalPrice === null)
        throw new BadRequestException('Booking final price is missing');
      return {
        quoteParts: 0,
        quoteLabour: booking.finalPrice,
        inspectionFee: 0,
      };
    }
    const report = booking.inspectionReport;
    if (report?.decisionStatus === InspectionDecisionStatus.ACCEPTED_REPAIR) {
      return {
        quoteParts: report.partsTotal,
        quoteLabour: report.labourCost,
        inspectionFee: 0,
      };
    }
    return {
      quoteParts: 0,
      quoteLabour: 0,
      inspectionFee: booking.inspectionFeeSnapshot ?? booking.finalPrice ?? 0,
    };
  }

  async listCases(query: ListSettlementCasesQueryDto) {
    const result = await this.repository.listCases(query);
    return { ...result, page: query.page, pageSize: query.pageSize };
  }

  async getCase(id: string) {
    const result = await this.repository.findCase(id);
    if (!result) throw new NotFoundException('Settlement case not found');
    return result;
  }

  async updateCase(
    id: string,
    dto: UpdateSettlementCaseDto,
    actorUserId: string,
  ) {
    await this.getCase(id);
    if (!dto.status && !dto.priority && !dto.assignedToUserId)
      throw new BadRequestException('At least one case field is required');
    await this.repository.updateCase(id, dto, actorUserId);
    return this.getCase(id);
  }

  async addNote(
    id: string,
    dto: AddSettlementCaseNoteDto,
    actorUserId: string,
  ) {
    await this.getCase(id);
    if (!dto.body.trim())
      throw new BadRequestException('Note body cannot be empty');
    return this.repository.addNote(id, dto.body.trim(), actorUserId);
  }

  async addContact(id: string, dto: AddContactAttemptDto, actorUserId: string) {
    await this.getCase(id);
    return this.repository.addContact(
      id,
      {
        channel: dto.channel,
        outcome: dto.outcome,
        note: dto.note?.trim() || undefined,
        followUpAt: dto.followUpAt ? new Date(dto.followUpAt) : undefined,
      },
      actorUserId,
    );
  }

  async runNightly(dto: RunNightlyCollectionDto, actorUserId: string | null) {
    const dateText = dto.collectionDate ?? this.currentBusinessDate();
    const collectionDate = new Date(`${dateText.slice(0, 10)}T00:00:00.000Z`);
    const existing =
      await this.repository.findCollectionsForDate(collectionDate);
    const eligible = await this.repository.findEligibleSettlements();
    const groups = new Map<
      string,
      { settlementId: string; amount: number }[]
    >();
    for (const settlement of eligible) {
      const items = groups.get(settlement.workerProfileId) ?? [];
      items.push({
        settlementId: settlement.id,
        amount: settlement.commission,
      });
      groups.set(settlement.workerProfileId, items);
    }
    const generated = await this.repository.createNightlyCollections(
      collectionDate,
      actorUserId,
      groups,
    );
    const byId = new Map(existing.map((item) => [item.id, item]));
    for (const item of generated) byId.set(item.id, item);
    const collections = [...byId.values()];
    return {
      collectionDate: dateText.slice(0, 10),
      workerCount: collections.length,
      totalAmount: collections.reduce((sum, item) => sum + item.amount, 0),
      collections,
    };
  }

  private currentBusinessDate(): string {
    const timeZone =
      this.config?.get<string>('business.timezone') ?? 'Asia/Karachi';
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).formatToParts(new Date());
    const value = (type: Intl.DateTimeFormatPartTypes) =>
      parts.find((part) => part.type === type)?.value;
    return `${value('year')}-${value('month')}-${value('day')}`;
  }

  async listCollections(query: ListCollectionsQueryDto) {
    const result = await this.repository.listCollections(query);
    return { ...result, page: query.page, pageSize: query.pageSize };
  }

  async updateCollection(id: string, dto: UpdateCollectionDto) {
    if (
      dto.status === CommissionCollectionStatus.FAILED &&
      !dto.failureReason?.trim()
    ) {
      throw new BadRequestException(
        'failureReason is required when collection fails',
      );
    }
    if (dto.status === CommissionCollectionStatus.PENDING)
      throw new BadRequestException(
        'A collection cannot be moved back to PENDING',
      );
    try {
      return await this.repository.updateCollection(
        id,
        dto.status,
        dto.failureReason?.trim(),
      );
    } catch (error: any) {
      if (error instanceof CollectedCollectionImmutableError) {
        throw new ConflictException(
          'A collected commission cannot change status',
        );
      }
      if (error?.code === 'P2025')
        throw new NotFoundException('Commission collection not found');
      throw error;
    }
  }
}
