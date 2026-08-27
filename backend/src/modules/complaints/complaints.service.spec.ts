import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
} from '@nestjs/common';
import {
  BookingStatus,
  ComplaintIssueType,
  ComplaintPriority,
  ComplaintSource,
  ComplaintStatus,
} from '@prisma/client';
import { ComplaintsService } from './complaints.service';

describe('ComplaintsService booking reports', () => {
  const booking = {
    id: 'booking-1',
    status: BookingStatus.COMPLETED,
    workerProfileId: 'worker-profile-1',
    clientProfile: { userId: 'client-1' },
  };
  const created = {
    id: 'complaint-1',
    bookingId: 'booking-1',
    reporterUserId: 'client-1',
    reportedWorkerProfileId: 'worker-profile-1',
    issueTypes: [ComplaintIssueType.WORK_QUALITY],
    otherText: null,
    source: ComplaintSource.APP_CUSTOMER,
    status: ComplaintStatus.OPEN,
    priority: ComplaintPriority.NORMAL,
    assignedToUserId: null,
    humanRequested: false,
    humanRequestedAt: null,
    resolvedAt: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    events: [{ id: 'event-created', type: 'CREATED' }],
  };

  let repository: any;
  let notifications: any;
  let service: ComplaintsService;

  beforeEach(() => {
    repository = {
      findBookingForComplaint: jest.fn().mockResolvedValue(booking),
      findByBookingId: jest.fn().mockResolvedValue(null),
      createBookingComplaint: jest.fn().mockResolvedValue(created),
      findById: jest.fn(),
      findDetail: jest.fn(),
      list: jest.fn(),
      mutate: jest.fn(),
      findActiveUser: jest.fn(),
      markHumanRequested: jest.fn(),
    };
    notifications = { notify: jest.fn().mockResolvedValue(undefined) };
    service = new ComplaintsService(repository, notifications);
  });

  it('creates a complaint for an owned completed booking with server defaults', async () => {
    const result = await service.createForBooking('client-1', 'booking-1', {
      issueTypes: [ComplaintIssueType.WORK_QUALITY],
    });

    expect(repository.createBookingComplaint).toHaveBeenCalledWith({
      bookingId: 'booking-1',
      reporterUserId: 'client-1',
      reportedWorkerProfileId: 'worker-profile-1',
      issueTypes: [ComplaintIssueType.WORK_QUALITY],
      otherText: null,
    });
    expect(result).toMatchObject({
      source: ComplaintSource.APP_CUSTOMER,
      status: ComplaintStatus.OPEN,
      priority: ComplaintPriority.NORMAL,
      humanRequested: false,
    });
    expect(result).not.toHaveProperty('events');
    expect(notifications.notify).toHaveBeenCalledWith(
      expect.objectContaining({
        eventKey: 'complaint.created',
        complaintEventId: 'event-created',
        bookingId: 'booking-1',
        entityId: 'complaint-1',
        route: '/client/booking/booking-1',
      }),
    );
    expect(booking.status).toBe(BookingStatus.COMPLETED);
  });

  it('rejects a non-completed booking', async () => {
    repository.findBookingForComplaint.mockResolvedValue({
      ...booking,
      status: BookingStatus.IN_PROGRESS,
    });
    await expect(
      service.createForBooking('client-1', 'booking-1', {
        issueTypes: [ComplaintIssueType.DAMAGE],
      }),
    ).rejects.toThrow(BadRequestException);
    expect(repository.createBookingComplaint).not.toHaveBeenCalled();
  });

  it("rejects someone else's booking", async () => {
    repository.findBookingForComplaint.mockResolvedValue({
      ...booking,
      clientProfile: { userId: 'someone-else' },
    });
    await expect(
      service.createForBooking('client-1', 'booking-1', {
        issueTypes: [ComplaintIssueType.DAMAGE],
      }),
    ).rejects.toThrow(ForbiddenException);
  });

  it('rejects an empty issue type list', async () => {
    await expect(
      service.createForBooking('client-1', 'booking-1', { issueTypes: [] }),
    ).rejects.toThrow('At least one issue type is required');
  });

  it('rejects OTHER without non-empty otherText', async () => {
    await expect(
      service.createForBooking('client-1', 'booking-1', {
        issueTypes: [ComplaintIssueType.OTHER],
        otherText: '   ',
      }),
    ).rejects.toThrow('otherText is required when OTHER is selected');
  });

  it('accepts OTHER with trimmed text', async () => {
    await service.createForBooking('client-1', 'booking-1', {
      issueTypes: [ComplaintIssueType.OTHER],
      otherText: '  Extra issue  ',
    });
    expect(repository.createBookingComplaint).toHaveBeenCalledWith(
      expect.objectContaining({ otherText: 'Extra issue' }),
    );
  });

  it('accepts multiple distinct issue types', async () => {
    const issueTypes = [
      ComplaintIssueType.WORK_QUALITY,
      ComplaintIssueType.PRICE_PAYMENT,
      ComplaintIssueType.WARRANTY_REWORK,
    ];
    await service.createForBooking('client-1', 'booking-1', { issueTypes });
    expect(repository.createBookingComplaint).toHaveBeenCalledWith(
      expect.objectContaining({ issueTypes }),
    );
  });

  it('rejects a known duplicate before trying to insert', async () => {
    repository.findByBookingId.mockResolvedValue(created);
    await expect(
      service.createForBooking('client-1', 'booking-1', {
        issueTypes: [ComplaintIssueType.DAMAGE],
      }),
    ).rejects.toThrow(ConflictException);
    expect(repository.createBookingComplaint).not.toHaveBeenCalled();
  });

  it('handles concurrent duplicate submissions with one row and one notification', async () => {
    let inserted: typeof created | null = null;
    repository.findByBookingId.mockResolvedValue(null);
    repository.createBookingComplaint.mockImplementation(async () => {
      await new Promise((resolve) => setImmediate(resolve));
      if (inserted) throw { code: 'P2002', meta: { target: ['bookingId'] } };
      inserted = created;
      return created;
    });

    const attempts = await Promise.allSettled([
      service.createForBooking('client-1', 'booking-1', {
        issueTypes: [ComplaintIssueType.DAMAGE],
      }),
      service.createForBooking('client-1', 'booking-1', {
        issueTypes: [ComplaintIssueType.DAMAGE],
      }),
    ]);

    expect(
      attempts.filter((result) => result.status === 'fulfilled'),
    ).toHaveLength(1);
    const rejected = attempts.find((result) => result.status === 'rejected');
    expect((rejected as PromiseRejectedResult).reason).toBeInstanceOf(
      ConflictException,
    );
    expect(inserted).not.toBeNull();
    expect(repository.createBookingComplaint).toHaveBeenCalledTimes(2);
    expect(notifications.notify).toHaveBeenCalledTimes(1);
  });

  it('returns an existing complaint and returns null cleanly when absent', async () => {
    repository.findByBookingId
      .mockResolvedValueOnce(created)
      .mockResolvedValueOnce(null);
    await expect(service.getForBooking('client-1', 'booking-1')).resolves.toBe(
      created,
    );
    await expect(
      service.getForBooking('client-1', 'booking-1'),
    ).resolves.toBeNull();
  });
});

