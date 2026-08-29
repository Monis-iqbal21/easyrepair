import { Injectable } from '@nestjs/common';
import {
  ComplaintEvent,
  ComplaintEventType,
  ComplaintIssueType,
  ComplaintPriority,
  ComplaintSource,
  ComplaintStatus,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { ListComplaintsQueryDto } from './dto/support-complaint.dto';

const complaintDetailInclude = {
  booking: {
    select: {
      id: true,
      title: true,
      status: true,
      clientProfileId: true,
      workerProfileId: true,
    },
  },
  reporter: { select: { id: true, phone: true, role: true } },
  reportedWorker: {
    include: {
      user: { select: { id: true, phone: true } },
    },
  },
  assignedTo: { select: { id: true, phone: true, role: true } },
  events: {
    orderBy: { createdAt: 'asc' as const },
    include: {
      actor: { select: { id: true, phone: true, role: true } },
      notification: { select: { id: true } },
    },
  },
} satisfies Prisma.ComplaintInclude;

export class ComplaintWriteConflictError extends Error {}

export interface ComplaintMutation {
  status?: ComplaintStatus;
  priority?: ComplaintPriority;
  assignedToUserId?: string | null;
}

@Injectable()
export class ComplaintsRepository {
  constructor(private readonly prisma: PrismaService) {}

  findBookingForComplaint(bookingId: string) {
    return this.prisma.booking.findUnique({
      where: { id: bookingId },
      select: {
        id: true,
        title: true,
        status: true,
        workerProfileId: true,
        clientProfile: { select: { userId: true } },
      },
    });
  }

  findByBookingId(bookingId: string) {
    return this.prisma.complaint.findUnique({ where: { bookingId } });
  }

  findById(id: string) {
    return this.prisma.complaint.findUnique({ where: { id } });
  }

  findDetail(id: string) {
    return this.prisma.complaint.findUnique({
      where: { id },
      include: complaintDetailInclude,
    });
  }

  findActiveUser(id: string) {
    return this.prisma.user.findFirst({
      where: { id, isActive: true, deletedAt: null },
      select: { id: true },
    });
  }

  createBookingComplaint(data: {
    bookingId: string;
    reporterUserId: string;
    reportedWorkerProfileId: string | null;
    issueTypes: ComplaintIssueType[];
    otherText: string | null;
  }) {
    return this.prisma.complaint.create({
      data: {
        ...data,
        source: ComplaintSource.APP_CUSTOMER,
        status: ComplaintStatus.OPEN,
        priority: ComplaintPriority.NORMAL,
        humanRequested: false,
        events: {
          create: {
            type: ComplaintEventType.CREATED,
            actorUserId: data.reporterUserId,
            metadata: { source: ComplaintSource.APP_CUSTOMER },
          },
        },
      },
      include: {
        events: {
          where: { type: ComplaintEventType.CREATED },
          orderBy: { createdAt: 'asc' },
          take: 1,
        },
      },
    });
  }

  async list(query: ListComplaintsQueryDto) {
    const term = query.search?.trim();
    const where: Prisma.ComplaintWhereInput = {
      ...(query.status ? { status: query.status } : {}),
      ...(query.priority ? { priority: query.priority } : {}),
      ...(query.source ? { source: query.source } : {}),
      ...(query.assignedToUserId
        ? { assignedToUserId: query.assignedToUserId }
        : {}),
      ...(query.humanRequested !== undefined
        ? { humanRequested: query.humanRequested }
        : {}),
      ...(term
        ? {
            OR: [
              { id: { contains: term, mode: 'insensitive' } },
              { bookingId: { contains: term, mode: 'insensitive' } },
              { reporter: { phone: { contains: term } } },
            ],
          }
        : {}),
    };

    const [items, total] = await Promise.all([
      this.prisma.complaint.findMany({
        where,
        include: complaintDetailInclude,
        orderBy: { createdAt: 'desc' },
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
      }),
      this.prisma.complaint.count({ where }),
    ]);
    return { items, total };
  }

  async mutate(
    id: string,
    mutation: ComplaintMutation,
    actorUserId: string | null,
  ) {
    return this.prisma.$transaction(async (tx) => {
      const before = await tx.complaint.findUniqueOrThrow({ where: { id } });
      const statusChanged =
        mutation.status !== undefined && mutation.status !== before.status;
      const priorityChanged =
        mutation.priority !== undefined &&
        mutation.priority !== before.priority;
      const assignmentChanged =
        mutation.assignedToUserId !== undefined &&
        mutation.assignedToUserId !== before.assignedToUserId;

      if (!statusChanged && !priorityChanged && !assignmentChanged) {
        return {
          complaint: await tx.complaint.findUniqueOrThrow({
            where: { id },
            include: complaintDetailInclude,
          }),
          statusEvent: null,
        };
      }

      const changedAt = new Date();
      const resolvedTarget =
        mutation.status === ComplaintStatus.RESOLVED ||
        mutation.status === ComplaintStatus.CLOSED;
      const resolvedBefore =
        before.status === ComplaintStatus.RESOLVED ||
        before.status === ComplaintStatus.CLOSED;
      const { count } = await tx.complaint.updateMany({
        where: { id, updatedAt: before.updatedAt },
        data: {
          ...(statusChanged
            ? {
                status: mutation.status,
                resolvedAt: resolvedTarget
                  ? (before.resolvedAt ?? changedAt)
                  : null,
              }
            : {}),
          ...(priorityChanged ? { priority: mutation.priority } : {}),
          ...(assignmentChanged
            ? { assignedToUserId: mutation.assignedToUserId }
            : {}),
          updatedAt: changedAt,
        },
      });
      if (count !== 1) {
        throw new ComplaintWriteConflictError(
          'Complaint changed during update',
        );
      }

      let statusEvent: ComplaintEvent | null = null;
      if (statusChanged) {
        const type =
          resolvedTarget && !resolvedBefore
            ? ComplaintEventType.RESOLVED
            : resolvedBefore && !resolvedTarget
              ? ComplaintEventType.REOPENED
              : ComplaintEventType.STATUS_CHANGED;
        statusEvent = await tx.complaintEvent.create({
          data: {
            complaintId: id,
            actorUserId,
            type,
            metadata: { from: before.status, to: mutation.status },
          },
        });
      }
      if (priorityChanged) {
        await tx.complaintEvent.create({
          data: {
            complaintId: id,
            actorUserId,
            type: ComplaintEventType.PRIORITY_CHANGED,
            metadata: { from: before.priority, to: mutation.priority },
          },
        });
      }
      if (assignmentChanged) {
        await tx.complaintEvent.create({
          data: {
            complaintId: id,
            actorUserId,
            type: ComplaintEventType.ASSIGNED,
            metadata: {
              from: before.assignedToUserId,
              to: mutation.assignedToUserId,
            },
          },
        });
      }

      return {
        complaint: await tx.complaint.findUniqueOrThrow({
          where: { id },
          include: complaintDetailInclude,
        }),
        statusEvent,
      };
    });
  }

  async markHumanRequested(id: string, actorUserId: string | null) {
    return this.prisma.$transaction(async (tx) => {
      const before = await tx.complaint.findUniqueOrThrow({ where: { id } });
      if (before.humanRequested) {
        return tx.complaint.findUniqueOrThrow({
          where: { id },
          include: complaintDetailInclude,
        });
      }

      const requestedAt = new Date();
      const { count } = await tx.complaint.updateMany({
        where: { id, humanRequested: false },
        data: {
          humanRequested: true,
          humanRequestedAt: requestedAt,
          updatedAt: requestedAt,
        },
      });
      if (count === 1) {
        await tx.complaintEvent.create({
          data: {
            complaintId: id,
            actorUserId,
            type: ComplaintEventType.HUMAN_REQUESTED,
          },
        });
      }
      return tx.complaint.findUniqueOrThrow({
        where: { id },
        include: complaintDetailInclude,
      });
    });
  }
}
