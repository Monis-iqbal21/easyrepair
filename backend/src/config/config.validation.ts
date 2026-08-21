import { plainToInstance } from 'class-transformer';
import {
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  validateSync,
} from 'class-validator';

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

  @IsString()
  @IsOptional()
  SMS_API_URL: string;

  @IsString()
  @IsOptional()
  SMS_SENDER: string;

  @IsString()
  @IsOptional()
  R2_BUCKET: string;

  @IsString()
  @IsOptional()
  R2_ACCOUNT_ID: string;

  @IsString()
  @IsOptional()
  R2_ACCESS_KEY_ID: string;

  @IsString()
  @IsOptional()
  R2_SECRET_ACCESS_KEY: string;

  @IsString()
  @IsOptional()
  R2_PUBLIC_URL: string;

  @IsString()
  @IsOptional()
  R2_ENDPOINT: string;

  @IsNumber()
  @IsOptional()
  PLATFORM_FEE_PERCENT: number = 10;

  @IsString()
  @IsOptional()
  BUSINESS_TIMEZONE: string = 'Asia/Karachi';

  @IsString()
  @IsOptional()
  USE_POSTGIS: string = 'false';

  @IsNumber()
  @IsOptional()
  MATCH_FANOUT_CHUNK_SIZE: number = 50;

  @IsNumber()
  @IsOptional()
  MATCH_NEARBY_FETCH_LIMIT: number = 200;

  @IsString()
  @IsOptional()
  OTP_ADMIN_ENCRYPTION_KEY: string;
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
