import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

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
    return this.prisma.inspectionReport.create({
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
  }

  async markAccepted(reportId: string): Promise<InspectionReportWithRelations> {
    return this.prisma.inspectionReport.update({
      where: { id: reportId },
      data: { decisionStatus: 'ACCEPTED_REPAIR', acceptedAt: new Date() },
      include: INSPECTION_REPORT_INCLUDE,
    });
  }

  async markClosed(reportId: string): Promise<InspectionReportWithRelations> {
    return this.prisma.inspectionReport.update({
      where: { id: reportId },
      data: { decisionStatus: 'CLOSED_AFTER_INSPECTION', closedAt: new Date() },
      include: INSPECTION_REPORT_INCLUDE,
    });
  }

  // NOTE: the FIND_OTHER_USTAAD decision transition deliberately has no
  // repository method here — it happens exclusively inside
  // BookingsRepository.closeInspectionAndOpenRepairBidding's transaction so
  // the report flip, booking completion, worker release, and linked child
  // creation can never be observed in a partial state.
}
