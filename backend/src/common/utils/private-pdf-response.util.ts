import { Response } from 'express';

/** A private PDF resolved by an authenticated, ownership-checked endpoint. */
export interface PrivatePdfPayload {
  body: Buffer;
  contentType: string;
  /** Must carry no CNIC, phone or legal name — a public id only. */
  fileName: string;
}

/**
 * Writes a sensitive PDF to the response.
 *
 * Kept in one place so every download endpoint sets the same headers: no
 * caching anywhere (these are legal identity documents, and a shared proxy or
 * disk cache holding one is a data leak), an explicit content length, and a
 * filename that is safe to appear in a downloads folder.
 */
export function sendPrivatePdf(res: Response, pdf: PrivatePdfPayload): void {
  res.setHeader('Content-Type', pdf.contentType);
  res.setHeader('Content-Length', pdf.body.length);
  res.setHeader(
    'Content-Disposition',
    `attachment; filename="${safeFileName(pdf.fileName)}"`,
  );
  res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, private');
  res.setHeader('Pragma', 'no-cache');
  res.setHeader('Expires', '0');
  res.end(pdf.body);
}

/**
 * Strips anything that could break out of the quoted filename or escape a
 * directory. Defensive only — callers already build the name from a generated
 * acceptance id.
 *
 * Traversal segments are collapsed rather than just having their separators
 * replaced: turning `../../x` into `-..-x` removes the slashes but leaves a
 * name a client could still mishandle when saving it.
 */
export function safeFileName(name: string): string {
  const cleaned = name
    .replace(/[^A-Za-z0-9._-]/g, '-')
    // Any run of dots collapses to one, so `..` can never survive.
    .replace(/\.{2,}/g, '.')
    .replace(/^[.-]+/, '');
  return cleaned || 'document.pdf';
}
