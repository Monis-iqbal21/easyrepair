import { Injectable } from '@nestjs/common';
import {
  activeSources,
  findSource,
  loadSourceText,
} from './source/agreement-source.registry';
import {
  TradeCode,
  USTAAD_DOCUMENT_TYPES,
  UstaadDocumentType,
} from './source/agreement-source.types';
import { tradeCodeForCategoryName } from './source/trade-mapping.util';
import { parseAgreementLocale } from './source/acceptance-identity.util';

/**
 * The three documents an Ustaad must read and accept, resolved for one worker.
 *
 * The Customer document is unreachable here: the list is derived from
 * USTAAD_DOCUMENT_TYPES.
 */
export interface UstaadAgreementTemplateDto {
  documentType: UstaadDocumentType;
  title: string;
  version: string;
  /** The locale of the LEGAL BODY being returned — currently always ur_Latn. */
  agreementLocale: string;
  sourceHash: string;
  applicableTrade: string | null;
  contentText: string;
  /**
   * True when the app language differs from the language of the approved
   * legal body, so the client must show "this approved agreement is currently
   * available in Roman Urdu". The legal text is NEVER machine-translated.
   */
  legalLanguageNoticeRequired: boolean;
  /** The app locale the client asked for, echoed back for clarity. */
  requestedAppLocale: string;
}

export class UnsupportedTradeError extends Error {
  constructor(readonly mainTrade: string | null) {
    super('No approved trade agreement exists for this trade.');
    this.name = 'UnsupportedTradeError';
  }
}

@Injectable()
export class UstaadTemplateService {
  /**
   * Resolves all three documents for [mainSkillCategoryName] in the language
   * the app is currently showing.
   *
   * English and Urdu legal bodies are PENDING_TRANSLATION, so the approved
   * Roman Urdu document is returned for every app language, with
   * `legalLanguageNoticeRequired` telling the client to explain that.
   */
  getTemplatesForWorker(
    mainSkillCategoryName: string | null,
    requestedAppLocale: string,
  ): UstaadAgreementTemplateDto[] {
    const appLocale = parseAgreementLocale(requestedAppLocale) ?? 'ur_Latn';
    const trade = tradeCodeForCategoryName(mainSkillCategoryName);
    if (!trade) throw new UnsupportedTradeError(mainSkillCategoryName);

    return USTAAD_DOCUMENT_TYPES.map((documentType) =>
      this._resolve(documentType, trade, appLocale),
    );
  }

  /** Languages whose legal body is genuinely available today. */
  availableLegalLocales(): string[] {
    return [...new Set(activeSources().map((s) => s.locale))];
  }

  private _resolve(
    documentType: UstaadDocumentType,
    trade: TradeCode,
    appLocale: string,
  ): UstaadAgreementTemplateDto {
    const docTrade =
      documentType === 'TRADE_SPECIFIC_SERVICE_AGREEMENT' ? trade : null;

    // Prefer the app's language when its legal body is approved; otherwise
    // fall back to the approved Roman Urdu source.
    const requested = findSource(documentType, appLocale as never, docTrade);
    const useAppLocale = requested?.status === 'ACTIVE';
    const legalLocale = useAppLocale ? (appLocale as 'ur_Latn') : 'ur_Latn';

    const source = loadSourceText(documentType, legalLocale, docTrade);

    return {
      documentType,
      title: source.descriptor.title,
      version: source.descriptor.version,
      agreementLocale: legalLocale,
      sourceHash: source.sha256,
      applicableTrade: docTrade,
      contentText: source.text,
      legalLanguageNoticeRequired: legalLocale !== appLocale,
      requestedAppLocale: appLocale,
    };
  }
}
