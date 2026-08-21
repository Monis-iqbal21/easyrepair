import { Injectable } from '@nestjs/common';
import {
  BookingStatus,
  CommissionCollectionStatus,
  Prisma,
  SettlementCaseEventType,
  SettlementCaseType,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import {
  ListAdminBookingsQueryDto,
  ListCollectionsQueryDto,
  ListSettlementCasesQueryDto,
  UpdateSettlementCaseDto,
} from './dto/admin-operations.dto';

const bookingAdminInclude = {
  clientProfile: { include: { user: { select: { id: true, phone: true } } } },
  workerProfile: { include: { user: { select: { id: true, phone: true } } } },
  category: { select: { id: true, name: true } },
  inspectionReport: {
    select: { labourCost: true, partsTotal: true, decisionStatus: true },
  },
  settlements: {
    orderBy: { settledAt: 'desc' as const },
    include: {
      supersededBy: { select: { id: true } },
      collectionItems: { select: { id: true } },
    },
  },
} satisfies Prisma.BookingInclude;

export class SettlementWriteConflictError extends Error {}
export class SettlementAlreadyCollectedError extends Error {}
export class CollectedCollectionImmutableError extends Error {}

const caseDetailInclude = {
  booking: { select: { id: true, title: true, status: true, lane: true } },
  workerProfile: { include: { user: { select: { phone: true } } } },
  settlement: true,
  assignedTo: { select: { id: true, phone: true } },
  events: {
    orderBy: { createdAt: 'asc' as const },
    include: { actor: { select: { id: true, phone: true } } },
  },
  notes: {
    orderBy: { createdAt: 'asc' as const },
    include: { author: { select: { id: true, phone: true } } },
  },
  contactAttempts: {
    orderBy: { contactedAt: 'asc' as const },
    include: { actor: { select: { id: true, phone: true } } },
  },
} satisfies Prisma.SettlementCaseInclude;

@Injectable()
export class AdminOperationsRepository {
  constructor(private readonly prisma: PrismaService) {}

  async listBookings(query: ListAdminBookingsQueryDto) {
    const where: Prisma.BookingWhereInput = {};
    if (query.status) where.status = query.status;
    if (query.lane) where.lane = query.lane;
    if (query.workerProfileId) where.workerProfileId = query.workerProfileId;
    if (query.from || query.to) {
      where.createdAt = {
        ...(query.from ? { gte: new Date(query.from) } : {}),
        ...(query.to ? { lte: new Date(query.to) } : {}),
      };
    }
    const term = query.search?.trim();
    if (term) {
      where.OR = [
        { id: { contains: term, mode: 'insensitive' } },
        { title: { contains: term, mode: 'insensitive' } },
        { clientProfile: { user: { phone: { contains: term } } } },
        { workerProfile: { user: { phone: { contains: term } } } },
      ];
    }
    const [items, total] = await Promise.all([
      this.prisma.booking.findMany({
        where,
        include: bookingAdminInclude,
        orderBy: { createdAt: 'desc' },
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
      }),
      this.prisma.booking.count({ where }),
    ]);
    return { items, total };
  }

  findBooking(id: string) {
    return this.prisma.booking.findUnique({
      where: { id },
      include: bookingAdminInclude,
    });
  }

  async createSettlement(
    data: Prisma.BookingSettlementUncheckedCreateInput,
    caseTypes: SettlementCaseType[],
    actorUserId: string,
  ) {
    return this.prisma.$transaction(async (tx) => {
      if (data.supersedesId) {
        const current = await tx.bookingSettlement.findUnique({
          where: { id: data.supersedesId },
          select: {
            id: true,
            bookingId: true,
            isCurrent: true,
            collectionItems: { select: { id: true }, take: 1 },
            cases: { select: { id: true, status: true } },
          },
        });
        if (
          !current ||
          current.bookingId !== data.bookingId ||
          !current.isCurrent
        ) {
          throw new SettlementWriteConflictError(
            'A correction must supersede the current settlement',
          );
        }
        if (current.collectionItems.length > 0) {
          throw new SettlementAlreadyCollectedError(
            'A collected settlement cannot be corrected',
          );
        }

        const { count } = await tx.bookingSettlement.updateMany({
          where: { id: current.id, bookingId: data.bookingId, isCurrent: true },
          data: { isCurrent: false },
        });
        if (count !== 1) {
          throw new SettlementWriteConflictError(
            'The current settlement changed during correction',
          );
        }

        const casesToClose = current.cases.filter(
          (item) => item.status !== 'CLOSED',
        );
        if (casesToClose.length > 0) {
          const closedAt = new Date();
          await tx.settlementCase.updateMany({
            where: { id: { in: casesToClose.map((item) => item.id) } },
            data: { status: 'CLOSED', resolvedAt: closedAt },
          });
          await tx.settlementCaseEvent.createMany({
            data: casesToClose.map((item) => ({
              caseId: item.id,
              type: SettlementCaseEventType.RESOLVED,
              actorUserId,
              metadata: {
                reason: 'SETTLEMENT_SUPERSEDED',
                replacementPending: true,
              },
            })),
          });
        }
      }

      const settlement = await tx.bookingSettlement.create({ data });
      for (const type of caseTypes) {
        const settlementCase = await tx.settlementCase.create({
          data: {
            bookingId: settlement.bookingId,
            workerProfileId: settlement.workerProfileId,
            settlementId: settlement.id,
            type,
          },
        });
        await tx.settlementCaseEvent.create({
          data: {
            caseId: settlementCase.id,
            type: SettlementCaseEventType.CREATED,
            actorUserId,
          },
        });
      }
      return settlement;
    });
  }

  async listCases(query: ListSettlementCasesQueryDto) {
    const where: Prisma.SettlementCaseWhereInput = {
      ...(query.status ? { status: query.status } : {}),
      ...(query.type ? { type: query.type } : {}),
      ...(query.priority ? { priority: query.priority } : {}),
      ...(query.assignedToUserId
        ? { assignedToUserId: query.assignedToUserId }
        : {}),
      ...(query.workerProfileId
        ? { workerProfileId: query.workerProfileId }
        : {}),
    };
    const [items, total] = await Promise.all([
      this.prisma.settlementCase.findMany({
        where,
        include: caseDetailInclude,
        orderBy: { createdAt: 'desc' },
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
      }),
      this.prisma.settlementCase.count({ where }),
    ]);
    return { items, total };
  }

  findCase(id: string) {
    return this.prisma.settlementCase.findUnique({
      where: { id },
      include: caseDetailInclude,
    });
  }

  async updateCase(
    id: string,
    dto: UpdateSettlementCaseDto,
    actorUserId: string,
  ) {
    return this.prisma.$transaction(async (tx) => {
      const before = await tx.settlementCase.findUniqueOrThrow({
        where: { id },
      });
      const resolved = dto.status === 'RESOLVED' || dto.status === 'CLOSED';
      const updated = await tx.settlementCase.update({
        where: { id },
        data: {
          ...(dto.status
            ? { status: dto.status, resolvedAt: resolved ? new Date() : null }
            : {}),
          ...(dto.priority ? { priority: dto.priority } : {}),
          ...(dto.assignedToUserId
            ? { assignedToUserId: dto.assignedToUserId }
            : {}),
        },
      });
      if (dto.status && dto.status !== before.status) {
        const type =
          dto.status === 'RESOLVED' || dto.status === 'CLOSED'
            ? SettlementCaseEventType.RESOLVED
            : before.status === 'RESOLVED' || before.status === 'CLOSED'
              ? SettlementCaseEventType.REOPENED
              : SettlementCaseEventType.STATUS_CHANGED;
        await tx.settlementCaseEvent.create({
          data: {
            caseId: id,
            actorUserId,
            type,
            metadata: { from: before.status, to: dto.status },
          },
        });
      }
      if (
        dto.assignedToUserId &&
        dto.assignedToUserId !== before.assignedToUserId
      ) {
        await tx.settlementCaseEvent.create({
          data: {
            caseId: id,
            actorUserId,
            type: SettlementCaseEventType.ASSIGNED,
            metadata: { assignedToUserId: dto.assignedToUserId },
          },
        });
      }
      return updated;
    });
  }

  async addNote(caseId: string, body: string, actorUserId: string) {
    return this.prisma.$transaction(async (tx) => {
      const note = await tx.settlementCaseNote.create({
        data: { caseId, body, authorUserId: actorUserId },
      });
      await tx.settlementCaseEvent.create({
        data: {
          caseId,
          actorUserId,
          type: SettlementCaseEventType.NOTE_ADDED,
          metadata: { noteId: note.id },
        },
      });
      return note;
    });
  }

  async addContact(
    caseId: string,
    data: { channel: any; outcome: any; note?: string; followUpAt?: Date },
    actorUserId: string,
  ) {
    return this.prisma.$transaction(async (tx) => {
      const contact = await tx.settlementContactAttempt.create({
        data: { caseId, actorUserId, ...data },
      });
      await tx.settlementCaseEvent.create({
        data: {
          caseId,
          actorUserId,
          type: SettlementCaseEventType.CONTACT_ATTEMPTED,
          metadata: { contactAttemptId: contact.id, outcome: contact.outcome },
        },
      });
      return contact;
    });
  }

  findEligibleSettlements() {
    return this.prisma.bookingSettlement.findMany({
      where: {
        supersededBy: null,
        commission: { gt: 0 },
        booking: {
          status: { in: [BookingStatus.COMPLETED, BookingStatus.SETTLED] },
          commissionStatus: 'PENDING',
        },
        collectionItems: {
          none: {
            collection: {
              status: {
                in: [
                  CommissionCollectionStatus.PENDING,
                  CommissionCollectionStatus.COLLECTED,
                ],
              },
            },
          },
        },
      },
      orderBy: { settledAt: 'asc' },
    });
  }

  findCollectionsForDate(collectionDate: Date) {
    return this.prisma.commissionCollection.findMany({
      where: { collectionDate },
      include: { items: true },
      orderBy: { createdAt: 'asc' },
    });
  }

  async createNightlyCollections(
    collectionDate: Date,
    actorUserId: string | null,
    groups: Map<string, { settlementId: string; amount: number }[]>,
  ) {
    return this.prisma.$transaction(async (tx) => {
      const created: Prisma.CommissionCollectionGetPayload<{
        include: { items: true };
      }>[] = [];
      for (const [workerProfileId, items] of groups) {
        if (items.length === 0) continue;

        // Revalidate under row locks in the SAME transaction that inserts the
        // collection items. A correction updates this row's isCurrent flag,
        // so it must acquire the same Postgres row lock. Whichever operation
        // wins first determines the valid outcome: collection blocks the
        // correction via its new item, or correction makes this query exclude
        // the superseded row. Candidate amounts from the earlier scan are
        // deliberately ignored; the locked ledger rows are authoritative.
        const eligible = await tx.$queryRaw<
          { id: string; commission: number }[]
        >(Prisma.sql`
          SELECT bs."id", bs."commission"
          FROM "booking_settlements" bs
          INNER JOIN "bookings" b ON b."id" = bs."bookingId"
          WHERE bs."id" IN (${Prisma.join(items.map((item) => item.settlementId))})
            AND bs."workerProfileId" = ${workerProfileId}
            AND bs."isCurrent" = TRUE
            AND bs."commission" > 0
            AND b."status" IN ('COMPLETED'::"BookingStatus", 'SETTLED'::"BookingStatus")
            AND b."commissionStatus" = 'PENDING'::"CommissionStatus"
            AND NOT EXISTS (
              SELECT 1
              FROM "booking_settlements" replacement
              WHERE replacement."supersedesId" = bs."id"
            )
            AND NOT EXISTS (
              SELECT 1
              FROM "commission_collection_items" cci
              INNER JOIN "commission_collections" cc ON cc."id" = cci."collectionId"
              WHERE cci."settlementId" = bs."id"
                AND cc."status" IN (
                  'PENDING'::"CommissionCollectionStatus",
                  'COLLECTED'::"CommissionCollectionStatus"
                )
            )
          ORDER BY bs."settledAt" ASC
          FOR UPDATE OF bs
        `);
        if (eligible.length === 0) continue;

        const lockedItems = eligible.map((item) => ({
          settlementId: item.id,
          amount: item.commission,
        }));
        const amount = lockedItems.reduce((sum, item) => sum + item.amount, 0);
        const collection = await tx.commissionCollection.upsert({
          where: {
            workerProfileId_collectionDate: {
              workerProfileId,
              collectionDate,
            },
          },
          update: {},
          create: {
            workerProfileId,
            collectionDate,
            amount,
            createdByUserId: actorUserId,
            automated: actorUserId === null,
            items: { create: lockedItems },
          },
          include: { items: true },
        });
        created.push(collection);
      }
      return created;
    });
  }

  async listCollections(query: ListCollectionsQueryDto) {
    const where: Prisma.CommissionCollectionWhereInput = {
      ...(query.status ? { status: query.status } : {}),
      ...(query.workerProfileId
        ? { workerProfileId: query.workerProfileId }
        : {}),
      ...(query.collectionDate
        ? { collectionDate: new Date(query.collectionDate) }
        : {}),
    };
    const [items, total] = await Promise.all([
      this.prisma.commissionCollection.findMany({
        where,
        include: {
          items: { include: { settlement: true } },
          workerProfile: { include: { user: { select: { phone: true } } } },
        },
        orderBy: { createdAt: 'desc' },
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
      }),
      this.prisma.commissionCollection.count({ where }),
    ]);
    return { items, total };
  }

  async updateCollection(
    id: string,
    status: CommissionCollectionStatus,
    failureReason?: string,
  ) {
    return this.prisma.$transaction(async (tx) => {
      const before = await tx.commissionCollection.findUniqueOrThrow({
        where: { id },
        include: { items: { include: { settlement: true } } },
      });
      if (
        before.status === CommissionCollectionStatus.COLLECTED &&
        status !== CommissionCollectionStatus.COLLECTED
      ) {
        throw new CollectedCollectionImmutableError(
          'A collected commission cannot change status',
        );
      }
      if (before.status === status) return before;

      const collection = await tx.commissionCollection.update({
        where: { id },
        data: {
          status,
          failureReason: status === 'FAILED' ? failureReason : null,
          collectedAt: status === 'COLLECTED' ? new Date() : null,
        },
        include: { items: { include: { settlement: true } } },
      });
      if (status === CommissionCollectionStatus.COLLECTED) {
        const bookingIds = [
          ...new Set(collection.items.map((item) => item.settlement.bookingId)),
        ];
        await tx.booking.updateMany({
          where: { id: { in: bookingIds } },
          data: {
            commissionStatus: 'PAID',
            commissionStatusUpdatedAt: new Date(),
          },
        });
      }
      return collection;
    });
  }
}
