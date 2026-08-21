import { Response } from 'express';

export interface PrivateFilePayload {
  body: Buffer;
  contentType: string;
  fileName: string;
}

/** Send sensitive bytes without allowing browsers or intermediary caches to retain them. */
export function sendPrivateFile(res: Response, file: PrivateFilePayload): void {
  const safeFileName = file.fileName.replace(/[^a-zA-Z0-9._-]/g, '_');
  res.setHeader('Content-Type', file.contentType);
  res.setHeader('Content-Length', file.body.length);
  res.setHeader(
    'Content-Disposition',
    `inline; filename="${safeFileName || 'document'}"`,
  );
  res.setHeader('Cache-Control', 'private, no-store, max-age=0');
  res.setHeader('Pragma', 'no-cache');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.send(file.body);
}
