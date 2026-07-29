import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigService } from '@nestjs/config';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { AuthRepository } from './auth.repository';
import { JwtStrategy } from './strategies/jwt.strategy';
import { SmsOtpService } from './sms-otp.service';
import { StorageModule } from '../storage/storage.module';

@Module({
  imports: [
    PassportModule.register({ defaultStrategy: 'jwt' }),
    StorageModule,
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>('jwt.secret'),
        signOptions: {
          expiresIn: config.getOrThrow<string>('jwt.accessExpires') as
            | `${number}${'s' | 'm' | 'h' | 'd' | 'w' | 'y'}`
            | number,
        },
      }),
    }),
  ],
  providers: [AuthService, AuthRepository, JwtStrategy, SmsOtpService],
  controllers: [AuthController],
  exports: [JwtStrategy, PassportModule],
})
export class AuthModule {}
