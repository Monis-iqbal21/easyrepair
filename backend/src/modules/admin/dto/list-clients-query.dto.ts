import { IsEnum, IsIn, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';
import { AccountStatus } from '@prisma/client';

export type PhoneVerifiedFilter = 'VERIFIED' | 'NOT_VERIFIED';
export type ClientSortOption = 'NEWEST' | 'OLDEST' | 'NAME';

/**
 * GET /admin/clients query params. `page`/`pageSize` rely on the global
 * ValidationPipe's `enableImplicitConversion` — no explicit @Type().
 */
export class ListClientsQueryDto {
  /** Matches first/last name or phone (normalized the same way auth does). */
  @IsOptional()
  @IsString()
  search?: string;

  @IsOptional()
  @IsEnum(AccountStatus)
  accountStatus?: AccountStatus;

  @IsOptional()
  @IsIn(['VERIFIED', 'NOT_VERIFIED'])
  phoneVerified?: PhoneVerifiedFilter;

  @IsOptional()
  @IsIn(['NEWEST', 'OLDEST', 'NAME'])
  sort: ClientSortOption = 'NEWEST';

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
