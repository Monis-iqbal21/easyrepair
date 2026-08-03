import 'reflect-metadata';
import { METHOD_METADATA, PATH_METADATA } from '@nestjs/common/constants';
import { RequestMethod } from '@nestjs/common';
import { WorkersController } from './workers.controller';
import { WorkersService } from './workers.service';
import { AdminController } from '../admin/admin.controller';
import { UstaadTemplateService } from '../agreements/ustaad-template.service';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';
import { sendPrivatePdf } from '../../common/utils/private-pdf-response.util';

/**
 * The HTTP surface of the Ustaad agreement feature.
 *
 * Every assertion here fails against the pre-agreement build. That build
 * answered `/agreement-templates` with the legacy
 * `{ id, type, title, version, contentText }` payload — no documentType, no
 * sourceHash, no locale — and did not register the download routes at all,
 * which is exactly what the Flutter client crashed on and what a route probe
 * saw as a 404.
 *
 * Route paths are read from the decorator metadata rather than by booting an
 * HTTP server, so this stays a fast unit test while still proving the routes
 * a deployment must expose.
 */

/** The path a controller method is registered under, or null if unrouted. */
function routeOf(target: object, method: string): string | null {
  const handler = (target as Record<string, unknown>)[method];
  if (typeof handler !== 'function') return null;
  const path = Reflect.getMetadata(PATH_METADATA, handler) as
    | string
    | undefined;
  return path ?? null;
}

function httpMethodOf(target: object, method: string): RequestMethod | null {
  const handler = (target as Record<string, unknown>)[method];
  if (typeof handler !== 'function') return null;
  return (
    (Reflect.getMetadata(METHOD_METADATA, handler) as RequestMethod) ?? null
  );
}

/** The full path a client calls, including the global `api/v1` prefix. */
function fullPath(controller: new (...args: never[]) => object, path: string) {
  const base = Reflect.getMetadata(PATH_METADATA, controller) as string;
  return `/api/v1/${base}/${path}`.replace(/\/+/g, '/');
}

// ── Routes the deployment must expose ───────────────────────────────────────

describe('Ustaad agreement routes are registered', () => {
  it.each([
    ['getAgreementTemplates', 'profile-completion/agreement-templates'],
    ['getMyAgreementAcceptances', 'profile-completion/agreements'],
    [
      'downloadMyAgreement',
      'profile-completion/agreements/:acceptanceId/download',
    ],
  ])('WorkersController.%s → GET %s', (method, path) => {
    expect(routeOf(WorkersController.prototype, method)).toBe(path);
    expect(httpMethodOf(WorkersController.prototype, method)).toBe(
      RequestMethod.GET,
    );
  });

  it.each([
    ['getWorkerAgreements', ':workerProfileId/agreements'],
    [
      'downloadWorkerAgreement',
      ':workerProfileId/agreements/:acceptanceId/download',
    ],
  ])('AdminController.%s → GET %s', (method, path) => {
    expect(routeOf(AdminController.prototype, method)).toBe(path);
    expect(httpMethodOf(AdminController.prototype, method)).toBe(
      RequestMethod.GET,
    );
  });

  it('exposes exactly the four agreement URLs the app and admin call', () => {
    expect([
      fullPath(
        WorkersController,
        routeOf(WorkersController.prototype, 'getAgreementTemplates')!,
      ),
      fullPath(
        WorkersController,
        routeOf(WorkersController.prototype, 'getMyAgreementAcceptances')!,
      ),
      fullPath(
        WorkersController,
        routeOf(WorkersController.prototype, 'downloadMyAgreement')!,
      ),
      fullPath(
        AdminController,
        routeOf(AdminController.prototype, 'getWorkerAgreements')!,
      ),
      fullPath(
        AdminController,
        routeOf(AdminController.prototype, 'downloadWorkerAgreement')!,
      ),
    ]).toEqual([
      '/api/v1/workers/profile-completion/agreement-templates',
      '/api/v1/workers/profile-completion/agreements',
      '/api/v1/workers/profile-completion/agreements/:acceptanceId/download',
      '/api/v1/admin/workers/:workerProfileId/agreements',
      '/api/v1/admin/workers/:workerProfileId/agreements/:acceptanceId/download',
    ]);
  });

  it('keeps both download routes behind the right role', () => {
    expect(Reflect.getMetadata(ROLES_KEY, WorkersController)).toEqual([
      Role.WORKER,
    ]);
    expect(Reflect.getMetadata(ROLES_KEY, AdminController)).toEqual([
      Role.ADMIN,
    ]);
  });
});