describe('ComplaintsService support lifecycle', () => {
  it('notifies the Client for IN_PROGRESS using the status event id', async () => {
    const complaint = {
      id: 'complaint-1',
      bookingId: 'booking-1',
      reporterUserId: 'client-1',
      status: ComplaintStatus.IN_PROGRESS,
    };
    const repository: any = {
      findById: jest.fn().mockResolvedValue({
        ...complaint,
        status: ComplaintStatus.OPEN,
      }),
      mutate: jest.fn().mockResolvedValue({
        complaint,
        statusEvent: { id: 'event-status' },
      }),
      findDetail: jest.fn().mockResolvedValue(complaint),
    };
    const notifications: any = {
      notify: jest.fn().mockResolvedValue(undefined),
    };
    const service = new ComplaintsService(repository, notifications);

    await service.changeStatus(
      'complaint-1',
      ComplaintStatus.IN_PROGRESS,
      'support-1',
    );

    expect(repository.mutate).toHaveBeenCalledWith(
      'complaint-1',
      { status: ComplaintStatus.IN_PROGRESS },
      'support-1',
    );
    expect(notifications.notify).toHaveBeenCalledWith(
      expect.objectContaining({
        eventKey: 'complaint.status.in_progress',
        complaintEventId: 'event-status',
        title: 'Your report is under review',
        body: 'Aap ka report review mein hai',
      }),
    );
  });

  it('notifies on RESOLVED but does not duplicate resolved copy for CLOSED', async () => {
    const notifications: any = {
      notify: jest.fn().mockResolvedValue(undefined),
    };
    const repository: any = {
      findById: jest
        .fn()
        .mockResolvedValueOnce({ status: ComplaintStatus.IN_PROGRESS })
        .mockResolvedValueOnce({ status: ComplaintStatus.RESOLVED }),
      mutate: jest
        .fn()
        .mockResolvedValueOnce({
          complaint: {
            id: 'complaint-1',
            bookingId: 'booking-1',
            reporterUserId: 'client-1',
            status: ComplaintStatus.RESOLVED,
          },
          statusEvent: { id: 'event-resolved' },
        })
        .mockResolvedValueOnce({
          complaint: {
            id: 'complaint-1',
            bookingId: 'booking-1',
            reporterUserId: 'client-1',
            status: ComplaintStatus.CLOSED,
          },
          statusEvent: { id: 'event-closed' },
        }),
      findDetail: jest.fn().mockResolvedValue({ id: 'complaint-1' }),
    };
    const service = new ComplaintsService(repository, notifications);

    await service.changeStatus(
      'complaint-1',
      ComplaintStatus.RESOLVED,
      'support-1',
    );
    await service.changeStatus(
      'complaint-1',
      ComplaintStatus.CLOSED,
      'support-1',
    );

    expect(notifications.notify).toHaveBeenCalledTimes(1);
    expect(notifications.notify).toHaveBeenCalledWith(
      expect.objectContaining({
        eventKey: 'complaint.status.resolved',
        complaintEventId: 'event-resolved',
      }),
    );
  });
});
