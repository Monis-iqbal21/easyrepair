import { ForbiddenException } from '@nestjs/common';
import { MessageType, Role } from '@prisma/client';
import { ChatService } from './chat.service';

describe('ChatService.getOrCreateConversation', () => {
  let chatRepository: any;
  let storageService: any;
  let notificationsService: any;
  let bookingsService: any;
  let supportUserService: any;
  let service: ChatService;

  const WORKER_USER = { userId: 'worker-user-1' };

  function makeConversation(overrides: Partial<any> = {}) {
    return {
      id: 'conv-1',
      clientUserId: 'client-user-1',
      workerUserId: 'worker-user-1',
      createdByUserId: 'client-user-1',
      lastMessageAt: null,
      lastMessagePreview: null,
      createdAt: new Date(),
      updatedAt: new Date(),
      workerUser: {
        workerProfile: {
          firstName: 'Ali',
          lastName: 'Khan',
          avatarUrl: null,
          rating: 4.5,
        },
      },
      clientUser: {
        clientProfile: {
          firstName: 'Sara',
          lastName: 'Ahmed',
          avatarUrl: null,
        },
      },
      ...overrides,
    };
  }

  beforeEach(() => {
    chatRepository = {
      findWorkerUserByProfileId: jest.fn().mockResolvedValue(WORKER_USER),
      findConversation: jest.fn().mockResolvedValue(null),
      countUnread: jest.fn().mockResolvedValue(0),
      createConversation: jest.fn().mockResolvedValue(makeConversation()),
    };
    storageService = {};
    notificationsService = { notify: jest.fn().mockResolvedValue(undefined) };
    bookingsService = {
      assertClientCanChatWithWorker: jest.fn().mockResolvedValue(undefined),
    };
    supportUserService = {
      getSupportUserId: jest.fn().mockResolvedValue('support-user-id'),
      displayName: 'HandyGo Support',
      isSupportPhone: jest.fn().mockReturnValue(false),
    };
    service = new ChatService(
      chatRepository,
      storageService,
      notificationsService,
      bookingsService,
      supportUserService,
    );
  });

  // ── #7 Existing conversation is returned instead of duplicated ─────────
  it('reopens an existing conversation without re-checking eligibility or creating a new one', async () => {
    chatRepository.findConversation.mockResolvedValue(makeConversation());

    const result = await service.getOrCreateConversation(
      'client-user-1',
      'booking-1',
      'worker-1',
    );

    expect(result.id).toBe('conv-1');
    expect(
      bookingsService.assertClientCanChatWithWorker,
    ).not.toHaveBeenCalled();
    expect(chatRepository.createConversation).not.toHaveBeenCalled();
  });

  // ── #6 Client cannot chat with an unrelated/ineligible worker ───────────
  it('rejects creating a new conversation when the worker fails the eligibility check', async () => {
    bookingsService.assertClientCanChatWithWorker.mockRejectedValue(
      new ForbiddenException(
        'You are not allowed to chat with this worker for this booking.',
      ),
    );

    await expect(
      service.getOrCreateConversation('client-user-1', 'booking-1', 'worker-1'),
    ).rejects.toThrow(ForbiddenException);
    expect(chatRepository.createConversation).not.toHaveBeenCalled();
  });

  // ── #4/#5 Eligible Standard/Inspection worker before assignment ────────
  it('creates a new conversation once the shared eligibility check passes', async () => {
    const result = await service.getOrCreateConversation(
      'client-user-1',
      'booking-1',
      'worker-1',
    );

    expect(bookingsService.assertClientCanChatWithWorker).toHaveBeenCalledWith(
      'client-user-1',
      'booking-1',
      'worker-1',
    );
    expect(chatRepository.createConversation).toHaveBeenCalledWith({
      clientUserId: 'client-user-1',
      workerUserId: 'worker-user-1',
      createdByUserId: 'client-user-1',
    });
    expect(result.id).toBe('conv-1');
  });
});

