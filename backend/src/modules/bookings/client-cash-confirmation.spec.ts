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
import { BookingsController } from './bookings.controller';
import { ConfirmCashPaymentDto } from './dto/confirm-cash-payment.dto';

describe('Client cash-confirmation HTTP contract', () => {
  it('exposes the stable CLIENT-only booking route behind JWT and role guards', () => {
    const handler = BookingsController.prototype.confirmCashPayment;

    expect(Reflect.getMetadata(PATH_METADATA, handler)).toBe(
      ':bookingId/confirm-cash-payment',
    );
    expect(Reflect.getMetadata(METHOD_METADATA, handler)).toBe(
      RequestMethod.POST,
    );
    expect(Reflect.getMetadata(ROLES_KEY, handler)).toEqual([Role.CLIENT]);
    expect(Reflect.getMetadata(GUARDS_METADATA, BookingsController)).toEqual([
      JwtAuthGuard,
      RolesGuard,
    ]);
  });

  it('accepts zero whole rupees and rejects negative or fractional amounts', async () => {
    const zero = plainToInstance(ConfirmCashPaymentDto, {
      receivedCashTotal: 0,
    });
    const negative = plainToInstance(ConfirmCashPaymentDto, {
      receivedCashTotal: -1,
    });
    const fractional = plainToInstance(ConfirmCashPaymentDto, {
      receivedCashTotal: 10.5,
    });

    expect(await validate(zero)).toHaveLength(0);
    expect(await validate(negative)).not.toHaveLength(0);
    expect(await validate(fractional)).not.toHaveLength(0);
  });

  it('forbids WORKER and ADMIN roles while allowing CLIENT', () => {
    const guard = new RolesGuard(new Reflector());
    const contextFor = (role: Role) =>
      ({
        getHandler: () => BookingsController.prototype.confirmCashPayment,
        getClass: () => BookingsController,
        switchToHttp: () => ({ getRequest: () => ({ user: { role } }) }),
      }) as any;

    expect(guard.canActivate(contextFor(Role.CLIENT))).toBe(true);
    expect(guard.canActivate(contextFor(Role.WORKER))).toBe(false);
    expect(guard.canActivate(contextFor(Role.ADMIN))).toBe(false);
  });
});

