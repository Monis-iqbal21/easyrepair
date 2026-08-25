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

export class UpdateClientAddressDto {
  @IsOptional()
  @Transform(trimText)
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  label?: string;

  @IsOptional()
  @Transform(trimText)
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  addressLine?: string;

  @IsOptional()
  @Transform(trimText)
  @IsString()
  @MaxLength(100)
  city?: string;

  @IsOptional()
  @IsLatitude()
  latitude?: number;

  @IsOptional()
  @IsLongitude()
  longitude?: number;
}
