import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  BookingStatus,
  ComplaintIssueType,
  ComplaintPriority,
  ComplaintStatus,
  Prisma,
} from '@prisma/client';
import { NotificationsService } from '../notifications/notifications.service';
import {
  ComplaintWriteConflictError,
  ComplaintsRepository,
} from './complaints.repository';
import { CreateBookingComplaintDto } from './dto/create-booking-complaint.dto';
import { ListComplaintsQueryDto } from './dto/support-complaint.dto';

const STATUS_TRANSITIONS: Record<
  ComplaintStatus,
  ReadonlySet<ComplaintStatus>
> = {
  [ComplaintStatus.OPEN]: new Set([
    ComplaintStatus.IN_PROGRESS,
    ComplaintStatus.WAITING_ON_CUSTOMER,
    ComplaintStatus.RESOLVED,
    ComplaintStatus.CLOSED,
  ]),
  [ComplaintStatus.IN_PROGRESS]: new Set([
    ComplaintStatus.WAITING_ON_CUSTOMER,
    ComplaintStatus.RESOLVED,
    ComplaintStatus.CLOSED,
  ]),
  [ComplaintStatus.WAITING_ON_CUSTOMER]: new Set([
    ComplaintStatus.IN_PROGRESS,
    ComplaintStatus.RESOLVED,
    ComplaintStatus.CLOSED,
  ]),
  [ComplaintStatus.RESOLVED]: new Set([
    ComplaintStatus.OPEN,
    ComplaintStatus.IN_PROGRESS,
    ComplaintStatus.CLOSED,
  ]),
  [ComplaintStatus.CLOSED]: new Set([
    ComplaintStatus.OPEN,
    ComplaintStatus.IN_PROGRESS,
  ]),
};

export const COMPLAINT_NOTIFICATION_COPY = {
  CREATED: {
    eventKey: 'complaint.created',
    en: 'Report submitted',
    urLatn: 'Report submit ho gaya',
  },
  IN_PROGRESS: {
    eventKey: 'complaint.status.in_progress',
    en: 'Your report is under review',
    urLatn: 'Aap ka report review mein hai',
  },
  RESOLVED: {
    eventKey: 'complaint.status.resolved',
    en: 'Your report has been resolved',
    urLatn: 'Aap ka report resolve ho gaya',
  },
} as const;

@Injectable()
export class ComplaintsService {
  constructor(
    private readonly repository: ComplaintsRepository,
    private readonly notifications: NotificationsService,
  ) {}

  async createForBooking(
    reporterUserId: string,
    bookingId: string,
    dto: CreateBookingComplaintDto,
  ) {
    const booking = await this.requireOwnedBooking(reporterUserId, bookingId);
    if (booking.status !== BookingStatus.COMPLETED) {
      throw new BadRequestException(
        'Complaints can only be submitted for completed bookings',
      );
    }

    this.validateIssueTypes(dto);
    if (await this.repository.findByBookingId(bookingId)) {
      throw new ConflictException(
        'A complaint already exists for this booking',
      );
    }

    try {
      const created = await this.repository.createBookingComplaint({
        bookingId,
        reporterUserId,
        reportedWorkerProfileId: booking.workerProfileId,
        issueTypes: dto.issueTypes,
        otherText: dto.otherText?.trim() || null,
      });
      const createdEvent = created.events[0];
      if (!createdEvent) {
        throw new Error('Complaint creation did not produce an audit event');
      }
      await this.sendNotification(
        created,
        createdEvent.id,
        COMPLAINT_NOTIFICATION_COPY.CREATED,
        reporterUserId,
        'CLIENT',
      );
      const { events: _events, ...complaint } = created;
      return complaint;
    } catch (error) {
      if (this.isUniqueConflict(error)) {
        throw new ConflictException(
          'A complaint already exists for this booking',
        );
      }
      throw error;
    }
  }

  async getForBooking(reporterUserId: string, bookingId: string) {
    await this.requireOwnedBooking(reporterUserId, bookingId);
    return this.repository.findByBookingId(bookingId);
  }

  async requestHumanForReporter(reporterUserId: string, complaintId: string) {
    const complaint = await this.repository.findById(complaintId);
    if (!complaint) throw new NotFoundException('Complaint not found');
    if (complaint.reporterUserId !== reporterUserId) {
      throw new ForbiddenException('Not your complaint');
    }
    return this.repository.markHumanRequested(complaintId, reporterUserId);
  }

  /** Role-neutral entrypoint for future bot channels using an existing row. */
  async requestHuman(complaintId: string, actorUserId: string | null) {
    await this.get(complaintId);
    return this.repository.markHumanRequested(complaintId, actorUserId);
  }

