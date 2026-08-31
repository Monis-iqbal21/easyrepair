import { Injectable } from '@nestjs/common';
import { ComplaintsService } from '../complaints/complaints.service';
import { AdminClientsService } from './admin-clients.service';
import { AdminOperationsService } from './admin-operations.service';
import { AdminService } from './admin.service';
import {
  ListAdminBookingsQueryDto,
  ListCollectionsQueryDto,
  ListSettlementCasesQueryDto,
} from './dto/admin-operations.dto';
import { ListClientsQueryDto } from './dto/list-clients-query.dto';
import { ListWorkersQueryDto } from './dto/list-workers-query.dto';
import { ListComplaintsQueryDto } from '../complaints/dto/support-complaint.dto';
import { WorkerListItemDto } from './dto/worker-list-item.dto';
import { PendingWorkerResponseDto } from './dto/pending-worker-response.dto';
import type { BookingSettlement } from '@prisma/client';

type AdminBooking = Awaited<ReturnType<AdminOperationsService['getBooking']>>;
type AdminSettlementCase = Awaited<
  ReturnType<AdminOperationsService['getCase']>
>;
type AdminCollection = Awaited<
  ReturnType<AdminOperationsService['listCollections']>
>['items'][number];
type AdminComplaint = Awaited<ReturnType<ComplaintsService['get']>>;
type WorkerSummarySource = WorkerListItemDto | PendingWorkerResponseDto;

/**
 * Thin read-only adapter over authoritative services. Every response is built
 * field-by-field: adding a sensitive field to a core service cannot make it
 * appear here accidentally.
 */
@Injectable()
export class AdminReadonlyService {
  constructor(
    private readonly admin: AdminService,
    private readonly clients: AdminClientsService,
    private readonly operations: AdminOperationsService,
    private readonly complaints: ComplaintsService,
  ) {}

  async getStats() {
    const stats = await this.admin.getStats();
    return {
      pendingUstaads: stats.pendingUstaads,
      approvedUstaads: stats.approvedUstaads,
      rejectedUstaads: stats.rejectedUstaads,
      changesRequiredUstaads: stats.changesRequiredUstaads,
      totalWorkers: stats.totalWorkers,
      totalUsers: stats.totalUsers,
    };
  }

  async listWorkers(query: ListWorkersQueryDto) {
    const result = await this.admin.getWorkers(query);
    return {
      items: result.items.map((item) => this.workerSummary(item)),
      meta: result.meta,
    };
  }

  async getWorker(id: string) {
    const worker = await this.admin.getWorkerById(id);
    return {
      ...this.workerSummary(worker),
      skills: worker.skills.map((skill) => ({
        categoryId: skill.category.id,
        categoryName: skill.category.name,
        yearsExperience: skill.yearsExperience,
      })),
      faceMatchStatus: worker.faceMatchStatus,
      trainingStatus: worker.trainingStatus,
      legalNameConfirmed: worker.legalNameConfirmedAt !== null,
      generalAgreementAccepted: worker.generalAgreementAcceptedAt !== null,
      tradeAgreementAccepted: worker.tradeAgreementAcceptedAt !== null,
      submittedForReviewAt: worker.submittedForReviewAt,
      updatedAt: worker.updatedAt,
    };
  }

  async listClients(query: ListClientsQueryDto) {
    const result = await this.clients.list(query);
    return {
      items: result.items.map((item) => ({
        id: item.id,
        firstName: item.firstName,
        lastName: item.lastName,
        phoneVerified: item.phoneVerified,
        accountStatus: item.accountStatus,
        bookingsCount: item.bookingsCount,
        createdAt: item.createdAt,
        lastActivityAt: item.lastActivityAt,
      })),
      meta: result.meta,
    };
  }

  async getClient(id: string) {
    const client = await this.clients.getDetail(id);
    return {
      id: client.id,
      firstName: client.firstName,
      lastName: client.lastName,
      phoneVerified: client.phoneVerified,
      accountStatus: client.accountStatus,
      isActive: client.isActive,
      createdAt: client.createdAt,
      updatedAt: client.updatedAt,
      bookingSummary: client.bookingSummary,
      recentBookings: client.recentBookings.map((booking) => ({
        id: booking.id,
        categoryName: booking.categoryName,
        status: booking.status,
        createdAt: booking.createdAt,
      })),
    };
  }

  async listBookings(query: ListAdminBookingsQueryDto) {
    const result = await this.operations.listBookings(query);
    return {
      items: result.items.map((item) => this.booking(item)),
      total: result.total,
      page: result.page,
      pageSize: result.pageSize,
    };
  }

  async getBooking(id: string) {
    return this.booking(await this.operations.getBooking(id));
  }

  async listSettlementCases(query: ListSettlementCasesQueryDto) {
    const result = await this.operations.listCases(query);
    return {
      items: result.items.map((item) => this.settlementCase(item)),
      total: result.total,
      page: result.page,
      pageSize: result.pageSize,
    };
  }

  async getSettlementCase(id: string) {
    return this.settlementCase(await this.operations.getCase(id));
  }

  async listCollections(query: ListCollectionsQueryDto) {
    const result = await this.operations.listCollections(query);
    return {
      items: result.items.map((item) => this.collection(item)),
      total: result.total,
      page: result.page,
      pageSize: result.pageSize,
    };
  }

