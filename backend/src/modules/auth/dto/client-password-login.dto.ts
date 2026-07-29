import { IsString, Matches } from 'class-validator';

export class ClientPasswordLoginDto {
  @IsString()
  @Matches(/^(\+92|0092|92|0)?[3][0-9]{9}$/, {
    message: 'phone must be a valid Pakistani mobile number',
  })
  phone: string;

  @IsString()
  password: string;
}
