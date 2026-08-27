import { BadRequestException } from '@nestjs/common';

import { WorkersService } from './workers.service';
import { SubmitProfileCompletionDto } from './dto/submit-profile-completion.dto';
import { UpdateSkillsDto } from './dto/update-skills.dto';
import { UstaadTemplateService } from '../agreements/ustaad-template.service';
import { loadSourceText } from '../agreements/source/agreement-source.registry';

/**
 * What the 4-step Ustaad registration actually leaves on the profile, checked
 * against what `submitProfileForReview` demands.
 *
 * The app-side flow used to collect none of `fatherName`, `dateOfBirth`,
 * `liveSelfieUrl` or `legalNameConfirmedAt` — Step 3 uploaded the customer
 * avatar through `PATCH /workers/avatar` (which writes `avatarUrl` and nothing
 * else) and asked for neither the father's name nor a date of birth, and no
 * step ever set the legal-name confirmation. Every submission from that flow
 * was therefore rejected with MISSING_PROFILE_DATA and no Ustaad could finish
 * registering.
 *
 * These tests pin the contract from the backend side: this exact set, and no
 * fewer, is what a registration has to produce.
 */

/** Exactly the profile the fixed Step 3 + Step 4 write, and nothing more. */
const PROFILE_AFTER_REGISTRATION = {
  id: 'worker-1',
  onboardingStatus: 'DRAFT',

  // Step 1 → carried into Step 3's PATCH /workers/profile-completion
  fullLegalName: 'Kamran Sheikh',
  cnicNumber: '42101-1234567-1',

  // Step 3 — the three that were previously collected nowhere
  fatherName: 'Sheikh Rafiq',
  dateOfBirth: '1995-04-02',
  legalNameConfirmedAt: new Date('2026-08-01T00:00:00.000Z'),

  // Step 3 — composed from house / street / area / landmark
  residentialAddress: 'B-42, Street 14, Saddar',

  // Step 3 — exactly one trade, which is also what `profileCompleted` means
  skills: [
    {
      id: 'skill-1',
      yearsExperience: 3,
      category: { id: 'cat-1', name: 'Electrician' },
    },
  ],

  // Step 4
  cnicFrontUrl: 'https://cdn/front.jpg',
  cnicBackUrl: 'https://cdn/back.jpg',
  liveSelfieUrl: 'https://cdn/selfie.jpg',

  // Genuinely optional — the EVS document prints a controlled "Not applicable"
  emergencyContact: null,

  generalAgreementAcceptedAt: null,
  tradeAgreementAcceptedAt: null,
  generalAgreementVersion: null,
  tradeAgreementVersion: null,
  submittedForReviewAt: null,
  changesRequiredReason: null,
  rejectionReason: null,
  faceMatchStatus: 'PENDING',
  trainingStatus: 'NOT_STARTED',
};

