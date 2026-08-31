import 'reflect-metadata';
import {
  ExecutionContext,
  ForbiddenException,
  RequestMethod,
  UnauthorizedException,
} from '@nestjs/common';
import {
  GUARDS_METADATA,
  METHOD_METADATA,
  PATH_METADATA,
} from '@nestjs/common/constants';
import { ConfigService } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import { createHash } from 'crypto';
import { RedisService } from '../../redis/redis.service';
import { ComplaintsService } from '../complaints/complaints.service';
import { AdminClientsService } from './admin-clients.service';
import { AdminOperationsService } from './admin-operations.service';
import { AdminService } from './admin.service';
import { AdminReadonlyController } from './admin-readonly.controller';
import { ADMIN_READONLY_SCOPES } from './admin-readonly.constants';
import { AdminReadonlyGuard } from './admin-readonly.guard';
import { AdminReadonlyService } from './admin-readonly.service';

const RAW_KEY = 'test-readonly-key-with-at-least-32-characters';

function contextFor(authorization?: string): ExecutionContext {
  const request = {
    headers: { authorization },
    method: 'GET',
    path: '/api/v1/admin-readonly/stats',
    ip: '127.0.0.1',
  };
  return {
    switchToHttp: () => ({ getRequest: () => request }),
    getHandler: () => function handler() {},
    getClass: () => AdminReadonlyController,
  } as unknown as ExecutionContext;
}