describe('ChatService.sendVoiceMessage', () => {
  it('passes duration to persistence and returns it in the message response', async () => {
    const conversation = {
      id: 'conv-voice',
      clientUserId: 'client-1',
      workerUserId: 'worker-1',
      clientUser: {
        clientProfile: { firstName: 'Sara', lastName: 'Khan' },
      },
      workerUser: {
        workerProfile: { firstName: 'Ali', lastName: 'Khan' },
      },
    };
    const chatRepository = {
      findConversationById: jest.fn().mockResolvedValue(conversation),
      createVoiceMessage: jest.fn().mockImplementation(async (data) => ({
        id: 'message-voice',
        conversationId: data.conversationId,
        senderUserId: data.senderUserId,
        senderRole: data.senderRole,
        type: MessageType.VOICE,
        text: null,
        mediaUrl: data.mediaUrl,
        storageKey: data.storageKey,
        thumbnailUrl: null,
        mimeType: data.mimeType,
        fileName: data.fileName,
        sizeBytes: data.sizeBytes,
        durationSeconds: data.durationSeconds,
        latitude: null,
        longitude: null,
        bookingId: null,
        replyToMessageId: null,
        editedAt: null,
        deletedAt: null,
        seenAt: null,
        createdAt: new Date('2026-08-31T10:00:00.000Z'),
        updatedAt: new Date('2026-08-31T10:00:00.000Z'),
      })),
    };
    const storageService = {
      uploadFile: jest.fn().mockResolvedValue({
        url: 'https://cdn.invalid/voice.m4a',
        key: 'chat/voice.m4a',
        mimeType: 'audio/m4a',
        fileName: 'voice.m4a',
        sizeBytes: 1234,
      }),
    };
    const service = new ChatService(
      chatRepository as any,
      storageService as any,
      { notify: jest.fn() } as any,
      {} as any,
      { displayName: 'HandyGo Support' } as any,
    );

    const response = await service.sendVoiceMessage(
      'client-1',
      Role.CLIENT,
      'conv-voice',
      Buffer.from('voice'),
      'voice.m4a',
      'audio/m4a',
      6.425,
    );

    expect(chatRepository.createVoiceMessage).toHaveBeenCalledWith(
      expect.objectContaining({ durationSeconds: 6.425 }),
    );
    expect(response.durationSeconds).toBe(6.425);
  });
});

