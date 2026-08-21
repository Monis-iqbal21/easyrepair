import 'reflect-metadata';
import { BadRequestException, ConflictException } from '@nestjs/common';
import { METHOD_METADATA, PATH_METADATA } from '@nestjs/common/constants';
import {
  BookingLane,
  BookingStatus,
  InspectionDecisionStatus,
  SettlementSource,
} from '@prisma/client';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';
import {
  AdminBookingOperationsController,
  AdminCommissionCollectionsController,
  AdminSettlementCasesController,
} from './admin-operations.controller';
import { AdminOperationsService } from './admin-operations.service';
import {
  AdminOperationsRepository,
  CollectedCollectionImmutableError,
  SettlementAlreadyCollectedError,
} from './admin-operations.repository';

describe('AdminOperationsController authorization', () => {
  it('is restricted to ADMIN', () => {
    for (const controller of [
      AdminBookingOperationsController,
      AdminSettlementCasesController,
      AdminCommissionCollectionsController,
    ]) {
      expect(Reflect.getMetadata(ROLES_KEY, controller)).toEqual([Role.ADMIN]);
    }
  });

  it('exposes no direct commission-status mutation route', () => {
    const routes = Object.getOwnPropertyNames(
      AdminBookingOperationsController.prototype,
    ).flatMap((name) => {
      const handler = (AdminBookingOperationsController.prototype as any)[name];
      if (typeof handler !== 'function') return [];
      return [
        {
          path: Reflect.getMetadata(PATH_METADATA, handler),
          method: Reflect.getMetadata(METHOD_METADATA, handler),
        },
      ];
    });
    expect(
      routes.some((route) => route.path === ':bookingId/commission-status'),
    ).toBe(false);
  });
});

describe('AdminOperationsService settlements', () => {
  const baseBooking = {
    id: 'booking-1',
    status: BookingStatus.COMPLETED,
    lane: BookingLane.BIDDING,
    workerProfileId: 'worker-1',
    finalPrice: 1000,
    inspectionFeeSnapshot: null,
    inspectionReport: null,
    settlements: [],
  };
  let repository: any;
  let service: AdminOperationsService;

  beforeEach(() => {
    repository = {
      findBooking: jest.fn().mockResolvedValue(baseBooking),
      createSettlement: jest.fn().mockImplementation(async (data) => data),
      findEligibleSettlements: jest.fn(),
      findCollectionsForDate: jest.fn().mockResolvedValue([]),
      createNightlyCollections: jest.fn(),
    };
    service = new AdminOperationsService(repository);
  });

  it('derives all monetary values on the backend', async () => {
    await service.createSettlement(
      'booking-1',
      { received: 800, source: SettlementSource.ADMIN },
      'admin-1',
    );
    expect(repository.createSettlement).toHaveBeenCalledWith(
      expect.objectContaining({
        expectedParts: 0,
        expectedLabour: 1000,
        expectedFee: 0,
        expectedTotal: 1000,
        received: 800,
        labourPaid: 800,
        commission: 144,
        shortfall: 200,
        munafa: 656,
      }),
      ['SHORT'],
      'admin-1',
    );
  });

  it('creates a fully paid BIDDING settlement only from explicit receipt confirmation', async () => {
    await service.createSettlement(
      'booking-1',
      { received: 1000, source: SettlementSource.CLIENT },
      'admin-1',
    );
    expect(repository.createSettlement).toHaveBeenCalledWith(
      expect.objectContaining({
        expectedTotal: 1000,
        received: 1000,
        commission: 180,
      }),
      [],
      'admin-1',
    );
  });

  it('uses inspection parts/labour snapshots and never commissions parts', async () => {
    repository.findBooking.mockResolvedValue({
      ...baseBooking,
      lane: BookingLane.INSPECTION,
      finalPrice: 12000,
      inspectionReport: {
        decisionStatus: InspectionDecisionStatus.ACCEPTED_REPAIR,
        partsTotal: 9000,
        labourCost: 3000,
      },
    });
    await service.createSettlement(
      'booking-1',
      { received: 12000, source: SettlementSource.CLIENT },
      'admin-1',
    );
    expect(repository.createSettlement).toHaveBeenCalledWith(
      expect.objectContaining({
        expectedParts: 9000,
        expectedLabour: 3000,
        commission: 540,
      }),
      [],
      'admin-1',
    );
  });

  it('rejects an in-place replacement when a current settlement exists', async () => {
    repository.findBooking.mockResolvedValue({
      ...baseBooking,
      settlements: [
        {
          id: 'settlement-1',
          isCurrent: true,
          collectionItems: [],
        },
      ],
    });
    await expect(
      service.createSettlement(
        'booking-1',
        { received: 1000, source: SettlementSource.ADMIN },
        'admin-1',
      ),
    ).rejects.toThrow(ConflictException);
    expect(repository.createSettlement).not.toHaveBeenCalled();
  });

  it('correction must supersede the current immutable row', async () => {
    repository.findBooking.mockResolvedValue({
      ...baseBooking,
      settlements: [
        {
          id: 'settlement-current',
          isCurrent: true,
          collectionItems: [],
        },
      ],
    });
    await expect(
      service.correctSettlement(
        'booking-1',
        {
          supersedesId: 'settlement-old',
          received: 1000,
          source: SettlementSource.ADMIN,
        },
        'admin-1',
      ),
    ).rejects.toThrow(ConflictException);
  });

  it('rejects settlement before completion', async () => {
    repository.findBooking.mockResolvedValue({
      ...baseBooking,
      status: BookingStatus.IN_PROGRESS,
    });
    await expect(
      service.createSettlement(
        'booking-1',
        { received: 1000, source: SettlementSource.ADMIN },
        'admin-1',
      ),
    ).rejects.toThrow(BadRequestException);
  });

  it('rejects overpayment before writing an immutable row', async () => {
    await expect(
      service.createSettlement(
        'booking-1',
        { received: 1001, source: SettlementSource.ADMIN },
        'admin-1',
      ),
    ).rejects.toThrow(BadRequestException);
    expect(repository.createSettlement).not.toHaveBeenCalled();
  });

  it('blocks correction after any commission collection was created', async () => {
    repository.findBooking.mockResolvedValue({
      ...baseBooking,
      settlements: [
        {
          id: 'settlement-current',
          isCurrent: true,
          collectionItems: [{ id: 'item-1' }],
        },
      ],
    });
    await expect(
      service.correctSettlement(
        'booking-1',
        {
          supersedesId: 'settlement-current',
          received: 1000,
          source: SettlementSource.ADMIN,
        },
        'admin-1',
      ),
    ).rejects.toThrow(ConflictException);
  });
});

