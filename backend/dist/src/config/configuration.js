"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = () => ({
    port: parseInt(process.env.PORT || '3000', 10),
    database: {
        url: process.env.DATABASE_URL,
    },
    redis: {
        url: process.env.REDIS_URL,
    },
    jwt: {
        secret: process.env.JWT_SECRET,
        accessExpires: process.env.JWT_ACCESS_EXPIRES || '15m',
        refreshExpires: process.env.JWT_REFRESH_EXPIRES || '30d',
    },
    firebase: {
        projectId: process.env.FIREBASE_PROJECT_ID,
        privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    },
    sms: {
        apiKey: process.env.SMS_API_KEY,
    },
    storage: {
        provider: process.env.STORAGE_PROVIDER || 's3',
        bucket: process.env.AWS_BUCKET,
        region: process.env.AWS_REGION,
        accessKey: process.env.AWS_ACCESS_KEY,
        secretKey: process.env.AWS_SECRET_KEY,
    },
    platform: {
        feePercent: parseInt(process.env.PLATFORM_FEE_PERCENT || '10', 10),
    },
    usePostgis: process.env.USE_POSTGIS === 'true',
});
//# sourceMappingURL=configuration.js.map