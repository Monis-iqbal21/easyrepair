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
import { ChatModule } from '../chat/chat.module';
import { WorkersModule } from '../workers/workers.module';

@Module({
  imports: [
    PassportModule.register({ defaultStrategy: 'jwt' }),
    StorageModule,
    // Login/registration ensures the user's HandyGo Support conversation.
    // Acyclic: ChatModule does not import AuthModule.
    ChatModule,
    // Logout is authoritative session cleanup — forces a logging-out Worker
    // OFFLINE server-side. Acyclic: WorkersModule (and everything it
    // imports) does not import AuthModule.
    WorkersModule,
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
