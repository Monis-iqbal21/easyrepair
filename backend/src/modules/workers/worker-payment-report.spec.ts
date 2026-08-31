import 'reflect-metadata';
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  RequestMethod,
} from '@nestjs/common';
import {
  GUARDS_METADATA,
  METHOD_METADATA,
  PATH_METADATA,
} from '@nestjs/common/constants';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { Reflector } from '@nestjs/core';
import {
  BookingLane,
  BookingStatus,
  InspectionDecisionStatus,
  SettlementSource,
} from '@prisma/client';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AdminOperationsService } from '../admin/admin-operations.service';
import { NOTIFICATION_KEYS } from '../notifications/notification-templates';
import { WorkersController } from './workers.controller';
import { ReportReceivedPaymentDto } from './dto/report-received-payment.dto';

describe('Ustaad short-payment HTTP contract', () => {
  it('exposes a WORKER-only route behind the JWT and role guards', () => {
    const handler = WorkersController.prototype.reportReceivedPayment;

    expect(Reflect.getMetadata(PATH_METADATA, handler)).toBe(
      'jobs/:bookingId/report-payment',
    );
    expect(Reflect.getMetadata(METHOD_METADATA, handler)).toBe(
      RequestMethod.POST,
    );
    expect(Reflect.getMetadata(GUARDS_METADATA, WorkersController)).toEqual([
      JwtAuthGuard,
      RolesGuard,
    ]);
    // The controller is @Roles(WORKER) at class level.
    expect(Reflect.getMetadata(ROLES_KEY, WorkersController)).toEqual([
      Role.WORKER,
    ]);
  });

  it('forbids CLIENT and ADMIN while allowing WORKER', () => {
    const guard = new RolesGuard(new Reflector());
    const contextFor = (role: Role) =>
      ({
        getHandler: () => WorkersController.prototype.reportReceivedPayment,
        getClass: () => WorkersController,
        switchToHttp: () => ({ getRequest: () => ({ user: { role } }) }),
      }) as any;

    expect(guard.canActivate(contextFor(Role.WORKER))).toBe(true);
    expect(guard.canActivate(contextFor(Role.CLIENT))).toBe(false);
    expect(guard.canActivate(contextFor(Role.ADMIN))).toBe(false);
  });

  it('accepts zero rupees and rejects negative or fractional amounts', async () => {
    const at = (receivedCashTotal: number) =>
      validate(
        plainToInstance(ReportReceivedPaymentDto, { receivedCashTotal }),
      );

    expect(await at(0)).toHaveLength(0);
    expect(await at(2500)).toHaveLength(0);
    expect(await at(-1)).not.toHaveLength(0);
    expect(await at(10.5)).not.toHaveLength(0);
  });
});

describe('AdminOperationsService.reportUstaadCashPayment', () => {
  const workerUserId = 'worker-user-1';
  const clientUserId = 'client-user-1';

  /**
   * The real production shape Phase 3 was verified against: an accepted
   * inspection repair quoting parts 1700 + labour 1000 = 2700.
   */
  const baseBooking = {
    id: 'booking-1',
    status: BookingStatus.COMPLETED,
    lane: BookingLane.INSPECTION,
    workerProfileId: 'worker-1',
    finalPrice: null,
    inspectionFeeSnapshot: null,
    inspectionReport: {
      partsTotal: 1700,
      labourCost: 1000,
      decisionStatus: InspectionDecisionStatus.ACCEPTED_REPAIR,
    },
    clientProfile: { user: { id: clientUserId } },
    workerProfile: { user: { id: workerUserId } },
    settlements: [],
  };

  let repository: any;
  let notifications: any;
  let service: AdminOperationsService;

  beforeEach(() => {
    repository = {
      findBooking: jest.fn().mockResolvedValue(baseBooking),
      createSettlement: jest.fn().mockImplementation(async (data) => ({
        ...data,
        id: 'settlement-1',
        settledAt: new Date('2026-08-31T00:00:00.000Z'),
      })),
    };
    notifications = {
      wasAlreadyNotified: jest.fn().mockResolvedValue(false),
      notify: jest.fn().mockResolvedValue(undefined),
    };
    service = new AdminOperationsService(repository, undefined, notifications);
  });

  it('records the Ustaad-declared amount under SettlementSource.USTAAD', async () => {
    await service.reportUstaadCashPayment('booking-1', 2500, workerUserId);

    expect(repository.createSettlement).toHaveBeenCalledWith(
      expect.objectContaining({
        source: SettlementSource.USTAAD,
        received: 2500,
        settledByUserId: workerUserId,
      }),
      ['SHORT'],
      workerUserId,
    );
  });

  it('returns the server waterfall verbatim - the app computes no money', async () => {
    const result = await service.reportUstaadCashPayment(
      'booking-1',
      2500,
      workerUserId,
    );

    // The already-verified production numbers. If this ever changes, the
    // settlement waterfall itself changed - not this endpoint.
    expect(result).toMatchObject({
      expectedTotal: 2700,
      receivedCashTotal: 2500,
      partsPaid: 1700,
      labourPaid: 800,
      commission: 144,
      munafa: 656,
      shortfall: 200,
      isCurrent: true,
    });
  });

  it('rejects a job belonging to another Ustaad', async () => {
    await expect(
      service.reportUstaadCashPayment('booking-1', 2500, 'someone-else'),
    ).rejects.toThrow(ForbiddenException);
    expect(repository.createSettlement).not.toHaveBeenCalled();
  });

  it('rejects an amount larger than the payable total server-side', async () => {
    await expect(
      service.reportUstaadCashPayment('booking-1', 5000, workerUserId),
    ).rejects.toThrow(BadRequestException);
    expect(repository.createSettlement).not.toHaveBeenCalled();
  });

  it('rejects a job that is not completed yet', async () => {
    repository.findBooking.mockResolvedValue({
      ...baseBooking,
      status: BookingStatus.IN_PROGRESS,
    });

    await expect(
      service.reportUstaadCashPayment('booking-1', 100, workerUserId),
    ).rejects.toThrow(BadRequestException);
  });

  it('is idempotent - the same declaration retried returns the same record', async () => {
    repository.findBooking.mockResolvedValue({
      ...baseBooking,
      settlements: [
        {
          id: 'settlement-1',
          bookingId: 'booking-1',
          isCurrent: true,
          source: SettlementSource.USTAAD,
          expectedTotal: 2700,
          received: 2500,
          partsPaid: 1700,
          labourPaid: 800,
          feePaid: 0,
          commission: 144,
          munafa: 656,
          shortfall: 200,
          settledAt: new Date('2026-08-31T00:00:00.000Z'),
        },
      ],
    });

    const result = await service.reportUstaadCashPayment(
      'booking-1',
      2500,
      workerUserId,
    );

    expect(result.settlementId).toBe('settlement-1');
    expect(repository.createSettlement).not.toHaveBeenCalled();
  });

  it('refuses a second, different amount instead of silently overwriting', async () => {
    repository.findBooking.mockResolvedValue({
      ...baseBooking,
      settlements: [
        { id: 'settlement-1', isCurrent: true, received: 2500 } as any,
      ],
    });

    await expect(
      service.reportUstaadCashPayment('booking-1', 2000, workerUserId),
    ).rejects.toThrow(ConflictException);
  });

  it('does not push a notification back at the Ustaad who declared it', async () => {
    await service.reportUstaadCashPayment('booking-1', 2500, workerUserId);
    expect(notifications.notify).not.toHaveBeenCalled();
  });
});

