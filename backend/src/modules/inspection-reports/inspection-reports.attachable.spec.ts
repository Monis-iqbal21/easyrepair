import { ForbiddenException } from '@nestjs/common';
import { InspectionDecisionStatus } from '@prisma/client';
import { InspectionReportsService } from './inspection-reports.service';
import { InspectionReportsRepository } from './inspection-reports.repository';
import { ATTACHABLE_INSPECTION_DECISION_STATUSES } from '../../common/utils/attachable-inspection.util';

/**
 * The client-facing selector behind "attach a previous inspection report",
 * plus the worker-facing read path for a report reached through such an
 * attachment. Both must stay strictly separate from the existing
 * Find-Other-Ustaad flow.
 */
describe('InspectionReportsService.listAttachableForClient', () => {
  let repository: any;
  let service: InspectionReportsService;

  beforeEach(() => {
    repository = {
      findClientProfileByUserId: jest.fn().mockResolvedValue({ id: 'client-1' }),
      findClientCompletedInspections: jest.fn().mockResolvedValue([]),
    };
    service = new InspectionReportsService(
      repository,
      {} as any,
      {} as any,
      {} as any,
    );
  });

  function row(overrides: Partial<any> = {}) {
    return {
      id: 'insp-1',
      categoryId: 'cat-1',
      completedAt: new Date('2026-08-12T10:00:00.000Z'),
      createdAt: new Date('2026-08-11T10:00:00.000Z'),
      category: { id: 'cat-1', name: 'AC Technician' },
      inspectionReport: {
        id: 'report-1',
        issueFound: 'Cooling issue diagnosed',
        recommendedRepair: 'Replace compressor',
        decisionStatus: InspectionDecisionStatus.CLOSED_AFTER_INSPECTION,
        createdAt: new Date('2026-08-12T09:00:00.000Z'),
      },
      ...overrides,
    };
  }

  it('scopes the query to the AUTHENTICATED client, never a supplied id', async () => {
    await service.listAttachableForClient('client-user-1');

    expect(repository.findClientProfileByUserId).toHaveBeenCalledWith(
      'client-user-1',
    );
    expect(repository.findClientCompletedInspections).toHaveBeenCalledWith(
      expect.objectContaining({ clientProfileId: 'client-1' }),
    );
  });

  it('maps a report to the compact selector shape (booking id, category, date, diagnosis)', async () => {
    repository.findClientCompletedInspections.mockResolvedValue([row()]);

    const [item] = await service.listAttachableForClient('client-user-1');

    expect(item.bookingId).toBe('insp-1');
    expect(item.categoryName).toBe('AC Technician');
    expect(item.inspectionDate).toBe('2026-08-12T10:00:00.000Z');
    expect(item.issueFound).toBe('Cooling issue diagnosed');
  });

  it('passes categoryId through so the selector can filter to the posted service', async () => {
    await service.listAttachableForClient('client-user-1', 'cat-1');

    expect(repository.findClientCompletedInspections).toHaveBeenCalledWith({
      clientProfileId: 'client-1',
      categoryId: 'cat-1',
    });
  });

  it('returns an empty list (not an error) when the client has none', async () => {
    repository.findClientCompletedInspections.mockResolvedValue([]);

    await expect(
      service.listAttachableForClient('client-user-1'),
    ).resolves.toEqual([]);
  });

  it('rejects a caller with no client profile', async () => {
    repository.findClientProfileByUserId.mockResolvedValue(null);

    await expect(
      service.listAttachableForClient('worker-user-1'),
    ).rejects.toThrow(ForbiddenException);
  });

  it('falls back to the report date when completedAt is somehow absent', async () => {
    repository.findClientCompletedInspections.mockResolvedValue([
      row({ completedAt: null }),
    ]);

    const [item] = await service.listAttachableForClient('client-user-1');
    expect(item.inspectionDate).toBe('2026-08-12T09:00:00.000Z');
  });
});

describe('InspectionReportsRepository.findClientCompletedInspections', () => {
  it('filters to this client, INSPECTION lane, COMPLETED, and finished decisions only', async () => {
    const prisma = { booking: { findMany: jest.fn().mockResolvedValue([]) } };
    const repo = new InspectionReportsRepository(prisma as never);

    await repo.findClientCompletedInspections({
      clientProfileId: 'client-1',
      categoryId: 'cat-1',
    });

    const where = prisma.booking.findMany.mock.calls[0][0].where;
    expect(where.clientProfileId).toBe('client-1');
    expect(where.lane).toBe('INSPECTION');
    expect(where.status).toBe('COMPLETED');
    expect(where.categoryId).toBe('cat-1');
    // A report must exist AND be in a finished decision state.
    expect(where.inspectionReport.decisionStatus.in).toEqual([
      ...ATTACHABLE_INSPECTION_DECISION_STATUSES,
    ]);
  });

  it('omits the category filter when none is supplied', async () => {
    const prisma = { booking: { findMany: jest.fn().mockResolvedValue([]) } };
    const repo = new InspectionReportsRepository(prisma as never);

    await repo.findClientCompletedInspections({ clientProfileId: 'client-1' });

    expect(
      prisma.booking.findMany.mock.calls[0][0].where,
    ).not.toHaveProperty('categoryId');
  });
});

describe('attachable decision statuses — shared rule', () => {
  it('allows exactly the two finished-decision states', () => {
    expect([...ATTACHABLE_INSPECTION_DECISION_STATUSES]).toEqual([
      InspectionDecisionStatus.CLOSED_AFTER_INSPECTION,
      InspectionDecisionStatus.ACCEPTED_REPAIR,
    ]);
  });

  it('never allows FIND_OTHER_USTAAD — that relationship belongs to the existing post-inspection flow', () => {
    expect([...ATTACHABLE_INSPECTION_DECISION_STATUSES]).not.toContain(
      InspectionDecisionStatus.FIND_OTHER_USTAAD,
    );
  });

  it('never allows a still-pending client decision', () => {
    expect([...ATTACHABLE_INSPECTION_DECISION_STATUSES]).not.toContain(
      InspectionDecisionStatus.PENDING_CLIENT_DECISION,
    );
  });
});
