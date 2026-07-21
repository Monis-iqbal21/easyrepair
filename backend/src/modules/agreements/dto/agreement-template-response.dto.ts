import { AgreementType } from '@prisma/client';

/** Worker-facing "View Agreement" payload — the exact text/version being accepted. */
export class AgreementTemplateResponseDto {
  id!: string;
  type!: AgreementType;
  title!: string;
  version!: string;
  contentText!: string;
}
