import { Injectable } from '@nestjs/common';
import {
  findCustomerSource,
  loadCustomerSourceText,
} from './source/customer-agreement-source.registry';
import {
  AgreementLocale,
  CustomerDocumentType,
} from './source/agreement-source.types';
import { parseAgreementLocale } from './source/acceptance-identity.util';

/**
 * The one document a Client must read and accept, resolved for the app's
 * current language. Mirrors UstaadTemplateService, minus trade resolution.
 */
export interface CustomerAgreementTemplateDto {
  documentType: CustomerDocumentType;
  title: string;
  version: string;
  /** The locale of the LEGAL BODY being returned — currently always ur_Latn. */
  agreementLocale: string;
  sourceHash: string;
  contentText: string;
  /**
   * True when the app language differs from the language of the approved
   * legal body, so the client must show "this approved agreement is
   * currently available in Roman Urdu". The legal text is NEVER
   * machine-translated.
   */
  legalLanguageNoticeRequired: boolean;
  /** The app locale the client asked for, echoed back for clarity. */
  requestedAppLocale: string;
}

const DOCUMENT_TYPE: CustomerDocumentType =
  'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE';

@Injectable()
export class CustomerTemplateService {
  /**
   * Resolves the Customer document in the language the app is currently
   * showing. English and Urdu-script legal bodies are PENDING_TRANSLATION,
   * so the approved Roman Urdu document is returned for every app language,
   * with `legalLanguageNoticeRequired` telling the client to explain that.
   */
  getTemplateForClient(
    requestedAppLocale: string,
  ): CustomerAgreementTemplateDto {
    const appLocale = parseAgreementLocale(requestedAppLocale) ?? 'ur_Latn';

    const requested = findCustomerSource(DOCUMENT_TYPE, appLocale);
    const useAppLocale = requested?.status === 'ACTIVE';
    const legalLocale: AgreementLocale = useAppLocale ? appLocale : 'ur_Latn';

    const source = loadCustomerSourceText(DOCUMENT_TYPE, legalLocale);

    return {
      documentType: DOCUMENT_TYPE,
      title: source.descriptor.title,
      version: source.descriptor.version,
      agreementLocale: legalLocale,
      sourceHash: source.sha256,
      contentText: source.text,
      legalLanguageNoticeRequired: legalLocale !== appLocale,
      requestedAppLocale: appLocale,
    };
  }
}
