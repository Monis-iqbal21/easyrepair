import 'reflect-metadata';
import { METHOD_METADATA, PATH_METADATA } from '@nestjs/common/constants';
import { NotFoundException, RequestMethod } from '@nestjs/common';
import { CustomerAgreementsController } from './customer-agreements.controller';
import { AdminClientAgreementsController } from '../admin/admin-client-agreements.controller';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';

/**
 * The HTTP surface of the Client agreement feature — mirrors
 * workers.agreement-routes.spec.ts. Route paths are read from decorator
 * metadata rather than by booting an HTTP server, so this stays a fast unit
 * test while still proving the routes a deployment must expose, and that a
 * WORKER is structurally unable to call the Client endpoints (wrong role).
 */

function routeOf(target: object, method: string): string | null {
  const handler = (target as Record<string, unknown>)[method];
  if (typeof handler !== 'function') return null;
  return (Reflect.getMetadata(PATH_METADATA, handler) as string) ?? null;
}

function httpMethodOf(target: object, method: string): RequestMethod | null {
  const handler = (target as Record<string, unknown>)[method];
  if (typeof handler !== 'function') return null;
  return (
    (Reflect.getMetadata(METHOD_METADATA, handler) as RequestMethod) ?? null
  );
}

function fullPath(controller: new (...args: never[]) => object, path: string) {
  const base = Reflect.getMetadata(PATH_METADATA, controller) as string;
  return `/api/v1/${base}/${path}`.replace(/\/+/g, '/');
}

describe('Client agreement routes are registered', () => {
  it.each([
    ['getRequired', 'required', RequestMethod.GET],
    ['accept', ':agreementKey/accept', RequestMethod.POST],
    ['getHistory', 'history', RequestMethod.GET],
    [
      'download',
      'acceptances/:acceptanceId/download',
      RequestMethod.GET,
    ],
  ])('CustomerAgreementsController.%s → %s %s', (method, path, verb) => {
    expect(routeOf(CustomerAgreementsController.prototype, method)).toBe(
      path,
    );
    expect(httpMethodOf(CustomerAgreementsController.prototype, method)).toBe(
      verb,
    );
  });

  it.each([
    ['getClientAgreements', ':clientProfileId/agreements'],
    [
      'downloadClientAgreement',
      ':clientProfileId/agreements/:acceptanceId/download',
    ],
  ])('AdminClientAgreementsController.%s → GET %s', (method, path) => {
    expect(routeOf(AdminClientAgreementsController.prototype, method)).toBe(
      path,
    );
    expect(
      httpMethodOf(AdminClientAgreementsController.prototype, method),
    ).toBe(RequestMethod.GET);
  });

  it('exposes exactly the requested Client + Admin URLs', () => {
    expect([
      fullPath(
        CustomerAgreementsController,
        routeOf(CustomerAgreementsController.prototype, 'getRequired')!,
      ),
      fullPath(
        CustomerAgreementsController,
        routeOf(CustomerAgreementsController.prototype, 'accept')!,
      ),
      fullPath(
        CustomerAgreementsController,
        routeOf(CustomerAgreementsController.prototype, 'getHistory')!,
      ),
      fullPath(
        CustomerAgreementsController,
        routeOf(CustomerAgreementsController.prototype, 'download')!,
      ),
      fullPath(
        AdminClientAgreementsController,
        routeOf(
          AdminClientAgreementsController.prototype,
          'getClientAgreements',
        )!,
      ),
      fullPath(
        AdminClientAgreementsController,
        routeOf(
          AdminClientAgreementsController.prototype,
          'downloadClientAgreement',
        )!,
      ),
    ]).toEqual([
      '/api/v1/customer/agreements/required',
      '/api/v1/customer/agreements/:agreementKey/accept',
      '/api/v1/customer/agreements/history',
      '/api/v1/customer/agreements/acceptances/:acceptanceId/download',
      '/api/v1/admin/clients/:clientProfileId/agreements',
      '/api/v1/admin/clients/:clientProfileId/agreements/:acceptanceId/download',
    ]);
  });

  it('keeps the Client endpoints behind Role.CLIENT — a Worker cannot call them', () => {
    expect(Reflect.getMetadata(ROLES_KEY, CustomerAgreementsController)).toEqual([
      Role.CLIENT,
    ]);
  });

  it('keeps the admin endpoints behind Role.ADMIN', () => {
    expect(
      Reflect.getMetadata(ROLES_KEY, AdminClientAgreementsController),
    ).toEqual([Role.ADMIN]);
  });
});

