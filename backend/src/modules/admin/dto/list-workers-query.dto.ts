import { IsEnum, IsInt, IsOptional, IsString, IsUUID, Max, Min } from 'class-validator';
import {
  WorkerStatus,
  WorkerOnboardingStatus,
  VerificationStatus,
} from '@prisma/client';

/**
 * GET /admin/workers query params. `page`/`pageSize` rely on the global
 * ValidationPipe's `enableImplicitConversion` to coerce the query strings —
 * no explicit @Type() needed.
 */
export class ListWorkersQueryDto {
  /** Matches against first/last name, phone, and CNIC number. */
  @IsOptional()
  @IsString()
  search?: string;

  @IsOptional()
  @IsEnum(WorkerStatus)
  status?: WorkerStatus;

  @IsOptional()
  @IsEnum(WorkerOnboardingStatus)
  onboardingStatus?: WorkerOnboardingStatus;

  @IsOptional()
  @IsEnum(VerificationStatus)
  verificationStatus?: VerificationStatus;

  /** Filter to workers whose (single) skill is this ServiceCategory. */
  @IsOptional()
  @IsUUID('4')
  categoryId?: string;

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