  async listComplaints(query: ListComplaintsQueryDto) {
    const result = await this.complaints.list(query);
    return {
      items: result.items.map((item) => this.complaint(item)),
      total: result.total,
      page: result.page,
      pageSize: result.pageSize,
    };
  }

  async getComplaint(id: string) {
    return this.complaint(await this.complaints.get(id));
  }

  private workerSummary(worker: WorkerSummarySource) {
    const primarySkill =
      'primarySkill' in worker
        ? worker.primarySkill
        : (worker.skills[0]?.category.name ?? null);
    return {
      id: worker.id,
      firstName: worker.firstName,
      lastName: worker.lastName,
      primarySkill,
      status: worker.status,
      onboardingStatus: worker.onboardingStatus,
      verificationStatus: worker.verificationStatus,
      createdAt: worker.createdAt,
    };
  }

  private booking(booking: NonNullable<AdminBooking>) {
    return {
      id: booking.id,
      clientProfileId: booking.clientProfileId,
      workerProfileId: booking.workerProfileId,
      category: booking.category
        ? { id: booking.category.id, name: booking.category.name }
        : null,
      status: booking.status,
      lane: booking.lane,
      urgency: booking.urgency,
      title: booking.title,
      scheduledAt: booking.scheduledAt,
      acceptedAt: booking.acceptedAt,
      startedAt: booking.startedAt,
      completedAt: booking.completedAt,
      cancelledAt: booking.cancelledAt,
      estimatedPrice: booking.estimatedPrice,
      finalPrice: booking.finalPrice,
      platformFee: booking.platformFee,
      paymentStatus: booking.paymentStatus,
      commissionStatus: booking.commissionStatus,
      createdAt: booking.createdAt,
      updatedAt: booking.updatedAt,
      inspectionReport: booking.inspectionReport
        ? {
            labourCost: booking.inspectionReport.labourCost,
            partsTotal: booking.inspectionReport.partsTotal,
            decisionStatus: booking.inspectionReport.decisionStatus,
          }
        : null,
      settlements: Array.isArray(booking.settlements)
        ? booking.settlements.map((item) => this.settlement(item))
        : [],
    };
  }

  private settlement(settlement: BookingSettlement) {
    return {
      id: settlement.id,
      bookingId: settlement.bookingId,
      workerProfileId: settlement.workerProfileId,
      supersedesId: settlement.supersedesId,
      isCurrent: settlement.isCurrent,
      expectedParts: settlement.expectedParts,
      expectedLabour: settlement.expectedLabour,
      expectedFee: settlement.expectedFee,
      expectedTotal: settlement.expectedTotal,
      received: settlement.received,
      source: settlement.source,
      partsPaid: settlement.partsPaid,
      labourPaid: settlement.labourPaid,
      feePaid: settlement.feePaid,
      commission: settlement.commission,
      munafa: settlement.munafa,
      shortfall: settlement.shortfall,
      handygoPays: settlement.handygoPays,
      settledAt: settlement.settledAt,
    };
  }

  private settlementCase(item: NonNullable<AdminSettlementCase>) {
    return {
      id: item.id,
      bookingId: item.bookingId,
      workerProfileId: item.workerProfileId,
      settlementId: item.settlementId,
      type: item.type,
      status: item.status,
      priority: item.priority,
      resolvedAt: item.resolvedAt,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
      booking: item.booking
        ? {
            id: item.booking.id,
            title: item.booking.title,
            status: item.booking.status,
            lane: item.booking.lane,
          }
        : null,
      settlement: item.settlement ? this.settlement(item.settlement) : null,
      events: Array.isArray(item.events)
        ? item.events.map((event) => ({
            id: event.id,
            type: event.type,
            createdAt: event.createdAt,
          }))
        : [],
    };
  }

  private collection(item: AdminCollection) {
    return {
      id: item.id,
      workerProfileId: item.workerProfileId,
      collectionDate: item.collectionDate,
      amount: item.amount,
      status: item.status,
      automated: item.automated,
      collectedAt: item.collectedAt,
      createdAt: item.createdAt,
      items: Array.isArray(item.items)
        ? item.items.map((collectionItem) => ({
            id: collectionItem.id,
            settlementId: collectionItem.settlementId,
            amount: collectionItem.amount,
            createdAt: collectionItem.createdAt,
          }))
        : [],
    };
  }

  private complaint(item: NonNullable<AdminComplaint>) {
    return {
      id: item.id,
      bookingId: item.bookingId,
      reportedWorkerProfileId: item.reportedWorkerProfileId,
      issueTypes: item.issueTypes,
      source: item.source,
      status: item.status,
      priority: item.priority,
      humanRequested: item.humanRequested,
      humanRequestedAt: item.humanRequestedAt,
      resolvedAt: item.resolvedAt,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
      booking: item.booking
        ? {
            id: item.booking.id,
            title: item.booking.title,
            status: item.booking.status,
            clientProfileId: item.booking.clientProfileId,
            workerProfileId: item.booking.workerProfileId,
          }
        : null,
      events: Array.isArray(item.events)
        ? item.events.map((event) => ({
            id: event.id,
            type: event.type,
            createdAt: event.createdAt,
          }))
        : [],
    };
  }
}
