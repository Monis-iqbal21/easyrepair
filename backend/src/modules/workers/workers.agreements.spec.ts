import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { AgreementType } from '@prisma/client';
import { WorkersService } from './workers.service';
import { SubmitProfileCompletionDto } from './dto/submit-profile-completion.dto';
import { UstaadTemplateService } from '../agreements/ustaad-template.service';
import { UstaadAgreementAccessService } from '../agreements/ustaad-agreement-access.service';
import { AgreementSubmissionError } from '../agreements/ustaad-acceptance.service';
import { loadSourceText } from '../agreements/source/agreement-source.registry';
import { AdminService } from '../admin/admin.service';

/**
 * The reachable production flow: which documents an Ustaad is shown, what
 * evidence the server demands back, and who may read an accepted PDF.
 *
 * Every test here exists because the alternative is a legal defect — a fourth
 * (Customer) document appearing in the Ustaad flow, a profile marked submitted
 * without three sealed records, or one Ustaad downloading another's CNIC-
 * bearing agreement.
 */

const COMPLETE_PROFILE = {
  id: 'worker-1',
  onboardingStatus: 'DRAFT',
  fullLegalName: 'Muhammad Ali Khan',
  fatherName: 'Abdul Rehman Khan',
  dateOfBirth: '1990-04-12',
  residentialAddress: 'House 12, Gulshan-e-Iqbal, Karachi',
  cnicNumber: '42101-1234567-1',
  emergencyContact: 'Fatima Khan, +92 300 1112233',
  cnicFrontUrl: 'https://cdn/front.jpg',
  cnicBackUrl: 'https://cdn/back.jpg',
  liveSelfieUrl: 'https://cdn/selfie.jpg',
  legalNameConfirmedAt: new Date('2026-08-01T00:00:00.000Z'),
  generalAgreementAcceptedAt: null,
  tradeAgreementAcceptedAt: null,
  generalAgreementVersion: null,
  tradeAgreementVersion: null,
  submittedForReviewAt: null,
  changesRequiredReason: null,
  rejectionReason: null,
  faceMatchStatus: 'PENDING',
  trainingStatus: 'NOT_STARTED',
  skills: [
    { id: 'skill-1', yearsExperience: 5, category: { id: 'cat-1', name: 'Electrician' } },
  ],
};

function evidenceForElectrician() {
  const general = loadSourceText('USTAAD_SERVICE_PROVIDER_AGREEMENT', 'ur_Latn', null);
  const trade = loadSourceText('TRADE_SPECIFIC_SERVICE_AGREEMENT', 'ur_Latn', 'ELECTRICIAN');
  const evs = loadSourceText('BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE', 'ur_Latn', null);
  const viewedAt = '2026-08-03T09:00:00.000Z';
  return [
    {
      documentType: 'USTAAD_SERVICE_PROVIDER_AGREEMENT',
      version: general.descriptor.version,
      sourceHash: general.sha256,
      agreementLocale: 'ur_Latn',
      applicableTrade: null,
      viewedAt,
      checkboxAccepted: true,
    },
    {
      documentType: 'TRADE_SPECIFIC_SERVICE_AGREEMENT',
      version: trade.descriptor.version,
      sourceHash: trade.sha256,
      agreementLocale: 'ur_Latn',
      applicableTrade: 'ELECTRICIAN',
      viewedAt,
      checkboxAccepted: true,
    },
    {
      documentType: 'BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE',
      version: evs.descriptor.version,
      sourceHash: evs.sha256,
      agreementLocale: 'ur_Latn',
      applicableTrade: null,
      viewedAt,
      checkboxAccepted: true,
    },
  ];
}

