import { ConfigService } from '@nestjs/config';
export declare class StorageService {
    private readonly config;
    private readonly logger;
    private readonly s3;
    private readonly bucket;
    private readonly region;
    constructor(config: ConfigService);
    upload(buffer: Buffer, originalName: string, mimeType: string, folder?: string): Promise<string>;
    deleteByUrl(url: string): Promise<void>;
}
