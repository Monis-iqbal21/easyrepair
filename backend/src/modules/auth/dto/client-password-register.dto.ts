import { IsString, Matches, MinLength } from 'class-validator';

export class ClientPasswordRegisterDto {
  @IsString()
  @MinLength(1, { message: 'fullName is required' })
  fullName: string;

  @IsString()
  @Matches(/^(\+92|0092|92|0)?[3][0-9]{9}$/, {
    message: 'phone must be a valid Pakistani mobile number',
  })
  phone: string;

  @IsString()
  @MinLength(8, { message: 'password must be at least 8 characters' })
  password: string;
}