function makeService(profileOverrides: Record<string, unknown> = {}) {
  const profile = { ...COMPLETE_PROFILE, ...profileOverrides };
  const workersRepository = {
    findByUserId: jest.fn().mockResolvedValue(profile),
    submitForReview: jest.fn().mockResolvedValue(profile),
  };
  const ustaadAcceptanceService = {
    acceptAll: jest.fn().mockResolvedValue(
      evidenceForElectrician().map((e, i) => ({
        id: `row-${i}`,
        acceptanceId: `HG-ACC-2026-00000000000${i}`,
        documentType: e.documentType,
        title: 'Doc',
        version: e.version,
        agreementLocale: 'ur_Latn',
        applicableTrade: e.applicableTrade,
        acceptedAt: new Date('2026-08-03T09:05:00.000Z'),
        reused: false,
      })),
    ),
  };
  const ustaadAgreementAccess = {
    listForWorker: jest.fn().mockResolvedValue([]),
    getPdf: jest.fn().mockResolvedValue({
      body: Buffer.from('%PDF-1.4'),
      contentType: 'application/pdf',
      fileName: 'handygo-agreement-HG-ACC-2026-X.pdf',
    }),
  };
  const service = new WorkersService(
    workersRepository as never,
    {} as never,
    {} as never,
    new UstaadTemplateService(),
    ustaadAcceptanceService as never,
    ustaadAgreementAccess as never,
    {} as never,
    {} as never,
    {} as never,
  );
  return { service, workersRepository, ustaadAcceptanceService, ustaadAgreementAccess };
}

// ── Templates ───────────────────────────────────────────────────────────────

describe('GET /workers/profile-completion/agreement-templates', () => {
  it('returns exactly the three Ustaad documents', async () => {
    const { service } = makeService();
    const templates = await service.getAgreementTemplates('user-1', 'en');

    expect(templates).toHaveLength(3);
    expect(templates.map((t) => t.documentType)).toEqual([
      'USTAAD_SERVICE_PROVIDER_AGREEMENT',
      'TRADE_SPECIFIC_SERVICE_AGREEMENT',
      'BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE',
    ]);
  });

  it('never returns the Customer document', async () => {
    const { service } = makeService();
    const templates = await service.getAgreementTemplates('user-1', 'ur_Latn');

    for (const t of templates) {
      expect(t.documentType).not.toBe(
        'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE',
      );
      expect(t.title.toLowerCase()).not.toContain('customer');
    }
  });

  it('carries the fields the viewer and the evidence both need', async () => {
    const { service } = makeService();
    const [general, trade] = await service.getAgreementTemplates(
      'user-1',
      'en',
    );

    expect(general.version).toBeTruthy();
    expect(general.sourceHash).toHaveLength(64);
    expect(general.contentText.length).toBeGreaterThan(500);
    expect(general.agreementLocale).toBe('ur_Latn');
    expect(general.applicableTrade).toBeNull();
    // English app language + Roman Urdu legal body ⇒ the app must explain it.
    expect(general.legalLanguageNoticeRequired).toBe(true);
    expect(general.requestedAppLocale).toBe('en');
    expect(trade.applicableTrade).toBe('ELECTRICIAN');
  });

  it('does not raise the language notice when the app is already Roman Urdu', async () => {
    const { service } = makeService();
    const templates = await service.getAgreementTemplates('user-1', 'ur_Latn');
    expect(templates.every((t) => !t.legalLanguageNoticeRequired)).toBe(true);
  });

  it('rejects a trade with no approved schedule instead of substituting one', async () => {
    const { service } = makeService({
      skills: [
        { id: 's', yearsExperience: 1, category: { id: 'c', name: 'Painter' } },
      ],
    });

    await expect(
      service.getAgreementTemplates('user-1', 'en'),
    ).rejects.toBeInstanceOf(AgreementSubmissionError);
  });

  it('returns the correct schedule per trade, never a default', async () => {
    for (const [category, trade] of [
      ['Electrician', 'ELECTRICIAN'],
      ['Plumber', 'PLUMBER'],
      ['AC Technician', 'AC_TECHNICIAN'],
      ['Carpenter', 'CARPENTER'],
    ]) {
      const { service } = makeService({
        skills: [
          { id: 's', yearsExperience: 1, category: { id: 'c', name: category } },
        ],
      });
      const templates = await service.getAgreementTemplates('user-1', 'ur_Latn');
      const tradeDoc = templates.find(
        (t) => t.documentType === 'TRADE_SPECIFIC_SERVICE_AGREEMENT',
      );
      expect(tradeDoc?.applicableTrade).toBe(trade);
    }
  });
});

// ── Submission ──────────────────────────────────────────────────────────────

