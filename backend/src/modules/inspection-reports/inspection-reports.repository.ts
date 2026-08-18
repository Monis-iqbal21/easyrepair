import { Injectable } from '@nestjs/common';
import { InspectionDecisionStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { ATTACHABLE_INSPECTION_DECISION_STATUSES } from '../../common/utils/attachable-inspection.util';

export const INSPECTION_REPORT_INCLUDE = {
  parts: { orderBy: { createdAt: 'asc' as const } },
  photos: { orderBy: { createdAt: 'asc' as const } },
} satisfies Prisma.InspectionReportInclude;

export type InspectionReportWithRelations = Prisma.InspectionReportGetPayload<{
  include: typeof INSPECTION_REPORT_INCLUDE;
}>;

/** Minimal booking context needed to authorize/guard report actions. */
export type InspectionBookingContext = {
  id: string;
  lane: string;
  status: string;
  workerProfileId: string | null;
  clientProfileId: string;
  categoryId: string;
  title: string | null;
  description: string;
  addressLine: string;
  city: string;
  latitude: number;
  longitude: number;
  inspectionFeeSnapshot: number | null;
  clientProfile: { userId: string } | null;
  workerProfile: { userId: string } | null;
  workerExclusions: { workerProfileId: string }[];
  /** For a linked repair booking: the completed inspection it came from. */
  sourceInspectionBookingId: string | null;
  /** For an independently-posted BIDDING job: the historical inspection whose
   *  report the client manually attached. Informational only — never implies
   *  the post-inspection/Find-Other-Ustaad relationship above. */
  attachedInspectionBookingId: string | null;
  /** For a completed inspection: the linked repair booking spawned by
   *  "Find Other Ustaad", if any — bidder eligibility is checked against
   *  this booking's own category/location/exclusions. */
  repairBooking: {
    id: string;
    status: string;
    categoryId: string;
    latitude: number;
    longitude: number;
    workerExclusions: { workerProfileId: string }[];
    workerProfile: { userId: string } | null;
  } | null;
};

@Injectable()
export class InspectionReportsRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findWorkerProfileByUserId(userId: string) {
    return this.prisma.workerProfile.findUnique({ where: { userId } });
  }

  async findClientProfileByUserId(userId: string) {
    return this.prisma.clientProfile.findUnique({
      where: { userId },
      select: { id: true },
    });
  }

  /**
   * The authenticated client's own previously COMPLETED inspection bookings
   * that carry a submitted report — the selectable set for "attach a previous
   * inspection report" when posting a new BIDDING job.
   *
   * Eligibility is deliberately strict and entirely server-side:
   *  - the inspection booking belongs to THIS client (never another's);
   *  - lane is INSPECTION;
   *  - the booking actually reached COMPLETED (so the inspection finished and
   *    its fee was settled — never an in-flight or cancelled one);
   *  - an InspectionReport row exists (a report was genuinely submitted, so
   *    drafts/never-filled inspections are excluded);
   *  - the client has already made their decision on it — CLOSED_AFTER_
   *    INSPECTION (the case this feature exists for) or ACCEPTED_REPAIR (a
   *    finished repair whose report is still useful context). A report still
   *    at PENDING_CLIENT_DECISION or mid-FIND_OTHER_USTAAD is excluded: those
   *    are live decisions, not history.
   *
   * [categoryId] narrows to the same service as the job being posted.
   */
  async findClientCompletedInspections(params: {
    clientProfileId: string;
    categoryId?: string;
  }) {
    return this.prisma.booking.findMany({
      where: {
        clientProfileId: params.clientProfileId,
        lane: 'INSPECTION',
        status: 'COMPLETED',
        ...(params.categoryId ? { categoryId: params.categoryId } : {}),
        inspectionReport: {
          decisionStatus: {
            in: [...ATTACHABLE_INSPECTION_DECISION_STATUSES],
          },
        },
      },
      orderBy: { completedAt: 'desc' },
      select: {
        id: true,
        categoryId: true,
        completedAt: true,
        createdAt: true,
        category: { select: { id: true, name: true } },
        inspectionReport: {
          select: {
            id: true,
            issueFound: true,
            recommendedRepair: true,
            decisionStatus: true,
            createdAt: true,
          },
        },
      },
    });
  }


  /** Used only to authorize an eligible bidder's sanitized-report access. */
  async findWorkerProfileWithSkillsByUserId(userId: string) {
    return this.prisma.workerProfile.findUnique({
      where: { userId },
      include: { skills: { select: { categoryId: true } } },
    });
  }

  async findBookingContext(
    bookingId: string,
  ): Promise<InspectionBookingContext | null> {
    return this.prisma.booking.findUnique({
      where: { id: bookingId },
      select: {
        id: true,
        lane: true,
        status: true,
        workerProfileId: true,
        clientProfileId: true,
        categoryId: true,
        title: true,
        description: true,
        addressLine: true,
        city: true,
        latitude: true,
        longitude: true,
        inspectionFeeSnapshot: true,
        clientProfile: { select: { userId: true } },
        workerProfile: { select: { userId: true } },
        workerExclusions: { select: { workerProfileId: true } },
        sourceInspectionBookingId: true,
        attachedInspectionBookingId: true,
        repairBooking: {
          select: {
            id: true,
            status: true,
            categoryId: true,
            latitude: true,
            longitude: true,
            workerExclusions: { select: { workerProfileId: true } },
            workerProfile: { select: { userId: true } },
          },
        },
      },
    });
  }

  async findByBookingId(
    bookingId: string,
  ): Promise<InspectionReportWithRelations | null> {
    return this.prisma.inspectionReport.findUnique({
      where: { bookingId },
      include: INSPECTION_REPORT_INCLUDE,
    });
  }

  async createReport(data: {
    bookingId: string;
    workerProfileId: string;
    issueFound: string | null;
    recommendedRepair: string | null;
    labourCost: number;
    partsNeeded: boolean;
    partsTotal: number;
    repairQuoteTotal: number;
    notes?: string;
    parts: Array<{
      name: string;
      quantity: number;
      unitPrice: number;
      warranty?: string;
      lineTotal: number;
    }>;
    photos: Array<{ url: string; storageKey?: string }>;
    voiceNoteUrl?: string | null;
    voiceNoteStorageKey?: string | null;
    voiceNoteMimeType?: string | null;
    voiceNoteDurationSeconds?: number | null;
  }): Promise<InspectionReportWithRelations> {
    try {
      return await this.prisma.inspectionReport.create({
        data: {
          bookingId: data.bookingId,
          workerProfileId: data.workerProfileId,
          issueFound: data.issueFound,
          recommendedRepair: data.recommendedRepair,
          labourCost: data.labourCost,
          partsNeeded: data.partsNeeded,
          partsTotal: data.partsTotal,
          repairQuoteTotal: data.repairQuoteTotal,
          notes: data.notes ?? null,
          voiceNoteUrl: data.voiceNoteUrl ?? null,
          voiceNoteStorageKey: data.voiceNoteStorageKey ?? null,
          voiceNoteMimeType: data.voiceNoteMimeType ?? null,
          voiceNoteDurationSeconds: data.voiceNoteDurationSeconds ?? null,
          parts: {
            create: data.parts.map((p) => ({
              name: p.name,
              quantity: p.quantity,
              unitPrice: p.unitPrice,
              warranty: p.warranty ?? null,
              lineTotal: p.lineTotal,
            })),
          },
          photos: {
            create: data.photos.map((ph) => ({
              url: ph.url,
              storageKey: ph.storageKey ?? null,
            })),
          },
        },
        include: INSPECTION_REPORT_INCLUDE,
      });
    } catch (err) {
      // `InspectionReport.bookingId @unique` backs "one report per booking".
      // A genuine concurrent double-submit (the caller's own pre-check raced
      // another request creating the row first) hits that constraint
      // (P2002) — return the winning row instead of surfacing a raw 500 or
      // creating a duplicate report.
      if (
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === 'P2002'
      ) {
        const existing = await this.findByBookingId(data.bookingId);
        if (existing) return existing;
      }
      throw err;
    }
  }

  /**
   * Guarded by `decisionStatus IN fromStatuses` so two concurrent accept
   * requests (double-tap, a retry racing the original) can never both
   * "win" — only the request that actually flips the decision returns
   * `changed: true`; the caller decides whether the loser's outcome is a
   * safe idempotent no-op or a genuine conflict.
   *
   * `fromStatuses` varies by caller: acceptQuote transitions from
   * PENDING_CLIENT_DECISION; hireInspectingWorker's old-style-row branch
   * collapses back from FIND_OTHER_USTAAD.
   */
  async markAccepted(
    reportId: string,
    fromStatuses: InspectionDecisionStatus[] = ['PENDING_CLIENT_DECISION'],
  ): Promise<{ report: InspectionReportWithRelations; changed: boolean }> {
    const { count } = await this.prisma.inspectionReport.updateMany({
      where: { id: reportId, decisionStatus: { in: fromStatuses } },
      data: { decisionStatus: 'ACCEPTED_REPAIR', acceptedAt: new Date() },
    });
    const report = await this.prisma.inspectionReport.findUniqueOrThrow({
      where: { id: reportId },
      include: INSPECTION_REPORT_INCLUDE,
    });
    return { report, changed: count > 0 };
  }

  /**
   * Accept-quote's variant of `markAccepted`: the report transition AND the
   * booking's finalPrice/platformFee overwrite (waiving the inspection fee
   * for the repair quote — see BookingsService's former
   * setInspectionRepairPrice, folded in here) happen in ONE transaction.
   *
   * Doing these as two separate writes (the report flip, then a later
   * `booking.update`) left a real window: if the process crashed or errored
   * between them, the report could end up ACCEPTED_REPAIR while
   * finalPrice/platformFee stayed at the stale inspection-fee snapshot —
   * and since acceptQuote's idempotent short-circuit only checks
   * decisionStatus, a retry would never re-run the price update, silently
   * pricing the job on the fee forever. Wrapping both writes atomically
   * makes that impossible: either the whole accept succeeds with correct
   * pricing, or nothing happens and a retry can complete it properly.
   */
  async markAcceptedAndFinalizeRepairPrice(
    reportId: string,
    bookingId: string,
    repairQuoteTotal: number,
    platformFee: number,
  ): Promise<{ report: InspectionReportWithRelations; changed: boolean }> {
    const changed = await this.prisma.$transaction(async (tx) => {
      const { count } = await tx.inspectionReport.updateMany({
        where: { id: reportId, decisionStatus: 'PENDING_CLIENT_DECISION' },
        data: { decisionStatus: 'ACCEPTED_REPAIR', acceptedAt: new Date() },
      });
      if (count === 0) return false;

      await tx.booking.update({
        where: { id: bookingId },
        data: { finalPrice: repairQuoteTotal, platformFee },
      });

      return true;
    });

    const report = await this.prisma.inspectionReport.findUniqueOrThrow({
      where: { id: reportId },
      include: INSPECTION_REPORT_INCLUDE,
    });
    return { report, changed };
  }

  /** Same guarded-updateMany shape as markAccepted — see its doc comment. */
  async markClosed(
    reportId: string,
  ): Promise<{ report: InspectionReportWithRelations; changed: boolean }> {
    const { count } = await this.prisma.inspectionReport.updateMany({
      where: { id: reportId, decisionStatus: 'PENDING_CLIENT_DECISION' },
      data: { decisionStatus: 'CLOSED_AFTER_INSPECTION', closedAt: new Date() },
    });
    const report = await this.prisma.inspectionReport.findUniqueOrThrow({
      where: { id: reportId },
      include: INSPECTION_REPORT_INCLUDE,
    });
    return { report, changed: count > 0 };
  }

  // NOTE: the FIND_OTHER_USTAAD decision transition deliberately has no
  // repository method here — it happens exclusively inside
  // BookingsRepository.closeInspectionAndOpenRepairBidding's transaction so
  // the report flip, booking completion, worker release, and linked child
  // creation can never be observed in a partial state.
}
