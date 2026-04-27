import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { BullModule } from '@nestjs/bull';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import configuration from './config/configuration';
import { validate } from './config/config.validation';
import { PrismaModule } from './prisma/prisma.module';
import { RedisModule } from './redis/redis.module';
import { FirebaseModule } from './firebase/firebase.module';
import { AuthModule } from './modules/auth/auth.module';
import { BookingsModule } from './modules/bookings/bookings.module';
import { CategoriesModule } from './modules/categories/categories.module';
import { WorkersModule } from './modules/workers/workers.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { ChatModule } from './modules/chat/chat.module';
import { BidsModule } from './modules/bids/bids.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
      validate,
      envFilePath: '.env',
    }),
    BullModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        url: config.getOrThrow<string>('redis.url'),
      }),
    }),
    PrismaModule,
    RedisModule,
    FirebaseModule,
    AuthModule,
    BookingsModule,
    CategoriesModule,
    WorkersModule,
    NotificationsModule,
    ChatModule,
    BidsModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