describe('POST /workers/profile-completion/submit', () => {
  const dto = (): SubmitProfileCompletionDto =>
    ({
      submissionAttemptId: 'attempt-1',
      agreements: evidenceForElectrician(),
    }) as never;

  it('hands all three evidence objects to the three-document service', async () => {
    const { service, ustaadAcceptanceService } = makeService();
    await service.submitProfileForReview(
      'user-1',
      '+923320219006',
      '203.0.113.9',
      'android',
      dto(),
    );

    expect(ustaadAcceptanceService.acceptAll).toHaveBeenCalledTimes(1);
    const input = ustaadAcceptanceService.acceptAll.mock.calls[0][0];
    expect(input.evidence).toHaveLength(3);
    expect(input.submissionAttemptId).toBe('attempt-1');
  });

  it('completes the profile inside the SAME call that creates the records', async () => {
    const { service, ustaadAcceptanceService } = makeService();
    await service.submitProfileForReview('user-1', '+92332', null, null, dto());

    const input = ustaadAcceptanceService.acceptAll.mock.calls[0][0];
    expect(input.profileCompletionUpdate.onboardingStatus).toBe(
      'SUBMITTED_FOR_REVIEW',
    );
    expect(input.profileCompletionUpdate.submittedForReviewAt).toBeInstanceOf(
      Date,
    );
    // The old two-column path must never be what decides submission is legal.
    expect(input.profileCompletionUpdate.generalAgreementVersion).toBe('1.0');
  });

  it('resolves identity from the profile, never from the request body', async () => {
    const { service, ustaadAcceptanceService } = makeService();
    await service.submitProfileForReview(
      'user-1',
      '+923320219006',
      null,
      null,
      dto(),
    );

    const input = ustaadAcceptanceService.acceptAll.mock.calls[0][0];
    expect(input.fullLegalName).toBe('Muhammad Ali Khan');
    expect(input.cnicNumber).toBe('42101-1234567-1');
    expect(input.fatherName).toBe('Abdul Rehman Khan');
    expect(input.dateOfBirth).toBe('1990-04-12');
    expect(input.registeredMobile).toBe('+923320219006');
    expect(input.mainSkillCategoryName).toBe('Electrician');
  });

  it('returns all three accepted agreement summaries', async () => {
    const { service } = makeService();
    const result = await service.submitProfileForReview(
      'user-1',
      '+92332',
      null,
      null,
      dto(),
    );
    expect(result.acceptedAgreements).toHaveLength(3);
    expect(result.acceptedAgreements[0].acceptanceId).toBeTruthy();
  });

  it.each(['fatherName', 'dateOfBirth', 'cnicNumber', 'fullLegalName'])(
    'blocks submission with a structured error when %s is missing',
    async (field) => {
      const { service, ustaadAcceptanceService } = makeService({
        [field]: null,
      });

      await expect(
        service.submitProfileForReview('user-1', '+92332', null, null, dto()),
      ).rejects.toMatchObject({ code: 'MISSING_PROFILE_DATA' });
      expect(ustaadAcceptanceService.acceptAll).not.toHaveBeenCalled();
    },
  );

  it('does not require the optional emergency contact', async () => {
    const { service } = makeService({ emergencyContact: null });
    await expect(
      service.submitProfileForReview('user-1', '+92332', null, null, dto()),
    ).resolves.toBeDefined();
  });
});

describe('SubmitProfileCompletionDto', () => {
  async function errorsFor(body: unknown) {
    return validate(plainToInstance(SubmitProfileCompletionDto, body));
  }

  it('accepts exactly three evidence objects', async () => {
    expect(
      await errorsFor({
        submissionAttemptId: 'a',
        agreements: evidenceForElectrician(),
      }),
    ).toHaveLength(0);
  });

  it.each([
    ['fewer', evidenceForElectrician().slice(0, 2)],
    ['more', [...evidenceForElectrician(), evidenceForElectrician()[0]]],
  ])('rejects %s than three evidence objects', async (_label, agreements) => {
    const errors = await errorsFor({ submissionAttemptId: 'a', agreements });
    expect(errors.length).toBeGreaterThan(0);
  });

  it('rejects the Customer document as a documentType', async () => {
    const agreements = evidenceForElectrician();
    (agreements[0] as { documentType: string }).documentType =
      'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE';
    const errors = await errorsFor({ submissionAttemptId: 'a', agreements });
    expect(errors.length).toBeGreaterThan(0);
  });

  it('requires a submissionAttemptId so a retry stays idempotent', async () => {
    const errors = await errorsFor({ agreements: evidenceForElectrician() });
    expect(errors.some((e) => e.property === 'submissionAttemptId')).toBe(true);
  });
});