  async list(query: ListComplaintsQueryDto) {
    const result = await this.repository.list(query);
    return { ...result, page: query.page, pageSize: query.pageSize };
  }

  async get(id: string) {
    const complaint = await this.repository.findDetail(id);
    if (!complaint) throw new NotFoundException('Complaint not found');
    return complaint;
  }

  async changeStatus(id: string, status: ComplaintStatus, actorUserId: string) {
    const before = await this.repository.findById(id);
    if (!before) throw new NotFoundException('Complaint not found');
    if (
      status !== before.status &&
      !STATUS_TRANSITIONS[before.status].has(status)
    ) {
      throw new BadRequestException(
        `Invalid complaint status transition: ${before.status} -> ${status}`,
      );
    }

    try {
      const result = await this.repository.mutate(id, { status }, actorUserId);
      if (result.statusEvent) {
        const copy =
          status === ComplaintStatus.IN_PROGRESS
            ? COMPLAINT_NOTIFICATION_COPY.IN_PROGRESS
            : status === ComplaintStatus.RESOLVED
              ? COMPLAINT_NOTIFICATION_COPY.RESOLVED
              : null;
        if (copy && result.complaint.reporterUserId) {
          await this.sendNotification(
            result.complaint,
            result.statusEvent.id,
            copy,
            actorUserId,
          );
          return this.get(id);
        }
      }
      return result.complaint;
    } catch (error) {
      this.rethrowWriteConflict(error);
    }
  }

  async changePriority(
    id: string,
    priority: ComplaintPriority,
    actorUserId: string,
  ) {
    await this.get(id);
    try {
      const result = await this.repository.mutate(
        id,
        { priority },
        actorUserId,
      );
      return result.complaint;
    } catch (error) {
      this.rethrowWriteConflict(error);
    }
  }

  async assign(
    id: string,
    assignedToUserId: string | null | undefined,
    actorUserId: string,
  ) {
    await this.get(id);
    if (assignedToUserId === undefined) {
      throw new BadRequestException('assignedToUserId is required');
    }
    if (
      assignedToUserId !== null &&
      !(await this.repository.findActiveUser(assignedToUserId))
    ) {
      throw new BadRequestException('Assignee user not found or inactive');
    }
    try {
      const result = await this.repository.mutate(
        id,
        { assignedToUserId },
        actorUserId,
      );
      return result.complaint;
    } catch (error) {
      this.rethrowWriteConflict(error);
    }
  }

  private async requireOwnedBooking(reporterUserId: string, bookingId: string) {
    const booking = await this.repository.findBookingForComplaint(bookingId);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.clientProfile.userId !== reporterUserId) {
      throw new ForbiddenException('Not your booking');
    }
    return booking;
  }

  private validateIssueTypes(dto: CreateBookingComplaintDto): void {
    if (!Array.isArray(dto.issueTypes) || dto.issueTypes.length === 0) {
      throw new BadRequestException('At least one issue type is required');
    }
    if (new Set(dto.issueTypes).size !== dto.issueTypes.length) {
      throw new BadRequestException('Issue types must be unique');
    }
    if (
      dto.issueTypes.includes(ComplaintIssueType.OTHER) &&
      !dto.otherText?.trim()
    ) {
      throw new BadRequestException(
        'otherText is required when OTHER is selected',
      );
    }
  }

  private isUniqueConflict(error: unknown): boolean {
    return (
      (error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002') ||
      (error as { code?: string } | null)?.code === 'P2002'
    );
  }

  private rethrowWriteConflict(error: unknown): never {
    if (error instanceof ComplaintWriteConflictError) {
      throw new ConflictException(
        'Complaint changed; reload before trying again',
      );
    }
    throw error;
  }

  private sendNotification(
    complaint: {
      id: string;
      bookingId: string | null;
      reporterUserId: string | null;
      status: ComplaintStatus;
    },
    complaintEventId: string,
    copy: { eventKey: string; en: string; urLatn: string },
    actorUserId?: string,
    actorRole?: string,
  ): Promise<void> {
    if (!complaint.reporterUserId) return Promise.resolve();
    return this.notifications.notify({
      userId: complaint.reporterUserId,
      eventKey: copy.eventKey,
      title: copy.en,
      body: copy.urLatn,
      complaintEventId,
      bookingId: complaint.bookingId ?? undefined,
      route: complaint.bookingId
        ? `/client/booking/${complaint.bookingId}`
        : undefined,
      actorUserId,
      actorRole,
      entityType: 'complaint',
      entityId: complaint.id,
      payload: {
        complaintId: complaint.id,
        bookingId: complaint.bookingId,
        status: complaint.status,
        copy: { en: copy.en, urLatn: copy.urLatn },
      },
    });
  }
}
