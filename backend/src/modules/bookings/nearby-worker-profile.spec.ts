import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { BookingLane, BookingStatus, FaceMatchStatus } from '@prisma/client';
import { BookingsService } from './bookings.service';
import { BookingsController } from './bookings.controller';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';

/**
 * GET /bookings/:id/nearby-workers/:workerProfileId/profile
 *
 * The Ustaad detail behind the avatar in the Standard/Inspection selection
 * list. The two things these tests care about most are that a client cannot
 * read a worker they were never shown, and that nothing private leaks into
 * the response.
 */

const CLIENT_USER_ID = 'client-user-1';
const OTHER_CLIENT_USER_ID = 'client-user-2';
const WORKER_ID = 'worker-1';
const BOOKING_ID = 'booking-1';

function makePendingBooking(overrides: Partial<any> = {}) {
  return {
    id: BOOKING_ID,
    categoryId: 'cat-ac',
    clientProfileId: 'client-1',
    clientProfile: { id: 'client-1', userId: CLIENT_USER_ID },
    workerProfileId: null,
    status: BookingStatus.PENDING,
    lane: BookingLane.STANDARD,
    latitude: 24.86,
    longitude: 67.0,
    inspectionReport: null,
    workerExclusions: [],
    ...overrides,
  };
}

function makeWorkerProfile(overrides: Partial<any> = {}) {
  return {
    id: WORKER_ID,
    firstName: 'Rashid',
    lastName: 'Ali',
    avatarUrl: 'https://cdn.example/rashid.jpg',
    rating: 4.9,
    faceMatchStatus: FaceMatchStatus.MATCHED,
    user: { phone: '+923001234567' },
    skills: [
      {
        categoryId: 'cat-ac',
        yearsExperience: 8,
        category: { name: 'AC Repair' },
      },
      {
        categoryId: 'cat-fridge',
        yearsExperience: 3,
        category: { name: 'Refrigeration' },
      },
    ],
    ...overrides,
  };
}

function makeReview(n: number) {
  return {
    id: `review-${n}`,
    rating: 5,
    comment: `Great work ${n}`,
    createdAt: new Date(2026, 7, n + 1),
    booking: {
      category: { name: 'AC Repair' },
      clientProfile: { firstName: 'Sara', lastName: 'Ahmed' },
    },
  };
}