// ── Secure list / download ──────────────────────────────────────────────────

function makeAccessService(rows: Record<string, unknown>[]) {
  const repository = {
    findUstaadAcceptances: jest.fn(async (workerProfileId: string) =>
      rows.filter((r) => r.workerProfileId === workerProfileId),
    ),
    findAcceptanceForDownloadByAcceptanceId: jest.fn(async (id: string) =>
      rows.find((r) => r.acceptanceId === id || r.id === id) ?? null,
    ),
  };
  const storage = {
    getObject: jest.fn().mockResolvedValue({
      body: Buffer.from('%PDF-1.4'),
      contentType: 'application/pdf',
    }),
    keyFromUrl: jest.fn().mockReturnValue(null),
  };
  return {
    access: new UstaadAgreementAccessService(repository as never, storage as never),
    repository,
    storage,
  };
}

const ROWS = [
  {
    id: 'row-1',
    acceptanceId: 'HG-ACC-2026-AAAA',
    workerProfileId: 'worker-1',
    userId: 'user-1',
    agreementType: AgreementType.GENERAL_USTAAD,
    agreementTitle: 'HandyGo Ustaad Service Provider Agreement',
    agreementVersion: '1.0',
    agreementLocale: 'UR_LATN',
    applicableTrade: null,
    sourceDocumentHash: 'a'.repeat(64),
    acceptedDocumentHash: 'b'.repeat(64),
    acceptedPdfHash: 'c'.repeat(64),
    documentViewedAt: new Date('2026-08-03T09:00:00.000Z'),
    acceptedAt: new Date('2026-08-03T09:05:00.000Z'),
    createdAt: new Date('2026-08-03T09:05:00.000Z'),
    acceptancePdfStorageKey: 'uploads/worker-documents/worker-1/agreements/x.pdf',
    acceptancePdfUrl: 'https://cdn.example.com/uploads/.../x.pdf',
  },
  {
    id: 'row-2',
    acceptanceId: 'HG-ACC-2026-BBBB',
    workerProfileId: 'worker-2',
    userId: 'user-2',
    agreementType: AgreementType.TRADE_SPECIFIC,
    agreementTitle: 'HandyGo Trade-Specific Service Agreement',
    agreementVersion: '1.0',
    agreementLocale: 'UR_LATN',
    applicableTrade: 'PLUMBER',
    sourceDocumentHash: 'd'.repeat(64),
    acceptedDocumentHash: 'e'.repeat(64),
    acceptedPdfHash: 'f'.repeat(64),
    documentViewedAt: new Date('2026-08-03T09:00:00.000Z'),
    acceptedAt: new Date('2026-08-03T09:05:00.000Z'),
    createdAt: new Date('2026-08-03T09:05:00.000Z'),
    acceptancePdfStorageKey: 'uploads/worker-documents/worker-2/agreements/y.pdf',
    acceptancePdfUrl: 'https://cdn.example.com/uploads/.../y.pdf',
  },
  {
    // Registered but must never surface in an Ustaad's legal history.
    id: 'row-3',
    acceptanceId: 'HG-ACC-2026-CCCC',
    workerProfileId: 'worker-1',
    userId: 'user-1',
    agreementType: AgreementType.CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE,
    agreementTitle: 'HandyGo Customer Terms',
    agreementVersion: '1.0',
    agreementLocale: 'UR_LATN',
    applicableTrade: null,
    sourceDocumentHash: null,
    acceptedDocumentHash: null,
    acceptedPdfHash: null,
    documentViewedAt: null,
    acceptedAt: new Date('2026-08-03T09:05:00.000Z'),
    createdAt: new Date('2026-08-03T09:05:00.000Z'),
    acceptancePdfStorageKey: 'uploads/customer/z.pdf',
    acceptancePdfUrl: 'https://cdn.example.com/uploads/.../z.pdf',
  },
];

