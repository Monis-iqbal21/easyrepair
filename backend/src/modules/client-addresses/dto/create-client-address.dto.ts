import { Transform } from 'class-transformer';
import {
  IsLatitude,
  IsLongitude,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

const trimText = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

export class CreateClientAddressDto {
  @Transform(trimText)
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  label: string;

  @Transform(trimText)
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  addressLine: string;

  @IsOptional()
  @Transform(trimText)
  @IsString()
  @MaxLength(100)
  city?: string;

  @IsLatitude()
  latitude: number;

  @IsLongitude()
  longitude: number;
}