describe('Payment notification to the Ustaad', () => {
  const workerUserId = 'worker-user-1';
  const clientUserId = 'client-user-1';
  const baseBooking = {
    id: 'booking-1',
    status: BookingStatus.COMPLETED,
    lane: BookingLane.BIDDING,
    workerProfileId: 'worker-1',
    finalPrice: 1000,
    inspectionFeeSnapshot: null,
    inspectionReport: null,
    clientProfile: { user: { id: clientUserId } },
    workerProfile: { user: { id: workerUserId } },
    settlements: [],
  };

  let repository: any;
  let notifications: any;
  let service: AdminOperationsService;

  beforeEach(() => {
    repository = {
      findBooking: jest.fn().mockResolvedValue(baseBooking),
      createSettlement: jest.fn().mockImplementation(async (data) => ({
        ...data,
        id: 'settlement-1',
        settledAt: new Date('2026-08-31T00:00:00.000Z'),
      })),
    };
    notifications = {
      wasAlreadyNotified: jest.fn().mockResolvedValue(false),
      notify: jest.fn().mockResolvedValue(undefined),
    };
    service = new AdminOperationsService(repository, undefined, notifications);
  });

  it('tells the Ustaad when the client paid in full, with a job deep link', async () => {
    await service.confirmClientCashPayment('booking-1', 1000, clientUserId);

    expect(notifications.notify).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: workerUserId,
        eventKey: NOTIFICATION_KEYS.PAYMENT_RECEIVED,
        bookingId: 'booking-1',
        route: '/worker/job/booking-1',
        entityType: 'booking',
        entityId: 'booking-1',
      }),
    );
  });

  it('uses the distinct short-payment key and carries the real amounts', async () => {
    await service.confirmClientCashPayment('booking-1', 400, clientUserId);

    const arg = notifications.notify.mock.calls[0][0];
    expect(arg.eventKey).toBe(NOTIFICATION_KEYS.PAYMENT_SHORT);
    expect(arg.payload).toEqual({
      receivedAmount: 400,
      expectedAmount: 1000,
      shortfall: 600,
    });
    expect(arg.body).toContain('400');
    expect(arg.body).toContain('600');
  });

  it('does not push twice for the same booking and event key', async () => {
    notifications.wasAlreadyNotified.mockResolvedValue(true);

    await service.confirmClientCashPayment('booking-1', 1000, clientUserId);

    expect(notifications.wasAlreadyNotified).toHaveBeenCalledWith(
      workerUserId,
      'booking-1',
      NOTIFICATION_KEYS.PAYMENT_RECEIVED,
    );
    expect(notifications.notify).not.toHaveBeenCalled();
  });

  it('never fails the settlement when the notification blows up', async () => {
    notifications.notify.mockRejectedValue(new Error('FCM down'));

    const result = await service.confirmClientCashPayment(
      'booking-1',
      1000,
      clientUserId,
    );

    expect(result.settlementId).toBe('settlement-1');
  });

  it('still settles when no notification service is wired at all', async () => {
    const bare = new AdminOperationsService(repository);
    await expect(
      bare.confirmClientCashPayment('booking-1', 1000, clientUserId),
    ).resolves.toMatchObject({ settlementId: 'settlement-1' });
  });
});
