import { Type } from 'class-transformer';
import { IsInt, Min } from 'class-validator';

export class ConfirmCashPaymentDto {
  @Type(() => Number)
  @IsInt()
  @Min(0)
  receivedCashTotal: number;
}

export interface ClientCashPaymentConfirmationDto {
  settlementId: string;
  bookingId: string;
  receivedCashTotal: number;
  expectedTotal: number;
  shortfall: number;
  recordedAt: Date;
  confirmationStatus: 'CONFIRMED';
  isCurrent: true;
}
