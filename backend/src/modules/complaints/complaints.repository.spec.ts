import {
  ComplaintEventType,
  ComplaintIssueType,
  ComplaintPriority,
  ComplaintSource,
  ComplaintStatus,
} from '@prisma/client';
import { ComplaintsRepository } from './complaints.repository';

describe('ComplaintsRepository audit and invariants', () => {
  it('forces APP_CUSTOMER and creates OPEN/NORMAL/non-human plus CREATED event', async () => {
    const prisma: any = {
      complaint: { create: jest.fn().mockResolvedValue({ id: 'complaint-1' }) },
    };
    const repository = new ComplaintsRepository(prisma);

    await repository.createBookingComplaint({
      bookingId: 'booking-1',
      reporterUserId: 'client-1',
      reportedWorkerProfileId: 'worker-1',
      issueTypes: [ComplaintIssueType.WORK_QUALITY],
      otherText: null,
    });

    expect(prisma.complaint.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          source: ComplaintSource.APP_CUSTOMER,
          status: ComplaintStatus.OPEN,
          priority: ComplaintPriority.NORMAL,
          humanRequested: false,
          events: {
            create: expect.objectContaining({
              type: ComplaintEventType.CREATED,
              actorUserId: 'client-1',
            }),
          },
        }),
      }),
    );
    expect(prisma.booking).toBeUndefined();
  });

  it('changes status and appends a lifecycle event without changing Booking', async () => {
    const before = {
      id: 'complaint-1',
      status: ComplaintStatus.OPEN,
      priority: ComplaintPriority.NORMAL,
      assignedToUserId: null,
      resolvedAt: null,
      updatedAt: new Date('2026-08-26T00:00:00.000Z'),
    };
    const updated = { ...before, status: ComplaintStatus.IN_PROGRESS };
    const tx: any = {
      complaint: {
        findUniqueOrThrow: jest
          .fn()
          .mockResolvedValueOnce(before)
          .mockResolvedValueOnce(updated),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      complaintEvent: {
        create: jest.fn().mockResolvedValue({ id: 'event-status' }),
      },
    };
    const repository = new ComplaintsRepository({
      $transaction: (work: any) => work(tx),
    } as any);

    const result = await repository.mutate(
      'complaint-1',
      { status: ComplaintStatus.IN_PROGRESS },
      'support-1',
    );

    expect(tx.complaintEvent.create).toHaveBeenCalledWith({
      data: {
        complaintId: 'complaint-1',
        actorUserId: 'support-1',
        type: ComplaintEventType.STATUS_CHANGED,
        metadata: {
          from: ComplaintStatus.OPEN,
          to: ComplaintStatus.IN_PROGRESS,
        },
      },
    });
    expect(result.statusEvent).toEqual({ id: 'event-status' });
    expect(tx.booking).toBeUndefined();
  });

  it('marks human requested once, appends HUMAN_REQUESTED, and never changes priority', async () => {
    const finalComplaint = {
      id: 'complaint-1',
      humanRequested: true,
      priority: ComplaintPriority.NORMAL,
    };
    const tx: any = {
      complaint: {
        findUniqueOrThrow: jest
          .fn()
          .mockResolvedValueOnce({
            id: 'complaint-1',
            humanRequested: false,
          })
          .mockResolvedValueOnce(finalComplaint),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      complaintEvent: {
        create: jest.fn().mockResolvedValue({ id: 'event-1' }),
      },
    };
    const repository = new ComplaintsRepository({
      $transaction: (work: any) => work(tx),
    } as any);

    await expect(
      repository.markHumanRequested('complaint-1', 'client-1'),
    ).resolves.toBe(finalComplaint);

    const updateData = tx.complaint.updateMany.mock.calls[0][0].data;
    expect(updateData).toMatchObject({
      humanRequested: true,
      humanRequestedAt: expect.any(Date),
    });
    expect(updateData).not.toHaveProperty('priority');
    expect(tx.complaintEvent.create).toHaveBeenCalledWith({
      data: {
        complaintId: 'complaint-1',
        actorUserId: 'client-1',
        type: ComplaintEventType.HUMAN_REQUESTED,
      },
    });
  });

  it('does not append a second HUMAN_REQUESTED event on an idempotent retry', async () => {
    const complaint = { id: 'complaint-1', humanRequested: true };
    const tx: any = {
      complaint: {
        findUniqueOrThrow: jest.fn().mockResolvedValue(complaint),
        updateMany: jest.fn(),
      },
      complaintEvent: { create: jest.fn() },
    };
    const repository = new ComplaintsRepository({
      $transaction: (work: any) => work(tx),
    } as any);

    await repository.markHumanRequested('complaint-1', 'client-1');

    expect(tx.complaint.updateMany).not.toHaveBeenCalled();
    expect(tx.complaintEvent.create).not.toHaveBeenCalled();
  });
});
