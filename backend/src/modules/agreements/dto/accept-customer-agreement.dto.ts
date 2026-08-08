import { IsBoolean, IsOptional, IsString, MaxLength } from 'class-validator';

/**
 * Body of POST /customer/agreements/:agreementKey/accept.
 *
 * Deliberately minimal: only genuine Client-origin evidence. Identity, the
 * agreement version/hash, timestamps and the acceptance id are all resolved
 * server-side from the authenticated account and the registered agreement
 * source — a value sent here for any of those would simply be ignored.
 */
export class AcceptCustomerAgreementDto {
  @IsBoolean()
  checkboxAccepted!: boolean;

  /** Optional client-supplied device/session label, purely informational. */
  @IsOptional()
  @IsString()
  @MaxLength(200)
  deviceDescriptor?: string;
}