// ── Behavioural tests: controller wiring, without a real Nest app ──────────

function makeController(
  overrides: {
    findClientProfileByUserId?: jest.Mock;
    findClientAcceptanceByUniqueKey?: jest.Mock;
    acceptResult?: unknown;
  } = {},
) {
  const repository = {
    findClientProfileByUserId:
      overrides.findClientProfileByUserId ??
      jest.fn(async () => ({
        id: 'cp-1',
        userId: 'user-1',
        firstName: 'Ayesha',
        lastName: 'Siddiqui',
      })),
    findClientAcceptanceByUniqueKey:
      overrides.findClientAcceptanceByUniqueKey ?? jest.fn(async () => null),
  };
  const templateService = {
    getTemplateForClient: jest.fn(() => ({
      documentType: 'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE',
      title: 'HandyGo Customer Terms, Booking Rules aur Privacy Notice',
      version: '1.0',
      agreementLocale: 'ur_Latn',
      sourceHash: 'a'.repeat(64),
      contentText: 'Full legal text…',
      legalLanguageNoticeRequired: false,
      requestedAppLocale: 'ur_Latn',
    })),
  };
  const acceptanceService = {
    accept: jest.fn(async () => overrides.acceptResult ?? { id: 'row-1' }),
  };
  const accessService = {
    listForClient: jest.fn(async () => []),
    getPdf: jest.fn(async () => ({
      body: Buffer.from('x'),
      contentType: 'application/pdf',
      fileName: 'x.pdf',
    })),
  };
  const controller = new CustomerAgreementsController(
    repository as never,
    templateService as never,
    acceptanceService as never,
    accessService as never,
  );
  return { controller, repository, templateService, acceptanceService, accessService };
}

describe('CustomerAgreementsController behaviour', () => {
  describe('GET required', () => {
    it('reports acceptance required for a client with no existing acceptance', async () => {
      const { controller } = makeController();
      const result = await controller.getRequired({ id: 'user-1' });

      expect(result.acceptanceRequired).toBe(true);
      expect(result.existingAcceptance).toBeNull();
      expect(result.agreement.version).toBe('1.0');
    });

    it('reports acceptance NOT required and echoes the existing record', async () => {
      const existing = {
        id: 'row-1',
        acceptanceId: 'HG-ACC-2026-ABCDEF123456',
        agreementVersion: '1.0',
        acceptedAt: new Date('2026-08-07T00:00:00.000Z'),
      };
      const { controller } = makeController({
        findClientAcceptanceByUniqueKey: jest.fn(async () => existing),
      });
      const result = await controller.getRequired({ id: 'user-1' });

      expect(result.acceptanceRequired).toBe(false);
      expect(result.existingAcceptance).toEqual({
        id: 'row-1',
        acceptanceId: 'HG-ACC-2026-ABCDEF123456',
        version: '1.0',
        acceptedAt: existing.acceptedAt,
      });
    });
  });

  describe('POST :agreementKey/accept', () => {
    it('rejects an unknown agreement key', async () => {
      const { controller } = makeController();
      await expect(
        controller.accept(
          { id: 'user-1', phone: '+92 300 1234567' },
          'not-a-real-key',
          { checkboxAccepted: true },
          '203.0.113.9',
          'test-agent',
        ),
      ).rejects.toThrow(NotFoundException);
    });

    it('resolves identity server-side and forwards only trusted fields', async () => {
      const { controller, acceptanceService } = makeController();
      await controller.accept(
        { id: 'user-1', phone: '+92 300 1234567' },
        'customer-terms',
        { checkboxAccepted: true, deviceDescriptor: 'my-phone' },
        '203.0.113.9',
        'test-agent',
      );

      expect(acceptanceService.accept).toHaveBeenCalledWith({
        clientProfileId: 'cp-1',
        userId: 'user-1',
        fullLegalName: 'Ayesha Siddiqui',
        registeredMobile: '+92 300 1234567',
        ipAddress: '203.0.113.9',
        deviceInfo: 'my-phone / test-agent',
        checkboxAccepted: true,
      });
    });
  });

  describe('client profile resolution', () => {
    it('404s when the authenticated user has no client profile', async () => {
      const { controller } = makeController({
        findClientProfileByUserId: jest.fn(async () => null),
      });
      await expect(controller.getHistory({ id: 'user-1' })).rejects.toThrow(
        NotFoundException,
      );
    });
  });
});
