import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  S3Client,
  PutObjectCommand,
  DeleteObjectCommand,
} from '@aws-sdk/client-s3';
import { randomUUID } from 'crypto';
import { extname } from 'path';

@Injectable()
export class StorageService {
  private readonly logger = new Logger(StorageService.name);
  private readonly s3: S3Client;
  private readonly bucket: string;
  private readonly region: string;

  constructor(private readonly config: ConfigService) {
    this.bucket = this.config.get<string>('storage.bucket') ?? '';
    this.region = this.config.get<string>('storage.region') ?? 'us-east-1';

    this.s3 = new S3Client({
      region: this.region,
      credentials: {
        accessKeyId: this.config.get<string>('storage.accessKey') ?? '',
        secretAccessKey: this.config.get<string>('storage.secretKey') ?? '',
      },
    });
  }

  /**
   * Upload a file buffer to S3 under the given folder prefix.
   * Returns the public URL of the uploaded object.
   */
  async upload(
    buffer: Buffer,
    originalName: string,
    mimeType: string,
    folder = 'booking-attachments',
  ): Promise<string> {
    const ext = extname(originalName) || '';
    const key = `${folder}/${randomUUID()}${ext}`;

    await this.s3.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: buffer,
        ContentType: mimeType,
      }),
    );

    const url = `https://${this.bucket}.s3.${this.region}.amazonaws.com/${key}`;
    this.logger.log(`[StorageService] uploaded: ${url}`);
    return url;
  }

  /**
   * Delete an object from S3 by its full URL.
   * Silently ignores failures so a bad URL never blocks the caller.
   */
  async deleteByUrl(url: string): Promise<void> {
    try {
      const prefix = `https://${this.bucket}.s3.${this.region}.amazonaws.com/`;
      if (!url.startsWith(prefix)) return;
      const key = url.slice(prefix.length);
      await this.s3.send(
        new DeleteObjectCommand({ Bucket: this.bucket, Key: key }),
      );
      this.logger.log(`[StorageService] deleted: ${key}`);
    } catch (err) {
      this.logger.warn(`[StorageService] failed to delete ${url}: ${err}`);
    }
  }
}
