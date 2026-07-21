import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { AgreementType } from '@prisma/client';
import { createHash } from 'crypto';
import { AgreementsRepository } from './agreements.repository';
import { StorageService } from '../storage/storage.service';
import { generateAgreementAcceptancePdf } from '../../common/utils/agreement-pdf.util';
import { AgreementTemplateResponseDto } from './dto/agreement-template-response.dto';
import { AgreementAcceptanceResponseDto } from './dto/agreement-acceptance-response.dto';

export interface AcceptanceSubmissionInput {
  workerProfileId: string;
  userId: string;
  fullLegalName: string;
  cnicNumber: string;
  mobile: string;
  mainSkillCategoryId: string;
  mainSkillName: string;
  cnicFrontUrl: string | null;
  cnicBackUrl: string | null;
  liveSelfieUrl: string | null;
  ipAddress: string | null;
  deviceInfo: string | null;
}

@Injectable()
export class AgreementsService {
  constructor(
    private readonly agreementsRepository: AgreementsRepository,
    private readonly storageService: StorageService,
  ) {}

  /** The currently active template row for a type (+ category, for TRADE_SPECIFIC). */
  async getActiveTemplate(type: AgreementType, categoryId: string | null) {
    return this.agreementsRepository.findActiveTemplate(type, categoryId);
  }

  /** Active templates relevant to a worker, for the pre-acceptance "View Agreement" screen. */
  async getTemplatesForWorker(
    categoryId: string | null,
  ): Promise<AgreementTemplateResponseDto[]> {
    const [general, trade] = await Promise.all([
      this.agreementsRepository.findActiveTemplate(AgreementType.GENERAL_USTAAD, null),
      categoryId
        ? this.agreementsRepository.findActiveTemplate(
            AgreementType.TRADE_SPECIFIC,
            categoryId,
          )
        : null,
    ]);

    return [general, trade]
      .filter((t): t is NonNullable<typeof t> => t !== null)
      .map((t) => ({
        id: t.id,
        type: t.type,
        title: t.title,
        version: t.version,
        contentText: t.contentText,
      }));
  }

  /**
   * Create (or reuse) the two permanent AgreementAcceptance records — one
   * GENERAL_USTAAD, one TRADE_SPECIFIC — for a profile-completion submission,
   * generating a PDF for each newly-created record.
   *
   * IMPORTANT LEGAL RULE: existing acceptance rows are never updated. If the
   * worker already accepted the currently-active template version, that row
   * is reused as-is (no duplicate, no PDF regeneration). A version bump on
   * the template creates a *different* row (new agreementTemplateId), so it
   * naturally requires a brand-new acceptance here rather than colliding
   * with the old one.
   */
  async acceptAgreementsOnSubmit(
    input: AcceptanceSubmissionInput,
  ): Promise<AgreementAcceptanceResponseDto[]> {
    const results: AgreementAcceptanceResponseDto[] = [];

    const plan: { type: AgreementType; categoryId: string | null }[] = [
      { type: AgreementType.GENERAL_USTAAD, categoryId: null },
      { type: AgreementType.TRADE_SPECIFIC, categoryId: input.mainSkillCategoryId },
    ];

    for (const step of plan) {
      const template = await this.agreementsRepository.findActiveTemplate(
        step.type,
        step.categoryId,
      );
      if (!template) {
        throw new InternalServerErrorException(
          `No active ${step.type} agreement template is configured${
            step.categoryId ? ` for this trade` : ''
          }. Contact support.`,
        );
      }

      const existing = await this.agreementsRepository.findAcceptance(
        input.workerProfileId,
        template.id,
      );

      if (existing) {
        results.push({
          id: existing.id,
          agreementType: existing.agreementType,
          agreementTitle: existing.agreementTitle,
          agreementVersion: existing.agreementVersion,
          acceptedAt: existing.acceptedAt,
          acceptancePdfUrl: existing.acceptancePdfUrl,
          createdAt: existing.createdAt,
        });
        continue;
      }

      const acceptedAt = new Date();
      const contentHash = createHash('sha256')
        .update(template.contentText, 'utf8')
        .digest('hex');

      const created = await this.agreementsRepository.createAcceptance({
        workerProfileId: input.workerProfileId,
        userId: input.userId,
        agreementTemplateId: template.id,
        agreementType: template.type,
        agreementTitle: template.title,
        agreementVersion: template.version,
        agreementContentSnapshot: template.contentText,
        agreementFileSnapshotUrl: template.fileUrl,
        agreementFileSnapshotStorageKey: template.fileStorageKey,
        agreementHash: contentHash,
        fullLegalNameSnapshot: input.fullLegalName,
        cnicNumberSnapshot: input.cnicNumber,
        mobileSnapshot: input.mobile,
        mainSkillSnapshot: input.mainSkillName,
        cnicFrontUrlSnapshot: input.cnicFrontUrl,
        cnicBackUrlSnapshot: input.cnicBackUrl,
        liveSelfieUrlSnapshot: input.liveSelfieUrl,
        acceptedAt,
        ipAddress: input.ipAddress,
        deviceInfo: input.deviceInfo,
        checkboxAccepted: true,
      });

      const pdfBuffer = await generateAgreementAcceptancePdf({
        acceptanceId: created.id,
        fullLegalName: input.fullLegalName,
        cnicNumber: input.cnicNumber,
        mobile: input.mobile,
        agreementType: template.type,
        agreementTitle: template.title,
        agreementVersion: template.version,
        agreementContent: template.contentText,
        agreementHash: contentHash,
        acceptedAt,
        ipAddress: input.ipAddress,
        deviceInfo: input.deviceInfo,
        cnicFrontUrl: input.cnicFrontUrl,
        cnicBackUrl: input.cnicBackUrl,
        liveSelfieUrl: input.liveSelfieUrl,
      });

      const uploaded = await this.storageService.uploadFile(
        pdfBuffer,
        `agreement-${template.type.toLowerCase()}-${created.id}.pdf`,
        'application/pdf',
        `uploads/worker-documents/${input.workerProfileId}/agreements`,
      );

      const updated = await this.agreementsRepository.setAcceptancePdf(
        created.id,
        uploaded.url,
        uploaded.key,
      );

      results.push({
        id: updated.id,
        agreementType: updated.agreementType,
        agreementTitle: updated.agreementTitle,
        agreementVersion: updated.agreementVersion,
        acceptedAt: updated.acceptedAt,
        acceptancePdfUrl: updated.acceptancePdfUrl,
        createdAt: updated.createdAt,
      });
    }

    return results;
  }

  /** Owner/admin-only list of a worker's permanent acceptance records. */
  async listAcceptancesForWorker(
    workerProfileId: string,
  ): Promise<AgreementAcceptanceResponseDto[]> {
    const rows = await this.agreementsRepository.findAcceptancesByWorkerProfileId(
      workerProfileId,
    );
    return rows.map((r) => ({
      id: r.id,
      agreementType: r.agreementType,
      agreementTitle: r.agreementTitle,
      agreementVersion: r.agreementVersion,
      acceptedAt: r.acceptedAt,
      acceptancePdfUrl: r.acceptancePdfUrl,
      createdAt: r.createdAt,
    }));
  }
}
