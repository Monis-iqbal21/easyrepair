import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  BookingLane,
  BookingStatus,
  CommissionCollectionStatus,
  InspectionDecisionStatus,
  SettlementCaseType,
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

@Injectable()
export class AdminOperationsService {
  constructor(
    private readonly repository: AdminOperationsRepository,
    @Optional() private readonly config?: ConfigService,
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
      return await this.repository.createSettlement(
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