describe('AdminOperationsService nightly collection', () => {
  it('groups current authoritative commissions by worker and totals on backend', async () => {
    const repository: any = {
      findCollectionsForDate: jest.fn().mockResolvedValue([]),
      findEligibleSettlements: jest.fn().mockResolvedValue([
        { id: 's1', workerProfileId: 'w1', commission: 180 },
        { id: 's2', workerProfileId: 'w1', commission: 360 },
        { id: 's3', workerProfileId: 'w2', commission: 90 },
      ]),
      createNightlyCollections: jest
        .fn()
        .mockImplementation(async (_date, _actor, groups) =>
          [...groups.entries()].map(([workerProfileId, items]: any) => ({
            id: `collection-${workerProfileId}`,
            workerProfileId,
            amount: items.reduce(
              (sum: number, item: any) => sum + item.amount,
              0,
            ),
          })),
        ),
    };
    const service = new AdminOperationsService(repository);
    const result = await service.runNightly(
      { collectionDate: '2026-08-21' },
      'admin-1',
    );
    expect(result).toMatchObject({ workerCount: 2, totalAmount: 630 });
    const groups = repository.createNightlyCollections.mock.calls[0][2];
    expect(groups.get('w1')).toEqual([
      { settlementId: 's1', amount: 180 },
      { settlementId: 's2', amount: 360 },
    ]);
  });

  it('returns existing collections on a repeated fallback run', async () => {
    const existing = { id: 'collection-1', amount: 180, items: [] };
    const repository: any = {
      findCollectionsForDate: jest.fn().mockResolvedValue([existing]),
      findEligibleSettlements: jest.fn().mockResolvedValue([]),
      createNightlyCollections: jest.fn().mockResolvedValue([]),
    };
    const service = new AdminOperationsService(repository);

    await expect(
      service.runNightly({ collectionDate: '2026-08-21' }, 'admin-1'),
    ).resolves.toMatchObject({
      workerCount: 1,
      totalAmount: 180,
      collections: [existing],
    });
  });
});

