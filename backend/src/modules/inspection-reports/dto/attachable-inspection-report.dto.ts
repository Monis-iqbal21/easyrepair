/**
 * One selectable entry in "attach a previous inspection report" while a
 * client posts a new BIDDING job.
 *
 * Deliberately minimal — just enough for the client to recognise which of
 * their own past inspections this is. The full report (parts, photos,
 * quote, voice note) is never included here; it is fetched through the
 * existing report viewer once a job actually references it, so this list
 * endpoint can never become a second copy of the report payload.
 */
export class AttachableInspectionReportDto {
  /** The historical inspection BOOKING id — this is what gets attached. */
  bookingId: string;
  categoryId: string;
  categoryName: string;
  /** When the inspection was completed (falls back to report creation). */
  inspectionDate: string;
  /** Short diagnosis line, when the report captured one in text. */
  issueFound: string | null;
  recommendedRepair: string | null;
}