describe('AdminOperationsService client cash confirmation', () => {
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
    settlements: [],
  };
  let repository: any;
  let service: AdminOperationsService;

  beforeEach(() => {
    repository = {
      findBooking: jest.fn().mockResolvedValue(baseBooking),
      createSettlement: jest.fn().mockImplementation(async (data) => ({
        ...data,
        id: 'settlement-1',
        settledAt: new Date('2026-08-22T00:00:00.000Z'),
      })),
    };
    service = new AdminOperationsService(repository);
  });

  it('creates a full BIDDING confirmation from finalPrice and returns only client-safe fields', async () => {
    const result = await service.confirmClientCashPayment(
      'booking-1',
      1000,
      clientUserId,
    );

    expect(repository.createSettlement).toHaveBeenCalledWith(
      expect.objectContaining({
        source: SettlementSource.CLIENT,
        received: 1000,
        expectedTotal: 1000,
        labourPaid: 1000,
        commission: 180,
      }),
      [],
      clientUserId,
    );
    expect(result).toEqual({
      settlementId: 'settlement-1',
      bookingId: 'booking-1',
      receivedCashTotal: 1000,
      expectedTotal: 1000,
      shortfall: 0,
      recordedAt: new Date('2026-08-22T00:00:00.000Z'),
      confirmationStatus: 'CONFIRMED',
      isCurrent: true,
    });
    expect(result).not.toHaveProperty('commission');
    expect(result).not.toHaveProperty('munafa');
  });

  it('supports partial payment and creates the existing shortfall case', async () => {
    const result = await service.confirmClientCashPayment(
      'booking-1',
      400,
      clientUserId,
    );

    expect(repository.createSettlement).toHaveBeenCalledWith(
      expect.objectContaining({ received: 400, shortfall: 600 }),
      ['SHORT'],
      clientUserId,
    );
    expect(result.shortfall).toBe(600);
  });

  it('derives a STANDARD booking total from its authoritative final price', async () => {
    repository.findBooking.mockResolvedValue({
      ...baseBooking,
      lane: BookingLane.STANDARD,
      finalPrice: 750,
    });

    await service.confirmClientCashPayment('booking-1', 750, clientUserId);

    expect(repository.createSettlement).toHaveBeenCalledWith(
      expect.objectContaining({
        expectedTotal: 750,
        expectedLabour: 750,
        received: 750,
      }),
      [],
      clientUserId,
    );
  });

  it('supports zero cash and creates the existing unpaid-labour case', async () => {
    const result = await service.confirmClientCashPayment(
      'booking-1',
      0,
      clientUserId,
    );

    expect(repository.createSettlement).toHaveBeenCalledWith(
      expect.objectContaining({
        received: 0,
        labourPaid: 0,
        commission: 0,
        shortfall: 1000,
      }),
      ['UNPAID_LABOUR'],
      clientUserId,
    );
    expect(result.receivedCashTotal).toBe(0);
  });

  it('uses the existing parts-first INSPECTION allocation', async () => {
    repository.findBooking.mockResolvedValue({
      ...baseBooking,
      lane: BookingLane.INSPECTION,
      finalPrice: 1000,
      inspectionReport: {
        decisionStatus: InspectionDecisionStatus.ACCEPTED_REPAIR,
        partsTotal: 900,
        labourCost: 100,
      },
    });

    await service.confirmClientCashPayment('booking-1', 950, clientUserId);

    expect(repository.createSettlement).toHaveBeenCalledWith(
      expect.objectContaining({
        expectedParts: 900,
        expectedLabour: 100,
        expectedFee: 0,
        expectedTotal: 1000,
        partsPaid: 900,
        labourPaid: 50,
        commission: 9,
        shortfall: 50,
      }),
      ['SHORT'],
      clientUserId,
    );
  });

  it('rejects another client booking without writing', async () => {
    await expect(
      service.confirmClientCashPayment('booking-1', 1000, 'other-client'),
    ).rejects.toThrow(ForbiddenException);
    expect(repository.createSettlement).not.toHaveBeenCalled();
  });

  it('rejects an incomplete booking', async () => {
    repository.findBooking.mockResolvedValue({
      ...baseBooking,
      status: BookingStatus.IN_PROGRESS,
    });

    await expect(
      service.confirmClientCashPayment('booking-1', 1000, clientUserId),
    ).rejects.toThrow(BadRequestException);
    expect(repository.createSettlement).not.toHaveBeenCalled();
  });

  it('rejects overpayment through the authoritative calculator', async () => {
    await expect(
      service.confirmClientCashPayment('booking-1', 1001, clientUserId),
    ).rejects.toThrow('Received cash cannot exceed the payable total');
    expect(repository.createSettlement).not.toHaveBeenCalled();
  });

  it('rejects a negative amount even when called below DTO validation', async () => {
    await expect(
      service.confirmClientCashPayment('booking-1', -1, clientUserId),
    ).rejects.toThrow('Settlement money values must be finite and non-negative');
    expect(repository.createSettlement).not.toHaveBeenCalled();
  });

  it('keeps a closed inspection fee-only with no repair price in settlement', async () => {
    repository.findBooking.mockResolvedValue({
      ...baseBooking,
      lane: BookingLane.INSPECTION,
      finalPrice: 900,
      inspectionFeeSnapshot: 900,
      inspectionReport: {
        decisionStatus: InspectionDecisionStatus.CLOSED_AFTER_INSPECTION,
        partsTotal: 7000,
        labourCost: 3000,
      },
    });

    await service.confirmClientCashPayment('booking-1', 900, clientUserId);

    expect(repository.createSettlement).toHaveBeenCalledWith(
      expect.objectContaining({
        expectedParts: 0,
        expectedLabour: 0,
        expectedFee: 900,
        expectedTotal: 900,
        feePaid: 900,
        commission: 0,
      }),
      [],
      clientUserId,
    );
  });

  it('returns the existing authoritative row for the same CLIENT retry', async () => {
    const current = {
      id: 'settlement-existing',
      bookingId: 'booking-1',
      source: SettlementSource.CLIENT,
      settledByUserId: clientUserId,
      received: 1000,
      expectedTotal: 1000,
      shortfall: 0,
      settledAt: new Date('2026-08-22T00:00:00.000Z'),
      isCurrent: true,
    };
    repository.findBooking.mockResolvedValue({
      ...baseBooking,
      settlements: [current],
    });

    const result = await service.confirmClientCashPayment(
      'booking-1',
      1000,
      clientUserId,
    );

    expect(result.settlementId).toBe('settlement-existing');
    expect(repository.createSettlement).not.toHaveBeenCalled();
  });

  it('rejects a different amount after confirmation and requires Admin correction', async () => {
    repository.findBooking.mockResolvedValue({
      ...baseBooking,
      settlements: [
        {
          id: 'settlement-existing',
          source: SettlementSource.CLIENT,
          settledByUserId: clientUserId,
          received: 1000,
          isCurrent: true,
        },
      ],
    });

    await expect(
      service.confirmClientCashPayment('booking-1', 900, clientUserId),
    ).rejects.toThrow(ConflictException);
    expect(repository.createSettlement).not.toHaveBeenCalled();
  });

  it('does not treat an ADMIN settlement as an idempotent CLIENT retry', async () => {
    repository.findBooking.mockResolvedValue({
      ...baseBooking,
      settlements: [
        {
          id: 'settlement-admin',
          source: SettlementSource.ADMIN,
          settledByUserId: 'admin-1',
          received: 1000,
          isCurrent: true,
        },
      ],
    });

    await expect(
      service.confirmClientCashPayment('booking-1', 1000, clientUserId),
    ).rejects.toThrow(ConflictException);
  });

  it('makes concurrent identical confirmations converge on one current row', async () => {
    let current: any = null;
    repository.findBooking.mockImplementation(async () => ({
      ...baseBooking,
      settlements: current ? [current] : [],
    }));
    repository.createSettlement.mockImplementation(async (data) => {
      await new Promise((resolve) => setImmediate(resolve));
      if (current) throw { code: 'P2002' };
      current = {
        ...data,
        id: 'settlement-winner',
        settledAt: new Date('2026-08-22T00:00:00.000Z'),
        isCurrent: true,
      };
      return current;
    });

    const results = await Promise.all([
      service.confirmClientCashPayment('booking-1', 1000, clientUserId),
      service.confirmClientCashPayment('booking-1', 1000, clientUserId),
    ]);

    expect(results.map((item) => item.settlementId)).toEqual([
      'settlement-winner',
      'settlement-winner',
    ]);
    expect(current.id).toBe('settlement-winner');
  });
});
