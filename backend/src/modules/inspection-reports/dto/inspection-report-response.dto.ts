export class InspectionReportPartResponseDto {
  id: string;
  name: string;
  quantity: number;
  unitPrice: number;
  warranty: string | null;
  lineTotal: number;
}

export class InspectionReportPhotoResponseDto {
  id: string;
  url: string;
  createdAt: string;
}

export class InspectionReportResponseDto {
  id: string;
  bookingId: string;
  workerProfileId: string;
  issueFound: string | null;
  recommendedRepair: string | null;
  labourCost: number;
  partsNeeded: boolean;
  partsTotal: number;
  /** labourCost + partsTotal. Not reduced by the inspection fee already paid. */
  repairQuoteTotal: number;
  /** The category's inspection fee snapshot at booking time — shown separately, informational only. */
  inspectionFeeSnapshot: number | null;
  notes: string | null;
  voiceNoteUrl: string | null;
  voiceNoteMimeType: string | null;
  voiceNoteDurationSeconds: number | null;
  decisionStatus:
    | 'PENDING_CLIENT_DECISION'
    | 'ACCEPTED_REPAIR'
    | 'CLOSED_AFTER_INSPECTION'
    | 'FIND_OTHER_USTAAD';
  parts: InspectionReportPartResponseDto[];
  photos: InspectionReportPhotoResponseDto[];
  createdAt: string;
  acceptedAt: string | null;
  closedAt: string | null;
}

/** Parts view for a bidder who hasn't been hired yet — name/qty/warranty only, no prices. */
export class SanitizedInspectionReportPartDto {
  id: string;
  name: string;
  quantity: number;
  warranty: string | null;
}

/**
 * Report view for an eligible-but-not-yet-hired bidder during the
 * "Find Other Ustaad" flow. Deliberately omits labourCost/partsTotal/
 * repairQuoteTotal/part prices/acceptedAt/closedAt — a bidder must never see
 * the inspecting Ustaad's original quotation before being hired.
 */
export class SanitizedInspectionReportResponseDto {
  id: string;
  bookingId: string;
  issueFound: string | null;
  recommendedRepair: string | null;
  notes: string | null;
  voiceNoteUrl: string | null;
  voiceNoteMimeType: string | null;
  voiceNoteDurationSeconds: number | null;
  partsNeeded: boolean;
  decisionStatus: 'FIND_OTHER_USTAAD';
  parts: SanitizedInspectionReportPartDto[];
  photos: InspectionReportPhotoResponseDto[];
  createdAt: string;
}
