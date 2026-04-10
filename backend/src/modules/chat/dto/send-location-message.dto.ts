import { IsNumber } from 'class-validator';

export class SendLocationMessageDto {
  @IsNumber()
  latitude!: number;

  @IsNumber()
  longitude!: number;
}