describe('AdminReadonlyGuard', () => {
  function createGuard(overrides: Record<string, unknown> = {}) {
    const values: Record<string, unknown> = {
      'adminReadonly.apiKeySha256': createHash('sha256')
        .update(RAW_KEY)
        .digest('hex'),
      'adminReadonly.clientId': 'anzal-ops',
      'adminReadonly.scopes': ADMIN_READONLY_SCOPES.STATS,
      'adminReadonly.expiresAt': '2099-01-01T00:00:00.000Z',
      'adminReadonly.rateLimitPerMinute': 120,
      ...overrides,
    };
    const reflector = {
      getAllAndOverride: jest
        .fn()
        .mockReturnValue([ADMIN_READONLY_SCOPES.STATS]),
    };
    const config = { get: jest.fn((key: string) => values[key]) };
    const redis = { getClient: jest.fn().mockReturnValue(null) };
    return new AdminReadonlyGuard(
      reflector as unknown as Reflector,
      config as unknown as ConfigService,
      redis as unknown as RedisService,
    );
  }

  it('allows a valid, unexpired credential with the required scope', async () => {
    await expect(
      createGuard().canActivate(contextFor(`Bearer ${RAW_KEY}`)),
    ).resolves.toBe(true);
  });

  it('denies a missing credential', async () => {
    await expect(createGuard().canActivate(contextFor())).rejects.toThrow(
      UnauthorizedException,
    );
  });

  it('denies an invalid credential', async () => {
    await expect(
      createGuard().canActivate(
        contextFor('Bearer invalid-key-that-is-long-enough-to-parse'),
      ),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('denies an expired credential', async () => {
    await expect(
      createGuard({
        'adminReadonly.expiresAt': '2020-01-01T00:00:00.000Z',
      }).canActivate(contextFor(`Bearer ${RAW_KEY}`)),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('fails closed when the configured expiry is invalid', async () => {
    await expect(
      createGuard({
        'adminReadonly.expiresAt': 'not-a-date',
      }).canActivate(contextFor(`Bearer ${RAW_KEY}`)),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('denies a valid credential without the route scope', async () => {
    await expect(
      createGuard({
        'adminReadonly.scopes': ADMIN_READONLY_SCOPES.BOOKINGS,
      }).canActivate(contextFor(`Bearer ${RAW_KEY}`)),
    ).rejects.toThrow(ForbiddenException);
  });

  it('rate-limits repeated valid requests', async () => {
    const guard = createGuard({
      'adminReadonly.rateLimitPerMinute': 1,
    });
    await expect(
      guard.canActivate(contextFor(`Bearer ${RAW_KEY}`)),
    ).resolves.toBe(true);
    await expect(
      guard.canActivate(contextFor(`Bearer ${RAW_KEY}`)),
    ).rejects.toMatchObject({ status: 429 });
  });
});

describe('AdminReadonlyController route surface', () => {
  it('is guarded and exposes GET handlers only', () => {
    expect(Reflect.getMetadata(PATH_METADATA, AdminReadonlyController)).toBe(
      'admin-readonly',
    );
    expect(
      Reflect.getMetadata(GUARDS_METADATA, AdminReadonlyController),
    ).toContain(AdminReadonlyGuard);

    const methods: RequestMethod[] = [];
    for (const name of Object.getOwnPropertyNames(
      AdminReadonlyController.prototype,
    )) {
      if (name === 'constructor') continue;
      const descriptor = Object.getOwnPropertyDescriptor(
        AdminReadonlyController.prototype,
        name,
      );
      if (typeof descriptor?.value !== 'function') continue;
      const handler = descriptor.value as (...args: unknown[]) => unknown;
      const method = Reflect.getMetadata(METHOD_METADATA, handler) as
        | RequestMethod
        | undefined;
      if (method !== undefined) methods.push(method);
    }

    expect(methods).toHaveLength(12);
    expect(methods.every((method) => method === RequestMethod.GET)).toBe(true);
  });
});

describe('AdminReadonlyService response allowlists', () => {
  function createService() {
    const admin = {
      getStats: jest.fn(),
      getWorkers: jest.fn(),
      getWorkerById: jest.fn(),
    };
    const clients = { list: jest.fn(), getDetail: jest.fn() };
    const operations = {
      listBookings: jest.fn(),
      getBooking: jest.fn(),
      listCases: jest.fn(),
      getCase: jest.fn(),
      listCollections: jest.fn(),
    };
    const complaints = { list: jest.fn(), get: jest.fn() };
    return {
      admin,
      clients,
      operations,
      complaints,
      service: new AdminReadonlyService(
        admin as unknown as AdminService,
        clients as unknown as AdminClientsService,
        operations as unknown as AdminOperationsService,
        complaints as unknown as ComplaintsService,
      ),
    };
  }

  it('excludes worker identity documents, phone, address, and storage URLs', async () => {
    const { admin, service } = createService();
    admin.getWorkerById.mockResolvedValue({
      id: 'worker-1',
      userId: 'user-1',
      phone: '+923001234567',
      firstName: 'Safe',
      lastName: 'Worker',
      fullLegalName: 'Private Legal Name',
      cnicNumber: '12345-1234567-1',
      residentialAddress: 'Private address',
      cnicFrontUrl: '/admin/private/cnic',
      documents: [{ fileUrl: '/admin/private/file' }],
      status: 'ACTIVE',
      onboardingStatus: 'APPROVED',
      verificationStatus: 'VERIFIED',
      skills: [],
      faceMatchStatus: 'MATCHED',
      trainingStatus: 'PASSED',
      legalNameConfirmedAt: new Date(),
      generalAgreementAcceptedAt: new Date(),
      tradeAgreementAcceptedAt: new Date(),
      submittedForReviewAt: new Date(),
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    const json = JSON.stringify(await service.getWorker('worker-1'));
    expect(json).toContain('worker-1');
    expect(json).not.toContain('+923001234567');
    expect(json).not.toContain('12345-1234567-1');
    expect(json).not.toContain('Private address');
    expect(json).not.toContain('/admin/private');
  });

  it('excludes booking address/location/description, phones, and settlement notes', async () => {
    const { operations, service } = createService();
    operations.getBooking.mockResolvedValue({
      id: 'booking-1',
      clientProfileId: 'client-1',
      workerProfileId: 'worker-1',
      title: 'Repair',
      description: 'Private customer description',
      addressLine: 'Private street',
      latitude: 31.5,
      longitude: 74.3,
      clientProfile: { user: { phone: '+923001111111' } },
      workerProfile: { user: { phone: '+923002222222' } },
      settlements: [
        {
          id: 'settlement-1',
          note: 'Private internal note',
          settledByUserId: 'admin-user',
          received: 1000,
        },
      ],
    });

    const json = JSON.stringify(await service.getBooking('booking-1'));
    expect(json).toContain('booking-1');
    expect(json).not.toContain('Private customer description');
    expect(json).not.toContain('Private street');
    expect(json).not.toContain('+92300');
    expect(json).not.toContain('Private internal note');
    expect(json).not.toContain('admin-user');
  });

  it('excludes complaint free text, people, phones, event metadata, and notifications', async () => {
    const { complaints, service } = createService();
    complaints.get.mockResolvedValue({
      id: 'complaint-1',
      issueTypes: ['OTHER'],
      otherText: 'Private free text',
      reporter: { phone: '+923001111111' },
      assignedTo: { phone: '+923002222222' },
      events: [
        {
          id: 'event-1',
          type: 'CREATED',
          metadata: { secret: 'internal-event-data' },
          notification: { id: 'notification-1' },
          createdAt: new Date(),
        },
      ],
    });

    const json = JSON.stringify(await service.getComplaint('complaint-1'));
    expect(json).toContain('complaint-1');
    expect(json).not.toContain('Private free text');
    expect(json).not.toContain('+92300');
    expect(json).not.toContain('internal-event-data');
    expect(json).not.toContain('notification-1');
  });
});
