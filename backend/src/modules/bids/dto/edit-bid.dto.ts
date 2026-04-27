import { IsNumber, IsOptional, IsString, MaxLength, Min } from 'class-validator';

export class EditBidDto {
  @IsNumber()
  @Min(0.01, { message: 'amount must be greater than 0' })
  amount: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  message?: string;
}
