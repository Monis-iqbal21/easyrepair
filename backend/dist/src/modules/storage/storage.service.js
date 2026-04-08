"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var StorageService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.StorageService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const client_s3_1 = require("@aws-sdk/client-s3");
const crypto_1 = require("crypto");
const path_1 = require("path");
let StorageService = StorageService_1 = class StorageService {
    constructor(config) {
        this.config = config;
        this.logger = new common_1.Logger(StorageService_1.name);
        this.bucket = this.config.get('storage.bucket') ?? '';
        this.region = this.config.get('storage.region') ?? 'us-east-1';
        this.s3 = new client_s3_1.S3Client({
            region: this.region,
            credentials: {
                accessKeyId: this.config.get('storage.accessKey') ?? '',
                secretAccessKey: this.config.get('storage.secretKey') ?? '',
            },
        });
    }
    async upload(buffer, originalName, mimeType, folder = 'booking-attachments') {
        const ext = (0, path_1.extname)(originalName) || '';
        const key = `${folder}/${(0, crypto_1.randomUUID)()}${ext}`;
        await this.s3.send(new client_s3_1.PutObjectCommand({
            Bucket: this.bucket,
            Key: key,
            Body: buffer,
            ContentType: mimeType,
        }));
        const url = `https://${this.bucket}.s3.${this.region}.amazonaws.com/${key}`;
        this.logger.log(`[StorageService] uploaded: ${url}`);
        return url;
    }
    async deleteByUrl(url) {
        try {
            const prefix = `https://${this.bucket}.s3.${this.region}.amazonaws.com/`;
            if (!url.startsWith(prefix))
                return;
            const key = url.slice(prefix.length);
            await this.s3.send(new client_s3_1.DeleteObjectCommand({ Bucket: this.bucket, Key: key }));
            this.logger.log(`[StorageService] deleted: ${key}`);
        }
        catch (err) {
            this.logger.warn(`[StorageService] failed to delete ${url}: ${err}`);
        }
    }
};
exports.StorageService = StorageService;
exports.StorageService = StorageService = StorageService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [config_1.ConfigService])
], StorageService);
//# sourceMappingURL=storage.service.js.map