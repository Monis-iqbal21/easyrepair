import PDFDocument from 'pdfkit';

export interface AgreementAcceptancePdfInput {
  acceptanceId: string;
  fullLegalName: string;
  cnicNumber: string;
  mobile: string;
  agreementType: 'GENERAL_USTAAD' | 'TRADE_SPECIFIC';
  agreementTitle: string;
  agreementVersion: string;
  agreementContent: string;
  agreementHash: string;
  acceptedAt: Date;
  ipAddress?: string | null;
  deviceInfo?: string | null;
  cnicFrontUrl?: string | null;
  cnicBackUrl?: string | null;
  liveSelfieUrl?: string | null;
}

/** Renders a signed-agreement-style PDF as a Buffer. Pure function, no I/O. */
export function generateAgreementAcceptancePdf(
  input: AgreementAcceptancePdfInput,
): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ size: 'A4', margin: 50 });
    const chunks: Buffer[] = [];
    doc.on('data', (chunk) => chunks.push(chunk));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    doc
      .fontSize(18)
      .font('Helvetica-Bold')
      .text('HandyGo — Ustaad Agreement Acceptance Record', { align: 'center' });
    doc.moveDown(1.5);

    doc.fontSize(11).font('Helvetica-Bold').text(input.agreementTitle);
    doc
      .font('Helvetica')
      .fontSize(10)
      .fillColor('#555555')
      .text(
        `Type: ${input.agreementType === 'GENERAL_USTAAD' ? 'General Ustaad Agreement' : 'Trade-Specific Agreement'}  |  Version: ${input.agreementVersion}`,
      );
    doc.fillColor('#000000');
    doc.moveDown(1);

    const acceptanceLines = [
      `Electronically Accepted by: ${input.fullLegalName}`,
      `CNIC: ${input.cnicNumber}`,
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
    doc.text(`Content Hash (SHA-256): ${input.agreementHash}`);
    if (input.ipAddress) doc.text(`IP Address: ${input.ipAddress}`);
    if (input.deviceInfo) doc.text(`Device / User Agent: ${input.deviceInfo}`);
    if (input.cnicFrontUrl) doc.text(`CNIC Front Reference: ${input.cnicFrontUrl}`);
    if (input.cnicBackUrl) doc.text(`CNIC Back Reference: ${input.cnicBackUrl}`);
    if (input.liveSelfieUrl) doc.text(`Live Selfie Reference: ${input.liveSelfieUrl}`);
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
