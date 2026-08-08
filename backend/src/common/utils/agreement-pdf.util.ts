import { AgreementType } from '@prisma/client';
import PDFDocument from 'pdfkit';

/**
 * Human-readable label per document type. Exhaustive by construction, so
 * adding a document type to the Prisma enum fails the build here rather than
 * silently printing the wrong heading on a legal PDF.
 */
const AGREEMENT_TYPE_LABEL: Record<AgreementType, string> = {
  GENERAL_USTAAD: 'General Ustaad Agreement',
  TRADE_SPECIFIC: 'Trade-Specific Agreement',
  BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE:
    'Background Verification, EVS Consent aur Ustaad Privacy Notice',
  CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE:
    'Customer Terms, Booking Rules aur Privacy Notice',
};

export interface AgreementAcceptancePdfInput {
  acceptanceId: string;
  fullLegalName: string;
  /** Worker-only. Null/omitted for a Client acceptance (a Customer has no CNIC). */
  cnicNumber?: string | null;
  mobile: string;
  /**
   * Widened from the original two-value union when the third Ustaad document
   * (Background Verification / EVS / Privacy) was added. Kept as the Prisma
   * enum so a future document type cannot silently miss a rendering branch.
   */
  agreementType: AgreementType;
  agreementTitle: string;
  agreementVersion: string;
  /**
   * The PERSONALIZED accepted text — every blank already filled. Never the
   * raw source template.
   */
  agreementContent: string;
  /** SHA-256 of the approved SOURCE document. */
  agreementHash: string;
  acceptedAt: Date;
  ipAddress?: string | null;
  deviceInfo?: string | null;
  cnicFrontUrl?: string | null;
  cnicBackUrl?: string | null;
  liveSelfieUrl?: string | null;

  /** App locale this document was accepted in ('en' | 'ur' | 'ur_Latn'). */
  agreementLocale?: string | null;
  /** Trade schedule contained in this document, for TRADE_SPECIFIC only. */
  applicableTrade?: string | null;
  /** SHA-256 of the personalized accepted text. */
  acceptedDocumentHash?: string | null;
}

/**
 * Fonts available to the renderer.
 *
 * Helvetica has no Arabic-script glyphs and pdfkit performs no bidi shaping,
 * so Urdu-script (`ur`) rendering is NOT possible with the built-in fonts —
 * it would emit boxes. Rather than silently produce an unreadable legal
 * document, [assertRenderableLocale] refuses.
 *
 * To enable Urdu later: register an Urdu-capable font here (e.g. Noto Nastaliq
 * Urdu) plus a shaping step, and add 'ur' to RENDERABLE_LOCALES. No font file
 * is bundled by this change.
 */
const RENDERABLE_LOCALES = new Set(['en', 'ur_Latn']);

export class UnrenderablePdfLocaleError extends Error {
  constructor(readonly locale: string) {
    super(
      `Cannot render a legal PDF in locale "${locale}": no Urdu-capable font ` +
        `is configured, and Helvetica would emit unreadable glyphs. Configure ` +
        `an approved Urdu font before activating this locale.`,
    );
    this.name = 'UnrenderablePdfLocaleError';
  }
}

export function assertRenderableLocale(locale: string | null | undefined): void {
  const value = locale ?? 'ur_Latn';
  if (!RENDERABLE_LOCALES.has(value)) {
    throw new UnrenderablePdfLocaleError(value);
  }
}

/** Renders a signed-agreement-style PDF as a Buffer. Pure function, no I/O. */
export function generateAgreementAcceptancePdf(
  input: AgreementAcceptancePdfInput,
): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    // Refuse before writing a byte: an unreadable legal PDF is worse than a
    // blocked submission. Rejecting (rather than throwing synchronously) keeps
    // the failure catchable by both `await` and `.catch()`.
    try {
      assertRenderableLocale(input.agreementLocale);
    } catch (err) {
      reject(err as Error);
      return;
    }

    const doc = new PDFDocument({ size: 'A4', margin: 50 });
    const chunks: Buffer[] = [];
    doc.on('data', (chunk) => chunks.push(chunk));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    doc
      .fontSize(18)
      .font('Helvetica-Bold')
      .text('HandyGo — Agreement Acceptance Record', {
        align: 'center',
      });
    doc.moveDown(1.5);

    doc.fontSize(11).font('Helvetica-Bold').text(input.agreementTitle);
    doc
      .font('Helvetica')
      .fontSize(10)
      .fillColor('#555555')
      .text(
        `Type: ${AGREEMENT_TYPE_LABEL[input.agreementType]}  |  Version: ${input.agreementVersion}`,
      );
    doc.fillColor('#000000');
    doc.moveDown(1);

    const acceptanceLines = [
      `Electronically Accepted by: ${input.fullLegalName}`,
      ...(input.cnicNumber ? [`CNIC: ${input.cnicNumber}`] : []),
      `Mobile: ${input.mobile}`,
      `Accepted on: ${input.acceptedAt.toISOString()}`,
      `Agreement Version: ${input.agreementVersion}`,
      `Acceptance ID: ${input.acceptanceId}`,
      `Method: Authenticated HandyGo account and explicit checkbox consent.`,
    ];

    doc.font('Helvetica-Bold').fontSize(11).text('Acceptance Details');
    doc.font('Helvetica').fontSize(10);
    for (const line of acceptanceLines) {
      doc.text(line);
    }
    doc.moveDown(1);

    doc
      .font('Helvetica-Oblique')
      .fontSize(9)
      .fillColor('#555555')
      .text(
        'This agreement was electronically accepted through the HandyGo application.',
      );
    doc.fillColor('#000000');
    doc.moveDown(1);

    doc.font('Helvetica-Bold').fontSize(11).text('Verification Metadata');
    doc.font('Helvetica').fontSize(9).fillColor('#555555');
    doc.text(`Source Hash (SHA-256): ${input.agreementHash}`);
    if (input.acceptedDocumentHash)
      doc.text(`Accepted Snapshot Hash (SHA-256): ${input.acceptedDocumentHash}`);
    if (input.agreementLocale)
      doc.text(`Agreement Language: ${input.agreementLocale}`);
    if (input.applicableTrade)
      doc.text(`Applicable Trade: ${input.applicableTrade}`);
    if (input.ipAddress) doc.text(`IP Address: ${input.ipAddress}`);
    if (input.deviceInfo) doc.text(`Device / User Agent: ${input.deviceInfo}`);
    if (input.cnicFrontUrl)
      doc.text(`CNIC Front Reference: ${input.cnicFrontUrl}`);
    if (input.cnicBackUrl)
      doc.text(`CNIC Back Reference: ${input.cnicBackUrl}`);
    if (input.liveSelfieUrl)
      doc.text(`Live Selfie Reference: ${input.liveSelfieUrl}`);
    doc.fillColor('#000000');
    doc.moveDown(1.5);

    doc.font('Helvetica-Bold').fontSize(11).text('Full Agreement Text');
    doc.moveDown(0.5);
    doc.font('Helvetica').fontSize(9).text(input.agreementContent, {
      align: 'left',
      lineGap: 2,
    });

    doc.end();
  });
}