describe('BookingsService.assertClientCanChatWithWorker', () => {
  // These scenarios exercise the shared eligibility method directly (the
  // single source of truth ChatService delegates to), covering #4-#10, #13.
  let bookingsRepository: any;
  let storageService: any;
  let notificationsService: any;
  let chatService: any;
  let bookingsQueue: any;
  let BookingsService: typeof import('../bookings/bookings.service').BookingsService;
  let service: InstanceType<typeof BookingsService>;

  const BASE_BOOKING = {
    id: 'booking-1',
    clientProfile: { userId: 'client-user-1' },
    workerProfileId: null as string | null,
    inspectionReport: null as {
      workerProfile: { id: string } | null;
      decisionStatus: string;
    } | null,
    status: 'PENDING',
    lane: 'STANDARD',
    categoryId: 'cat-1',
    latitude: 24.86,
    longitude: 67.0,
    workerExclusions: [] as { workerProfileId: string }[],
  };

  beforeAll(async () => {
    ({ BookingsService } = await import('../bookings/bookings.service'));
  });

  beforeEach(() => {
    bookingsRepository = {
      findBookingById: jest.fn().mockResolvedValue(BASE_BOOKING),
      // Membership-test variant used by assertClientCanChatWithWorker — same
      // search/eligibility, ids only (no stats/ranking).
      findNearbyWorkerIds: jest
        .fn()
        .mockResolvedValue(new Set(['nearby-worker-1'])),
      hasBidFromWorker: jest.fn().mockResolvedValue(false),
    };
    storageService = {};
    notificationsService = {};
    chatService = {};
    bookingsQueue = { getJob: jest.fn(), add: jest.fn() };
    service = new BookingsService(
      bookingsRepository,
      storageService,
      notificationsService,
      chatService,
      bookingsQueue,
      { broadcastJob: jest.fn(), matchOpenJobsForWorker: jest.fn() } as any,
      { notifyClientJobCompleted: jest.fn() } as any,
    );
  });

  it('rejects when the caller does not own the booking', async () => {
    await expect(
      service.assertClientCanChatWithWorker(
        'someone-else',
        'booking-1',
        'nearby-worker-1',
      ),
    ).rejects.toThrow(ForbiddenException);
  });

  // ── #4 Eligible Standard-lane worker before assignment ──────────────────
  it('allows a worker present in the nearby-worker result for a PENDING STANDARD booking', async () => {
    await expect(
      service.assertClientCanChatWithWorker(
        'client-user-1',
        'booking-1',
        'nearby-worker-1',
      ),
    ).resolves.toBeUndefined();
  });

  // ── #5 Eligible Inspection-lane worker before assignment ────────────────
  it('allows a worker present in the nearby-worker result for a PENDING ordinary INSPECTION booking', async () => {
    bookingsRepository.findBookingById.mockResolvedValue({
      ...BASE_BOOKING,
      lane: 'INSPECTION',
      inspectionReport: null,
    });

    await expect(
      service.assertClientCanChatWithWorker(
        'client-user-1',
        'booking-1',
        'nearby-worker-1',
      ),
    ).resolves.toBeUndefined();
  });

  // ── #6 Cannot chat with an unrelated/ineligible worker ──────────────────
  it('rejects a worker who is not in the nearby-worker result and not assigned/inspecting', async () => {
    await expect(
      service.assertClientCanChatWithWorker(
        'client-user-1',
        'booking-1',
        'random-unrelated-worker',
      ),
    ).rejects.toThrow(ForbiddenException);
  });

  it('rejects an excluded worker even though the booking is still open', async () => {
    bookingsRepository.findNearbyWorkerIds.mockResolvedValue(new Set());
    await expect(
      service.assertClientCanChatWithWorker(
        'client-user-1',
        'booking-1',
        'excluded-worker',
      ),
    ).rejects.toThrow(ForbiddenException);
  });

  it('allows a bidder on a BIDDING-lane booking even though they are not in a nearby-worker list', async () => {
    bookingsRepository.findBookingById.mockResolvedValue({
      ...BASE_BOOKING,
      lane: 'BIDDING',
    });
    bookingsRepository.hasBidFromWorker.mockResolvedValue(true);

    await expect(
      service.assertClientCanChatWithWorker(
        'client-user-1',
        'booking-1',
        'bidder-1',
      ),
    ).resolves.toBeUndefined();
    expect(bookingsRepository.findNearbyWorkerIds).not.toHaveBeenCalled();
  });

  // ── #8 Assigned worker after a completed STANDARD job ───────────────────
  it('allows the assigned worker to chat after a completed STANDARD job', async () => {
    bookingsRepository.findBookingById.mockResolvedValue({
      ...BASE_BOOKING,
      lane: 'STANDARD',
      status: 'COMPLETED',
      workerProfileId: 'worker-1',
    });

    await expect(
      service.assertClientCanChatWithWorker(
        'client-user-1',
        'booking-1',
        'worker-1',
      ),
    ).resolves.toBeUndefined();
  });

  // ── #9 Assigned worker after a completed INSPECTION job (same inspector) ─
  it('allows the assigned worker to chat after a completed INSPECTION job (same inspecting worker)', async () => {
    bookingsRepository.findBookingById.mockResolvedValue({
      ...BASE_BOOKING,
      lane: 'INSPECTION',
      status: 'COMPLETED',
      workerProfileId: 'inspector-1',
      inspectionReport: {
        workerProfile: { id: 'inspector-1' },
        decisionStatus: 'ACCEPTED_REPAIR',
      },
    });

    await expect(
      service.assertClientCanChatWithWorker(
        'client-user-1',
        'booking-1',
        'inspector-1',
      ),
    ).resolves.toBeUndefined();
  });

  // ── #10 Find Other Ustaad completed booking → repair worker + inspector ─
  it('allows chatting with the repair worker on a completed Find Other Ustaad booking', async () => {
    bookingsRepository.findBookingById.mockResolvedValue({
      ...BASE_BOOKING,
      lane: 'INSPECTION',
      status: 'COMPLETED',
      workerProfileId: 'repair-worker-1',
      inspectionReport: {
        workerProfile: { id: 'inspector-1' },
        decisionStatus: 'FIND_OTHER_USTAAD',
      },
    });

    await expect(
      service.assertClientCanChatWithWorker(
        'client-user-1',
        'booking-1',
        'repair-worker-1',
      ),
    ).resolves.toBeUndefined();
  });

  it('still allows chatting with the original inspector on a completed Find Other Ustaad booking', async () => {
    bookingsRepository.findBookingById.mockResolvedValue({
      ...BASE_BOOKING,
      lane: 'INSPECTION',
      status: 'COMPLETED',
      workerProfileId: 'repair-worker-1',
      inspectionReport: {
        workerProfile: { id: 'inspector-1' },
        decisionStatus: 'FIND_OTHER_USTAAD',
      },
    });

    await expect(
      service.assertClientCanChatWithWorker(
        'client-user-1',
        'booking-1',
        'inspector-1',
      ),
    ).resolves.toBeUndefined();
  });

  // ── #13 Existing normal assigned-worker chat keeps working ──────────────
  it('allows the assigned worker to chat while the job is still in progress (regression)', async () => {
    bookingsRepository.findBookingById.mockResolvedValue({
      ...BASE_BOOKING,
      lane: 'STANDARD',
      status: 'IN_PROGRESS',
      workerProfileId: 'worker-1',
    });

    await expect(
      service.assertClientCanChatWithWorker(
        'client-user-1',
        'booking-1',
        'worker-1',
      ),
    ).resolves.toBeUndefined();
  });
});
