import { IsString, IsNotEmpty, MaxLength } from 'class-validator';

export class EditMessageDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(4000)
  text!: string;
}