describe('BookingsService.getNearbyWorkerProfile', () => {
  let repo: any;
  let service: BookingsService;

  beforeEach(() => {
    repo = {
      findBookingById: jest.fn().mockResolvedValue(makePendingBooking()),
      // The eligible-worker set for this booking — the same membership test
      // the chat gate uses.
      findNearbyWorkerIds: jest
        .fn()
        .mockResolvedValue(new Set([WORKER_ID, 'worker-2'])),
      hasBidFromWorker: jest.fn().mockResolvedValue(false),
      findWorkerPublicProfile: jest
        .fn()
        .mockResolvedValue(makeWorkerProfile()),
      getWorkerReviewSummary: jest
        .fn()
        .mockResolvedValue({ totalReviews: 12, averageRating: 4.9 }),
      countCompletedJobs: jest.fn().mockResolvedValue(214),
      findLatestWorkerReviews: jest
        .fn()
        .mockImplementation((_id: string, limit: number) =>
          Promise.resolve(
            [1, 2, 3, 4, 5, 6, 7].slice(0, limit).map(makeReview),
          ),
        ),
    };

    service = new BookingsService(
      repo,
      {} as any,
      { notify: jest.fn() } as any,
      {} as any,
      { add: jest.fn(), getJob: jest.fn() } as any,
      { broadcastJob: jest.fn() } as any,
      {} as any,
    );
  });

  // ── Authorization ────────────────────────────────────────────────────────

  it('lets the client who owns the booking read an eligible worker', async () => {
    const dto = await service.getNearbyWorkerProfile(
      CLIENT_USER_ID,
      BOOKING_ID,
      WORKER_ID,
    );
    expect(dto.workerProfileId).toBe(WORKER_ID);
  });

  it('refuses another client using this booking', async () => {
    await expect(
      service.getNearbyWorkerProfile(
        OTHER_CLIENT_USER_ID,
        BOOKING_ID,
        WORKER_ID,
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(repo.findWorkerPublicProfile).not.toHaveBeenCalled();
  });

  it('refuses a guessed workerProfileId that was never shown for this booking', async () => {
    await expect(
      service.getNearbyWorkerProfile(
        CLIENT_USER_ID,
        BOOKING_ID,
        'some-unrelated-worker',
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(repo.findWorkerPublicProfile).not.toHaveBeenCalled();
  });

  it('404s on a nonexistent booking', async () => {
    repo.findBookingById.mockResolvedValue(null);
    await expect(
      service.getNearbyWorkerProfile(CLIENT_USER_ID, 'nope', WORKER_ID),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('404s when the worker row is gone after the visibility check', async () => {
    repo.findWorkerPublicProfile.mockResolvedValue(null);
    await expect(
      service.getNearbyWorkerProfile(CLIENT_USER_ID, BOOKING_ID, WORKER_ID),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('still allows the already-assigned worker on a non-PENDING booking', async () => {
    repo.findBookingById.mockResolvedValue(
      makePendingBooking({
        status: BookingStatus.COMPLETED,
        workerProfileId: WORKER_ID,
      }),
    );
    const dto = await service.getNearbyWorkerProfile(
      CLIENT_USER_ID,
      BOOKING_ID,
      WORKER_ID,
    );
    expect(dto.workerProfileId).toBe(WORKER_ID);
    // No nearby search needed once the worker is the assigned one.
    expect(repo.findNearbyWorkerIds).not.toHaveBeenCalled();
  });

  it('works for the INSPECTION lane, not just STANDARD', async () => {
    repo.findBookingById.mockResolvedValue(
      makePendingBooking({ lane: BookingLane.INSPECTION }),
    );
    const dto = await service.getNearbyWorkerProfile(
      CLIENT_USER_ID,
      BOOKING_ID,
      WORKER_ID,
    );
    expect(dto.workerProfileId).toBe(WORKER_ID);
  });

  it('is declared CLIENT-only, so a WORKER token cannot reach it', () => {
    // The role gate lives on the controller, not the service — assert it on
    // the handler's metadata rather than duplicating RolesGuard here.
    const roles = Reflect.getMetadata(
      ROLES_KEY,
      BookingsController.prototype.getNearbyWorkerProfile,
    );
    expect(roles).toEqual([Role.CLIENT]);
  });

  // ── Payload ──────────────────────────────────────────────────────────────

  it('returns phone, rating, completed jobs and the verification boolean', async () => {
    const dto = await service.getNearbyWorkerProfile(
      CLIENT_USER_ID,
      BOOKING_ID,
      WORKER_ID,
    );
    expect(dto.phone).toBe('+923001234567');
    expect(dto.averageRating).toBe(4.9);
    expect(dto.totalReviews).toBe(12);
    expect(dto.completedJobs).toBe(214);
    expect(dto.cnicVerified).toBe(true);
  });

  it('reports cnicVerified false when the admin has not matched CNIC to selfie', async () => {
    // Approval alone must never imply CNIC verification — AdminRepository
    // .approve never touches faceMatchStatus.
    repo.findWorkerPublicProfile.mockResolvedValue(
      makeWorkerProfile({ faceMatchStatus: FaceMatchStatus.PENDING }),
    );
    const dto = await service.getNearbyWorkerProfile(
      CLIENT_USER_ID,
      BOOKING_ID,
      WORKER_ID,
    );
    expect(dto.cnicVerified).toBe(false);
  });

  it('returns every skill with its own years, and the booking category as the relevant one', async () => {
    const dto = await service.getNearbyWorkerProfile(
      CLIENT_USER_ID,
      BOOKING_ID,
      WORKER_ID,
    );
    expect(dto.skills).toEqual([
      { name: 'AC Repair', yearsExperience: 8 },
      { name: 'Refrigeration', yearsExperience: 3 },
    ]);
    // The booking's category is cat-ac → 8, never 8 + 3.
    expect(dto.relevantExperienceYears).toBe(8);
  });

  it('reports null relevant experience when the worker has no skill for this category', async () => {
    repo.findBookingById.mockResolvedValue(
      makePendingBooking({ categoryId: 'cat-plumbing' }),
    );
    const dto = await service.getNearbyWorkerProfile(
      CLIENT_USER_ID,
      BOOKING_ID,
      WORKER_ID,
    );
    expect(dto.relevantExperienceYears).toBeNull();
  });

  // ── Reviews ──────────────────────────────────────────────────────────────

  it('asks the database for at most 5 reviews and returns 5', async () => {
    const dto = await service.getNearbyWorkerProfile(
      CLIENT_USER_ID,
      BOOKING_ID,
      WORKER_ID,
    );
    expect(repo.findLatestWorkerReviews).toHaveBeenCalledWith(WORKER_ID, 5);
    expect(dto.reviews).toHaveLength(5);
    expect(dto.reviews[0]).toEqual({
      id: 'review-1',
      rating: 5,
      comment: 'Great work 1',
      reviewerName: 'Sara Ahmed',
      serviceCategory: 'AC Repair',
      createdAt: new Date(2026, 7, 2).toISOString(),
    });
  });

  it('returns exactly 3 when the worker has 3', async () => {
    repo.findLatestWorkerReviews.mockResolvedValue([1, 2, 3].map(makeReview));
    const dto = await service.getNearbyWorkerProfile(
      CLIENT_USER_ID,
      BOOKING_ID,
      WORKER_ID,
    );
    expect(dto.reviews).toHaveLength(3);
  });

  it('returns an empty list when the worker has none', async () => {
    repo.findLatestWorkerReviews.mockResolvedValue([]);
    const dto = await service.getNearbyWorkerProfile(
      CLIENT_USER_ID,
      BOOKING_ID,
      WORKER_ID,
    );
    expect(dto.reviews).toEqual([]);
  });

  it('keeps a nameless reviewer anonymous rather than failing', async () => {
    repo.findLatestWorkerReviews.mockResolvedValue([
      {
        ...makeReview(1),
        booking: {
          category: { name: 'AC Repair' },
          clientProfile: null,
        },
      },
    ]);
    const dto = await service.getNearbyWorkerProfile(
      CLIENT_USER_ID,
      BOOKING_ID,
      WORKER_ID,
    );
    expect(dto.reviews[0].reviewerName).toBeNull();
  });

  // ── Privacy ──────────────────────────────────────────────────────────────

  it('leaks no CNIC, document, address or onboarding field', async () => {
    // The repository projection is narrow, but a future `...profile` spread
    // in the mapper would quietly widen the response — this pins the shape.
    repo.findWorkerPublicProfile.mockResolvedValue(
      makeWorkerProfile({
        // Deliberately hand the mapper private columns it must ignore.
        cnicNumber: '12345-1234567-1',
        cnicFrontUrl: 'https://cdn.example/front.jpg',
        cnicBackUrl: 'https://cdn.example/back.jpg',
        liveSelfieUrl: 'https://cdn.example/selfie.jpg',
        residentialAddress: 'House 1, Karachi',
        dateOfBirth: '1990-01-01',
        fatherName: 'Ahmed Ali',
        emergencyContact: 'Bilal, +923009999999',
        onboardingStatus: 'APPROVED',
        verificationStatus: 'VERIFIED',
        rejectionReason: null,
        changesRequiredReason: null,
      }),
    );

    const dto = await service.getNearbyWorkerProfile(
      CLIENT_USER_ID,
      BOOKING_ID,
      WORKER_ID,
    );

    expect(Object.keys(dto).sort()).toEqual(
      [
        'averageRating',
        'avatarUrl',
        'cnicVerified',
        'completedJobs',
        'firstName',
        'lastName',
        'phone',
        'relevantExperienceYears',
        'reviews',
        'skills',
        'totalReviews',
        'workerProfileId',
      ].sort(),
    );
    const serialized = JSON.stringify(dto);
    for (const secret of [
      '12345-1234567-1',
      'front.jpg',
      'back.jpg',
      'selfie.jpg',
      'House 1, Karachi',
      '1990-01-01',
      'Ahmed Ali',
      '+923009999999',
      'APPROVED',
    ]) {
      expect(serialized).not.toContain(secret);
    }
  });

  it('exposes no review internals beyond the public four fields', async () => {
    const dto = await service.getNearbyWorkerProfile(
      CLIENT_USER_ID,
      BOOKING_ID,
      WORKER_ID,
    );
    expect(Object.keys(dto.reviews[0]).sort()).toEqual([
      'comment',
      'createdAt',
      'id',
      'rating',
      'reviewerName',
      'serviceCategory',
    ]);
  });
});