describe('AdminOperationsRepository immutable transitions', () => {
  const correctionData = {
    bookingId: 'booking-1',
    workerProfileId: 'worker-1',
    supersedesId: 'settlement-old',
    expectedParts: 0,
    expectedLabour: 1000,
    expectedFee: 0,
    expectedTotal: 1000,
    received: 1000,
    source: SettlementSource.ADMIN,
    partsPaid: 0,
    labourPaid: 1000,
    feePaid: 0,
    commission: 180,
    munafa: 820,
    shortfall: 0,
    handygoPays: 0,
    settledByUserId: 'admin-1',
  } as any;

  it('atomically retires the old row and closes its cases before correction', async () => {
    const tx: any = {
      bookingSettlement: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'settlement-old',
          bookingId: 'booking-1',
          isCurrent: true,
          collectionItems: [],
          cases: [{ id: 'case-old', status: 'OPEN' }],
        }),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        create: jest.fn().mockResolvedValue({
          id: 'settlement-new',
          bookingId: 'booking-1',
          workerProfileId: 'worker-1',
        }),
      },
      settlementCase: {
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        create: jest.fn(),
      },
      settlementCaseEvent: {
        createMany: jest.fn().mockResolvedValue({ count: 1 }),
        create: jest.fn(),
      },
    };
    const repository = new AdminOperationsRepository({
      $transaction: (work: any) => work(tx),
    } as any);

    await repository.createSettlement(correctionData, [], 'admin-1');

    expect(tx.bookingSettlement.updateMany).toHaveBeenCalledWith({
      where: {
        id: 'settlement-old',
        bookingId: 'booking-1',
        isCurrent: true,
      },
      data: { isCurrent: false },
    });
    expect(tx.settlementCase.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ status: 'CLOSED' }),
      }),
    );
  });

  it('rejects correction once a collection item exists', async () => {
    const tx: any = {
      bookingSettlement: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'settlement-old',
          bookingId: 'booking-1',
          isCurrent: true,
          collectionItems: [{ id: 'item-1' }],
          cases: [],
        }),
      },
    };
    const repository = new AdminOperationsRepository({
      $transaction: (work: any) => work(tx),
    } as any);

    await expect(
      repository.createSettlement(correctionData, [], 'admin-1'),
    ).rejects.toThrow(SettlementAlreadyCollectedError);
  });

  it('never allows a COLLECTED collection to change state', async () => {
    const tx: any = {
      commissionCollection: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({
          id: 'collection-1',
          status: 'COLLECTED',
          items: [],
        }),
        update: jest.fn(),
      },
    };
    const repository = new AdminOperationsRepository({
      $transaction: (work: any) => work(tx),
    } as any);

    await expect(
      repository.updateCollection(
        'collection-1',
        'FAILED' as any,
        'provider rejected',
      ),
    ).rejects.toThrow(CollectedCollectionImmutableError);
    expect(tx.commissionCollection.update).not.toHaveBeenCalled();
  });

  it('marks booking commission paid only through collection completion', async () => {
    const tx: any = {
      commissionCollection: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({
          id: 'collection-1',
          status: 'PENDING',
          items: [{ settlement: { bookingId: 'booking-1' } }],
        }),
        update: jest.fn().mockResolvedValue({
          id: 'collection-1',
          status: 'COLLECTED',
          items: [{ settlement: { bookingId: 'booking-1' } }],
        }),
      },
      booking: { updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
    };
    const repository = new AdminOperationsRepository({
      $transaction: (work: any) => work(tx),
    } as any);

    await repository.updateCollection('collection-1', 'COLLECTED' as any);

    expect(tx.booking.updateMany).toHaveBeenCalledWith({
      where: { id: { in: ['booking-1'] } },
      data: {
        commissionStatus: 'PAID',
        commissionStatusUpdatedAt: expect.any(Date),
      },
    });
  });

  it('uses an upsert key so repeated nightly generation returns the existing collection', async () => {
    const existing = { id: 'collection-1', amount: 180, items: [] };
    const tx: any = {
      $queryRaw: jest
        .fn()
        .mockResolvedValue([{ id: 'settlement-1', commission: 180 }]),
      commissionCollection: { upsert: jest.fn().mockResolvedValue(existing) },
    };
    const repository = new AdminOperationsRepository({
      $transaction: (work: any) => work(tx),
    } as any);
    const groups = new Map([
      ['worker-1', [{ settlementId: 'settlement-1', amount: 180 }]],
    ]);

    await expect(
      repository.createNightlyCollections(
        new Date('2026-08-21T00:00:00.000Z'),
        'admin-1',
        groups,
      ),
    ).resolves.toEqual([existing]);
    expect(tx.commissionCollection.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          workerProfileId_collectionDate: {
            workerProfileId: 'worker-1',
            collectionDate: new Date('2026-08-21T00:00:00.000Z'),
          },
        },
        update: {},
      }),
    );
  });

  it('revalidates and locks candidates inside collection creation', async () => {
    const tx: any = {
      $queryRaw: jest.fn().mockResolvedValue([]),
      commissionCollection: { upsert: jest.fn() },
    };
    const repository = new AdminOperationsRepository({
      $transaction: (work: any) => work(tx),
    } as any);
    const staleSelection = new Map([
      ['worker-1', [{ settlementId: 'superseded-settlement', amount: 180 }]],
    ]);

    await expect(
      repository.createNightlyCollections(
        new Date('2026-08-21T00:00:00.000Z'),
        null,
        staleSelection,
      ),
    ).resolves.toEqual([]);

    expect(tx.$queryRaw).toHaveBeenCalledTimes(1);
    expect(tx.commissionCollection.upsert).not.toHaveBeenCalled();
  });

  it('uses locked database commission values instead of stale scan amounts', async () => {
    const tx: any = {
      $queryRaw: jest
        .fn()
        .mockResolvedValue([{ id: 'settlement-current', commission: 270 }]),
      commissionCollection: {
        upsert: jest.fn().mockImplementation(async ({ create }: any) => ({
          id: 'collection-1',
          amount: create.amount,
          items: create.items.create,
        })),
      },
    };
    const repository = new AdminOperationsRepository({
      $transaction: (work: any) => work(tx),
    } as any);

    const result = await repository.createNightlyCollections(
      new Date('2026-08-21T00:00:00.000Z'),
      'admin-1',
      new Map([
        ['worker-1', [{ settlementId: 'settlement-current', amount: 999 }]],
      ]),
    );

    expect(result[0]).toMatchObject({
      amount: 270,
      items: [{ settlementId: 'settlement-current', amount: 270 }],
    });
  });
});
