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
    | 'CLOSED_AFTER_INSPECTION';
  parts: InspectionReportPartResponseDto[];
  photos: InspectionReportPhotoResponseDto[];
  createdAt: string;
  acceptedAt: string | null;
  closedAt: string | null;
}