function evidenceForElectrician() {
  const general = loadSourceText(
    'USTAAD_SERVICE_PROVIDER_AGREEMENT',
    'ur_Latn',
    null,
  );
  const trade = loadSourceText(
    'TRADE_SPECIFIC_SERVICE_AGREEMENT',
    'ur_Latn',
    'ELECTRICIAN',
  );
  const evs = loadSourceText(
    'BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE',
    'ur_Latn',
    null,
  );
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

const dto = (): SubmitProfileCompletionDto =>
  ({
    submissionAttemptId: 'attempt-1',
    agreements: evidenceForElectrician(),
  }) as never;

function makeService(profileOverrides: Record<string, unknown> = {}) {
  const profile = { ...PROFILE_AFTER_REGISTRATION, ...profileOverrides };
  const workersRepository = {
    findByUserId: jest.fn().mockResolvedValue(profile),
    submitForReview: jest.fn().mockResolvedValue(profile),
    findCategoriesByIds: jest
      .fn()
      .mockImplementation((ids: string[]) => ids.map((id) => ({ id }))),
    replaceSkills: jest.fn().mockResolvedValue([
      {
        id: 'skill-1',
        yearsExperience: 3,
        category: { id: 'cat-1', name: 'Electrician' },
      },
    ]),
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
  const service = new WorkersService(
    workersRepository as never,
    {} as never,
    {} as never,
    new UstaadTemplateService(),
    ustaadAcceptanceService as never,
    {} as never,
    {} as never,
    {} as never,
    {} as never,
  );
  return { service, workersRepository, ustaadAcceptanceService };
}

describe('the 4-step registration now satisfies submitProfileForReview', () => {
  it('accepts a profile carrying ONLY what registration collects', async () => {
    const { service, ustaadAcceptanceService } = makeService();

    const result = await service.submitProfileForReview(
      'user-1',
      '+923378372427',
      '203.0.113.9',
      'android',
      dto(),
    );

    expect(result.acceptedAgreements).toHaveLength(3);
    const input = ustaadAcceptanceService.acceptAll.mock.calls[0][0];
    expect(input.profileCompletionUpdate.onboardingStatus).toBe(
      'SUBMITTED_FOR_REVIEW',
    );
    expect(input.profileCompletionUpdate.submittedForReviewAt).toBeInstanceOf(
      Date,
    );
  });

  it('seals the identity registration supplied, from the profile', async () => {
    const { service, ustaadAcceptanceService } = makeService();
    await service.submitProfileForReview(
      'user-1',
      '+923378372427',
      null,
      null,
      dto(),
    );

    const input = ustaadAcceptanceService.acceptAll.mock.calls[0][0];
    expect(input.fullLegalName).toBe('Kamran Sheikh');
    expect(input.fatherName).toBe('Sheikh Rafiq');
    expect(input.dateOfBirth).toBe('1995-04-02');
    expect(input.cnicNumber).toBe('42101-1234567-1');
    expect(input.liveSelfieUrl).toBe('https://cdn/selfie.jpg');
    expect(input.mainSkillCategoryName).toBe('Electrician');
  });

  // One case per field the app-side flow used to omit. Each of these is a
  // registration that could not be completed before this work.
  it.each([
    ['fatherName', { fatherName: null }],
    ['dateOfBirth', { dateOfBirth: null }],
    ['liveSelfieUrl', { liveSelfieUrl: null }],
    ['legalNameConfirmedAt', { legalNameConfirmedAt: null }],
  ])(
    'still refuses the submission when %s is missing',
    async (_field, override) => {
      const { service, ustaadAcceptanceService } = makeService(override);

      await expect(
        service.submitProfileForReview('user-1', '+92337', null, null, dto()),
      ).rejects.toMatchObject({ code: 'MISSING_PROFILE_DATA' });
      expect(ustaadAcceptanceService.acceptAll).not.toHaveBeenCalled();
    },
  );

  it('refuses a profile carrying two skills, not just zero', async () => {
    const { service } = makeService({
      skills: [
        {
          id: 'skill-1',
          yearsExperience: 3,
          category: { id: 'cat-1', name: 'Electrician' },
        },
        {
          id: 'skill-2',
          yearsExperience: 1,
          category: { id: 'cat-2', name: 'Plumber' },
        },
      ],
    });

    await expect(
      service.submitProfileForReview('user-1', '+92337', null, null, dto()),
    ).rejects.toMatchObject({
      code: 'MISSING_PROFILE_DATA',
      details: { missingFields: expect.arrayContaining(['mainSkill']) },
    });
  });
});

describe('updateSkills stays single-skill', () => {
  it('accepts the one category registration sends', async () => {
    const { service, workersRepository } = makeService();
    await service.updateSkills('user-1', {
      categoryIds: ['cat-1'],
    } as UpdateSkillsDto);

    expect(workersRepository.replaceSkills).toHaveBeenCalledWith(
      'worker-1',
      ['cat-1'],
      undefined,
    );
  });

  it('rejects two — which is exactly what Step 3 used to send', async () => {
    const { service, workersRepository } = makeService();

    await expect(
      service.updateSkills('user-1', {
        categoryIds: ['cat-1', 'cat-2'],
      } as UpdateSkillsDto),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(workersRepository.replaceSkills).not.toHaveBeenCalled();
  });
});