describe('UstaadAgreementAccessService', () => {
  it('lists only the requested worker’s own records', async () => {
    const { access } = makeAccessService(ROWS);
    const mine = await access.listForWorker('worker-1');
    expect(mine.every((r) => r.acceptanceId !== 'HG-ACC-2026-BBBB')).toBe(true);
  });

  it('never exposes a storage URL in the listing', async () => {
    const { access } = makeAccessService(ROWS);
    const [record] = await access.listForWorker('worker-1');
    expect(JSON.stringify(record)).not.toContain('cdn.example.com');
    expect(record).not.toHaveProperty('acceptancePdfUrl');
  });

  it('returns the evidence hashes the admin screen shows', async () => {
    const { access } = makeAccessService(ROWS);
    const [record] = await access.listForWorker('worker-1');
    expect(record.sourceDocumentHash).toHaveLength(64);
    expect(record.acceptedDocumentHash).toHaveLength(64);
    expect(record.acceptedPdfHash).toHaveLength(64);
    expect(record.agreementLocale).toBe('ur_Latn');
  });

  it('serves the owner their own accepted PDF', async () => {
    const { access } = makeAccessService(ROWS);
    const pdf = await access.getPdf('HG-ACC-2026-AAAA', 'worker-1');
    expect(pdf.contentType).toBe('application/pdf');
    // No CNIC, phone or name in the filename an Ustaad ends up with on disk.
    expect(pdf.fileName).toBe('handygo-agreement-HG-ACC-2026-AAAA.pdf');
    expect(pdf.fileName).not.toContain('42101');
  });

  it('denies another worker’s acceptance id', async () => {
    const { access } = makeAccessService(ROWS);
    await expect(
      access.getPdf('HG-ACC-2026-BBBB', 'worker-1'),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('refuses to serve a Customer document even by direct id', async () => {
    const { access } = makeAccessService(ROWS);
    await expect(
      access.getPdf('HG-ACC-2026-CCCC', 'worker-1'),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('allows an admin (no owner scope) to read any record', async () => {
    const { access } = makeAccessService(ROWS);
    await expect(access.getPdf('HG-ACC-2026-BBBB')).resolves.toBeDefined();
  });
});

describe('Worker agreement endpoints are owner-scoped', () => {
  it('lists using the caller’s own profile id', async () => {
    const { service, ustaadAgreementAccess } = makeService();
    await service.getMyAgreementAcceptances('user-1');
    expect(ustaadAgreementAccess.listForWorker).toHaveBeenCalledWith('worker-1');
  });

  it('downloads with the caller’s own profile id as the ownership scope', async () => {
    const { service, ustaadAgreementAccess } = makeService();
    await service.downloadMyAgreement('user-1', 'HG-ACC-2026-AAAA');
    expect(ustaadAgreementAccess.getPdf).toHaveBeenCalledWith(
      'HG-ACC-2026-AAAA',
      'worker-1',
    );
  });
});

describe('Admin agreement endpoints', () => {
  function makeAdmin() {
    const adminRepository = {
      findById: jest.fn().mockResolvedValue({ id: 'worker-1' }),
    };
    const ustaadAgreementAccess = {
      listForWorker: jest.fn().mockResolvedValue([]),
      getPdf: jest.fn().mockResolvedValue({
        body: Buffer.from('%PDF'),
        contentType: 'application/pdf',
        fileName: 'handygo-agreement-HG-ACC-2026-AAAA.pdf',
      }),
    };
    return {
      admin: new AdminService(
        adminRepository as never,
        ustaadAgreementAccess as never,
        {} as never,
      ),
      adminRepository,
      ustaadAgreementAccess,
    };
  }

  it('lists a worker’s accepted agreements', async () => {
    const { admin, ustaadAgreementAccess } = makeAdmin();
    await admin.getWorkerAgreements('worker-1');
    expect(ustaadAgreementAccess.listForWorker).toHaveBeenCalledWith('worker-1');
  });

  it('scopes the download to the worker in the path', async () => {
    const { admin, ustaadAgreementAccess } = makeAdmin();
    await admin.downloadWorkerAgreement('worker-1', 'HG-ACC-2026-AAAA');
    expect(ustaadAgreementAccess.getPdf).toHaveBeenCalledWith(
      'HG-ACC-2026-AAAA',
      'worker-1',
    );
  });

  it('404s for a worker that does not exist', async () => {
    const { admin, adminRepository } = makeAdmin();
    adminRepository.findById.mockResolvedValue(null);
    await expect(admin.getWorkerAgreements('nope')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});
