import {
  IsString,
  IsNotEmpty,
  MinLength,
  IsIn,
  Matches,
} from 'class-validator';

export class RegisterDto {
  @IsString()
  @IsNotEmpty()
  @Matches(/^(\+92|0092|92|0)?[3][0-9]{9}$/, {
    message: 'phone must be a valid Pakistani mobile number',
  })
  phone: string;

  @IsString()
  @MinLength(8, { message: 'password must be at least 8 characters' })
  password: string;

  @IsString()
  @IsNotEmpty()
  firstName: string;

  @IsString()
  @IsNotEmpty()
  lastName: string;

  @IsIn(['CLIENT', 'WORKER'], {
    message: 'role must be CLIENT or WORKER',
  })
  role: 'CLIENT' | 'WORKER';
}