// ── The controller calls the three-document service, not the legacy one ─────

describe('WorkersController.getAgreementTemplates', () => {
  function makeController() {
    const workersService = {
      getAgreementTemplates: jest.fn().mockResolvedValue([]),
    };
    return {
      controller: new WorkersController(
        workersService as unknown as WorkersService,
        {} as never,
      ),
      workersService,
    };
  }

  it('passes the app locale from the query string through', async () => {
    const { controller, workersService } = makeController();
    await controller.getAgreementTemplates({ id: 'user-1' }, 'en', 'ur');
    expect(workersService.getAgreementTemplates).toHaveBeenCalledWith(
      'user-1',
      'en',
    );
  });

  it('falls back to Accept-Language, then to Roman Urdu', async () => {
    const a = makeController();
    await a.controller.getAgreementTemplates({ id: 'user-1' }, undefined, 'ur');
    expect(a.workersService.getAgreementTemplates).toHaveBeenCalledWith(
      'user-1',
      'ur',
    );

    const b = makeController();
    await b.controller.getAgreementTemplates({ id: 'user-1' });
    expect(b.workersService.getAgreementTemplates).toHaveBeenCalledWith(
      'user-1',
      'ur_Latn',
    );
  });
});

// ── The payload itself ──────────────────────────────────────────────────────

describe('the agreement-templates payload', () => {
  /** The real service chain, with only the database mocked out. */
  async function templatesFor(categoryName: string, appLocale = 'en') {
    const workersRepository = {
      findByUserId: jest.fn().mockResolvedValue({
        id: 'worker-1',
        onboardingStatus: 'DRAFT',
        skills: [{ category: { id: 'cat-1', name: categoryName } }],
      }),
    };
    const service = new WorkersService(
      workersRepository as never,
      {} as never,
      {} as never,
      new UstaadTemplateService(),
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    );
    const controller = new WorkersController(service, {} as never);
    return controller.getAgreementTemplates({ id: 'user-1' }, appLocale);
  }

  /** Exactly the contract the Flutter model parses as required/optional. */
  const EXPECTED_KEYS = [
    'documentType',
    'title',
    'version',
    'agreementLocale',
    'sourceHash',
    'applicableTrade',
    'contentText',
    'legalLanguageNoticeRequired',
    'requestedAppLocale',
  ];

  it('returns exactly the three Ustaad documents', async () => {
    const templates = await templatesFor('Electrician');

    expect(templates).toHaveLength(3);
    expect(templates.map((t) => t.documentType)).toEqual([
      'USTAAD_SERVICE_PROVIDER_AGREEMENT',
      'TRADE_SPECIFIC_SERVICE_AGREEMENT',
      'BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE',
    ]);
  });

  it('never includes the Customer document', async () => {
    const templates = await templatesFor('Plumber');

    for (const t of templates) {
      expect(t.documentType).not.toBe(
        'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE',
      );
      expect(t.title.toLowerCase()).not.toContain('customer');
      expect(t.contentText.toLowerCase()).not.toContain('customer terms');
    }
  });

  it('carries every field the client requires, and nothing legacy', async () => {
    const templates = await templatesFor('Electrician');

    for (const t of templates) {
      expect(Object.keys(t).sort()).toEqual([...EXPECTED_KEYS].sort());

      // The legacy payload was { id, type, title, version, contentText }.
      // Those two keys must not come back, or the client is talking to an
      // undeployed build.
      expect(t).not.toHaveProperty('id');
      expect(t).not.toHaveProperty('type');
    }
  });

  it('gives every required field a usable value', async () => {
    const templates = await templatesFor('Electrician');

    for (const t of templates) {
      // The client treats these as required and refuses to default them,
      // because version + sourceHash + locale ARE the acceptance evidence.
      expect(typeof t.documentType).toBe('string');
      expect(t.title).toBeTruthy();
      expect(t.version).toBe('1.0');
      expect(t.agreementLocale).toBe('ur_Latn');
      expect(t.sourceHash).toMatch(/^[0-9a-f]{64}$/);
      expect(t.contentText.length).toBeGreaterThan(1000);
      expect(typeof t.legalLanguageNoticeRequired).toBe('boolean');
      expect(t.requestedAppLocale).toBe('en');
    }
  });

  it('sets applicableTrade only on the trade-specific document', async () => {
    const templates = await templatesFor('Electrician');
    const byType = Object.fromEntries(
      templates.map((t) => [t.documentType, t]),
    );

    expect(byType.USTAAD_SERVICE_PROVIDER_AGREEMENT.applicableTrade).toBeNull();
    expect(
      byType.BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE.applicableTrade,
    ).toBeNull();
    expect(byType.TRADE_SPECIFIC_SERVICE_AGREEMENT.applicableTrade).toBe(
      'ELECTRICIAN',
    );
  });

  it.each([
    ['Electrician', 'ELECTRICIAN'],
    ['Plumber', 'PLUMBER'],
    ['AC Technician', 'AC_TECHNICIAN'],
    ['Carpenter', 'CARPENTER'],
  ])('serves the %s schedule, never a default', async (category, trade) => {
    const templates = await templatesFor(category);
    const tradeDoc = templates.find(
      (t) => t.documentType === 'TRADE_SPECIFIC_SERVICE_AGREEMENT',
    )!;
    expect(tradeDoc.applicableTrade).toBe(trade);
  });

  it('raises the language notice for English and Urdu, not Roman Urdu', async () => {
    for (const locale of ['en', 'ur']) {
      const templates = await templatesFor('Electrician', locale);
      expect(templates.every((t) => t.legalLanguageNoticeRequired)).toBe(true);
      // The legal body itself stays the approved Roman Urdu, untranslated.
      expect(templates.every((t) => t.agreementLocale === 'ur_Latn')).toBe(true);
    }

    const romanUrdu = await templatesFor('Electrician', 'ur_Latn');
    expect(romanUrdu.every((t) => !t.legalLanguageNoticeRequired)).toBe(true);
  });

  it('rejects a trade with no approved schedule', async () => {
    await expect(templatesFor('Painter')).rejects.toMatchObject({
      code: 'UNSUPPORTED_TRADE',
    });
  });
});

