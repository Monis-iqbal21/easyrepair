import { AgreementType } from '@prisma/client';

/**
 * Owner/admin-only view of a permanent acceptance record. Never include this
 * (or the pdfUrl it carries) in any booking/job/bid DTO — CNIC and agreement
 * PDFs must stay invisible to clients and other workers.
 */
export class AgreementAcceptanceResponseDto {
  id!: string;
  agreementType!: AgreementType;
  agreementTitle!: string;
  agreementVersion!: string;
  acceptedAt!: Date;
  acceptancePdfUrl!: string | null;
  createdAt!: Date;
}
