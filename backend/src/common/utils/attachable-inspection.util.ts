import { InspectionDecisionStatus } from '@prisma/client';

/**
 * THE single definition of "which of a client's past inspection reports may
 * be attached to a new, independently-posted BIDDING job".
 *
 * Shared by the two sides that must never disagree:
 *   - the selector listing (InspectionReportsRepository.findClientCompletedInspections)
 *   - the attach-time validation (BookingsService.createBooking)
 * so a report can never be listed as selectable and then rejected on submit,
 * or vice versa.
 *
 * Only decisions the client has already FINISHED qualify:
 *   - CLOSED_AFTER_INSPECTION — the case this feature exists for: the client
 *     paid the fee, closed the inspection, and later wants that diagnosis to
 *     inform a fresh bidding job.
 *   - ACCEPTED_REPAIR — a finished repair whose report is still useful
 *     context for related follow-up work.
 *
 * Deliberately excluded:
 *   - PENDING_CLIENT_DECISION — a live decision, not history.
 *   - FIND_OTHER_USTAAD — already owns the existing post-inspection repair
 *     flow via sourceInspectionBookingId; attaching it manually would create
 *     a second, conflicting representation of the same relationship.
 */
export const ATTACHABLE_INSPECTION_DECISION_STATUSES = [
  InspectionDecisionStatus.CLOSED_AFTER_INSPECTION,
  InspectionDecisionStatus.ACCEPTED_REPAIR,
] as const;

export function isAttachableDecisionStatus(
  status: InspectionDecisionStatus | string | null | undefined,
): boolean {
  return (ATTACHABLE_INSPECTION_DECISION_STATUSES as readonly string[]).includes(
    status as string,
  );
}