// ── Download responses ──────────────────────────────────────────────────────

describe('secure PDF responses', () => {
  function fakeResponse() {
    const headers: Record<string, string | number> = {};
    return {
      headers,
      body: null as Buffer | null,
      setHeader(key: string, value: string | number) {
        headers[key] = value;
      },
      end(body: Buffer) {
        this.body = body;
      },
    };
  }

  it('streams the bytes with sensitive-content headers', () => {
    const res = fakeResponse();
    sendPrivatePdf(res as never, {
      body: Buffer.from('%PDF-1.4'),
      contentType: 'application/pdf',
      fileName: 'handygo-agreement-HG-ACC-2026-AAAA.pdf',
    });

    expect(res.headers['Content-Type']).toBe('application/pdf');
    expect(res.headers['Content-Disposition']).toBe(
      'attachment; filename="handygo-agreement-HG-ACC-2026-AAAA.pdf"',
    );
    // A legal identity document must not sit in a proxy or disk cache.
    expect(res.headers['Cache-Control']).toContain('no-store');
    expect(res.headers['Cache-Control']).toContain('private');
    expect(res.body?.toString()).toBe('%PDF-1.4');
  });

  it('never lets a CNIC or a path escape into the filename', () => {
    const res = fakeResponse();
    sendPrivatePdf(res as never, {
      body: Buffer.from('%PDF'),
      contentType: 'application/pdf',
      fileName: '../../42101-1234567-1 "Ali".pdf',
    });

    const disposition = String(res.headers['Content-Disposition']);
    expect(disposition).not.toContain('..');
    expect(disposition).not.toContain('/');
    // The quoting cannot be broken out of.
    expect(disposition.match(/"/g)).toHaveLength(2);
  });
});
