declare enum StorageProvider {
    S3 = "s3"
}
declare class EnvironmentVariables {
    PORT: number;
    DATABASE_URL: string;
    REDIS_URL: string;
    JWT_SECRET: string;
    JWT_ACCESS_EXPIRES: string;
    JWT_REFRESH_EXPIRES: string;
    FIREBASE_PROJECT_ID: string;
    FIREBASE_PRIVATE_KEY: string;
    FIREBASE_CLIENT_EMAIL: string;
    SMS_API_KEY: string;
    STORAGE_PROVIDER: StorageProvider;
    AWS_BUCKET: string;
    AWS_REGION: string;
    AWS_ACCESS_KEY: string;
    AWS_SECRET_KEY: string;
    PLATFORM_FEE_PERCENT: number;
    USE_POSTGIS: string;
}
export declare function validate(config: Record<string, unknown>): EnvironmentVariables;
export {};
