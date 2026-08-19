import { UnprocessableEntityException } from '@nestjs/common';
import { AvailabilityStatus } from '@prisma/client';

import { readFileSync } from 'fs';
import { join } from 'path';

import { WorkersService } from './workers.service';

/**
 * Ustaad registration creates the account at the end of Step 3, in DRAFT, so
 * that Step 4 can call the authenticated compliance endpoints. That means a
 * Worker row can now exist for someone who never finished registering — and
 * for someone whose profile is sitting in the admin queue.
 *
 * Neither may work. These rules are not new; this file exists because the new
 * registration flow makes those two states reachable in a way they were not
 * before, and a regression here would put unverified Ustaads in front of
 * Clients.
 */
describe('Worker onboarding eligibility', () => {
  const NOT_ALLOWED_TO_WORK = [
    'DRAFT',
    'CHANGES_REQUIRED',
    'SUBMITTED_FOR_REVIEW',
    'REJECTED',
  ] as const;

  describe('going online', () => {
    let service: WorkersService;
    let repository: any;

    function profile(overrides: Partial<any> = {}) {
      return {
        id: 'w1',
        onboardingStatus: 'APPROVED',
        profileCompleted: true,
        availabilityStatus: AvailabilityStatus.OFFLINE,
        skills: [{ id: 's1' }],
        ...overrides,
      };
    }

    beforeEach(() => {
      repository = {
        findByUserId: jest.fn(),
        updateAvailability: jest.fn().mockResolvedValue({
          availabilityStatus: AvailabilityStatus.ONLINE,
        }),
      };
      // Only the repository matters here; the rest of the graph is never
      // reached because every case below is rejected before any collaborator
      // is used.
      service = new WorkersService(
        repository,
        {} as any,
        {} as any,
        {} as any,
        {} as any,
        {} as any,
        {} as any,
        {} as any,
        {} as any,
      );
    });

    it.each(NOT_ALLOWED_TO_WORK)(
      'refuses ONLINE while onboardingStatus is %s',
      async (onboardingStatus) => {
        repository.findByUserId.mockResolvedValue(
          profile({ onboardingStatus }),
        );

        await expect(
          service.updateAvailability('u1', {
            status: AvailabilityStatus.ONLINE,
            lat: 24.86,
            lng: 67.0,
          } as any),
        ).rejects.toBeInstanceOf(UnprocessableEntityException);
        expect(repository.updateAvailability).not.toHaveBeenCalled();
      },
    );

    it('refuses ONLINE for an APPROVED worker whose profile is not complete',
      async () => {
        repository.findByUserId.mockResolvedValue(
          profile({ profileCompleted: false }),
        );

        await expect(
          service.updateAvailability('u1', {
            status: AvailabilityStatus.ONLINE,
            lat: 24.86,
            lng: 67.0,
          } as any),
        ).rejects.toBeInstanceOf(UnprocessableEntityException);
      });
  });

  describe('matching', () => {
    it('only ever considers APPROVED workers, so a DRAFT or submitted Ustaad '
      + 'is invisible to Clients', () => {
        // Asserted against the source rather than a mock: the filter is a
        // literal inside the query, and this is what makes deleting it fail.
        const source = readFileSync(
          join(__dirname, '..', 'matching', 'matching.repository.ts'),
          'utf8',
        );
        expect(source).toContain("onboardingStatus: 'APPROVED'");
        expect(source).toContain('profileCompleted: true');
      });
  });
});
