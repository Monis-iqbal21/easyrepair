import { IsEnum, IsIn, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';
import { AuthOtpPurpose } from '@prisma/client';

export type OtpStatusFilter = 'ACTIVE' | 'CONSUMED' | 'EXPIRED';

/**
 * GET /admin/otp query params. `sinceMinutes`/`page`/`pageSize` rely on the
 * global ValidationPipe's `enableImplicitConversion` — no explicit @Type().
 */
export class ListOtpQueryDto {
  /** Matches phone (normalized the same way auth does). */
  @IsOptional()
  @IsString()
  search?: string;

  @IsOptional()
  @IsEnum(AuthOtpPurpose)
  purpose?: AuthOtpPurpose;

  @IsOptional()
  @IsIn(['ACTIVE', 'CONSUMED', 'EXPIRED'])
  status?: OtpStatusFilter;

  /** Minutes of history to include. Default 60 (last hour); capped at 24h. */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(1440)
  sinceMinutes: number = 60;

  @IsOptional()
  @IsInt()
  @Min(1)
  page: number = 1;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize: number = 20;
}
