import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

/**
 * PATCH /admin/clients/:clientProfileId/profile — admin-editable operational
 * fields only. Deliberately has NO `phone` property: phone is the account's
 * authentication identity, so it is structurally impossible to change it
 * through this DTO (the global ValidationPipe's forbidNonWhitelisted rejects
 * any attempt to send one). Account status is managed separately via the
 * existing PATCH /admin/users/:userId/account-status endpoint.
 */
export class UpdateClientProfileDto {
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  firstName?: string;

  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  lastName?: string;
}
