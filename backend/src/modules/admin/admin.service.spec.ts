import { AdminService } from './admin.service';

/** Flushes pending microtasks — requestChanges fires its notification via a
 * fire-and-forget IIFE that must never block the admin response, so tests
 * need to let that background work settle before asserting on it. */
function flushPromises(): Promise<void> {
  return new Promise((resolve) => setImmediate(resolve));
}

describe('AdminService', () => {
  let adminRepository: any;
  let agreementsService: any;
  let notificationsService: any;
  let service: AdminService;

  const UPDATED_PROFILE = {
    id: 'worker-1',
    user: { id: 'worker-user-1', phone: '+923001234567' },
    firstName: 'Ali',
    lastName: 'Khan',
    bio: null,
    avatarUrl: null,
    status: 'ACTIVE',
    verificationStatus: 'PENDING',
    skills: [],
    documents: [],
    createdAt: new Date(),
    fullLegalName: null,
    cnicNumber: null,
    residentialAddress: null,
    cnicFrontUrl: null,
    cnicBackUrl: null,
    liveSelfieUrl: null,
    faceMatchStatus: 'PENDING',
    trainingStatus: 'PENDING',
    onboardingStatus: 'CHANGES_REQUIRED',
    legalNameConfirmedAt: null,
    generalAgreementAcceptedAt: null,
    tradeAgreementAcceptedAt: null,
    generalAgreementVersion: null,
    tradeAgreementVersion: null,
    submittedForReviewAt: null,
    changesRequiredReason: 'CNIC photo is blurry',
    rejectionReason: null,
  };

  beforeEach(() => {
    adminRepository = {
      findById: jest.fn().mockResolvedValue({ id: 'worker-1' }),
      findWorkerByIdFull: jest.fn().mockResolvedValue(UPDATED_PROFILE),
      requestChanges: jest.fn().mockResolvedValue(UPDATED_PROFILE),
    };
    agreementsService = {};
    notificationsService = {
      wasRecentlyNotifiedForEntity: jest.fn().mockResolvedValue(false),
      notify: jest.fn().mockResolvedValue(undefined),
    };
    service = new AdminService(
      adminRepository,
      agreementsService,
      notificationsService,
    );
  });

  // ── #1 Admin marks profile CHANGES_REQUIRED → stored notification + push ──
  it('notifies the worker with a Roman Urdu title/body when changes are required', async () => {
    await service.requestChanges('worker-1', 'CNIC photo is blurry');
    await flushPromises();

    expect(notificationsService.notify).toHaveBeenCalledTimes(1);
    const call = notificationsService.notify.mock.calls[0][0];
    expect(call.userId).toBe('worker-user-1');
    expect(call.eventKey).toBe('worker.onboarding.changes_required');
    expect(call.title).toBe('Profile mein tabdeeli darkaar hai');
    expect(call.route).toBe('/worker/profile-completion');
    expect(call.entityType).toBe('worker_profile');
    expect(call.entityId).toBe('worker-1');
  });

  // ── #2 Change reason included when available ────────────────────────────
  it('includes the admin-provided reason in the notification body and payload', async () => {
    await service.requestChanges('worker-1', 'CNIC photo is blurry');
    await flushPromises();

    const call = notificationsService.notify.mock.calls[0][0];
    expect(call.body).toContain('CNIC photo is blurry');
    expect(call.payload).toEqual({ reason: 'CNIC photo is blurry' });
  });

  // ── #3 Duplicate admin request does not create duplicate notification ──
  it('does not send a second notification when already recently notified for this entity', async () => {
    notificationsService.wasRecentlyNotifiedForEntity.mockResolvedValue(true);

    await service.requestChanges('worker-1', 'CNIC photo is blurry');
    await flushPromises();

    expect(notificationsService.wasRecentlyNotifiedForEntity).toHaveBeenCalledWith(
      'worker-user-1',
      'worker_profile',
      'worker-1',
      'worker.onboarding.changes_required',
      10_000,
    );
    expect(notificationsService.notify).not.toHaveBeenCalled();
  });

  it('still persists the onboarding status change even when the notification is skipped', async () => {
    notificationsService.wasRecentlyNotifiedForEntity.mockResolvedValue(true);

    const result = await service.requestChanges('worker-1', 'CNIC photo is blurry');
    await flushPromises();

    expect(adminRepository.requestChanges).toHaveBeenCalledWith(
      'worker-1',
      'CNIC photo is blurry',
    );
    expect(result).toBeDefined();
  });
});
