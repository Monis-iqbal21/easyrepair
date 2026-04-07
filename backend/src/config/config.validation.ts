import { plainToInstance } from 'class-transformer';
import {
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  validateSync,
} from 'class-validator';

enum StorageProvider {
  S3 = 's3',
}

class EnvironmentVariables {
  @IsNumber()
  @IsOptional()
  PORT: number = 3000;

  @IsString()
  @IsNotEmpty()
  DATABASE_URL: string;

  @IsString()
  @IsNotEmpty()
  REDIS_URL: string;

  @IsString()
  @IsNotEmpty()
  JWT_SECRET: string;

  @IsString()
  @IsOptional()
  JWT_ACCESS_EXPIRES: string = '15m';

  @IsString()
  @IsOptional()
  JWT_REFRESH_EXPIRES: string = '30d';

  @IsString()
  @IsOptional()
  FIREBASE_PROJECT_ID: string;

  @IsString()
  @IsOptional()
  FIREBASE_PRIVATE_KEY: string;

  @IsString()
  @IsOptional()
  FIREBASE_CLIENT_EMAIL: string;

  @IsString()
  @IsOptional()
  SMS_API_KEY: string;

  @IsEnum(StorageProvider)
  @IsOptional()
  STORAGE_PROVIDER: StorageProvider = StorageProvider.S3;

  @IsString()
  @IsOptional()
  AWS_BUCKET: string;

  @IsString()
  @IsOptional()
  AWS_REGION: string;

  @IsString()
  @IsOptional()
  AWS_ACCESS_KEY: string;

  @IsString()
  @IsOptional()
  AWS_SECRET_KEY: string;

  @IsNumber()
  @IsOptional()
  PLATFORM_FEE_PERCENT: number = 10;

  @IsString()
  @IsOptional()
  USE_POSTGIS: string = 'false';
}

export function validate(config: Record<string, unknown>) {
  const validatedConfig = plainToInstance(EnvironmentVariables, config, {
    enableImplicitConversion: true,
  });
  const errors = validateSync(validatedConfig, {
    skipMissingProperties: false,
  });

  if (errors.length > 0) {
    throw new Error(errors.toString());
  }
  return validatedConfig;
}
