import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module';
import { GlobalExceptionFilter } from './common/filters/http-exception.filter';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';
import { AdminOperationsScheduler } from './modules/admin/admin-operations.processor';
import { BookingExpiryScheduler } from './modules/bookings/booking-expiry.scheduler';
import { bindHttpThenStartBackgroundServices } from './common/startup/http-startup';

async function bootstrap() {
  console.log('[startup] creating Nest application');
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  console.log('[startup] Nest application created; configuring HTTP');

  const configService = app.get(ConfigService);
  const port = configService.get<number>('port') ?? 3000;

  // Every deployment sits behind a load balancer, so the socket address
  // Express sees is the proxy's — the SAME value for every user on the
  // platform. Anything that buckets by `req.ip` (the OTP per-IP abuse cap)
  // would then be counting all users into one bucket and locking out real
  // people. Trusting the proxy makes `req.ip` the client's actual address
  // from X-Forwarded-For.
  //
  // TRUST_PROXY_HOPS is the number of proxies in front of this app (1 for a
  // single load balancer). It is a count, never `true`: blindly trusting the
  // whole chain lets a client spoof its own X-Forwarded-For and slip any
  // per-IP limit.
  const trustProxyHops = Number(process.env.TRUST_PROXY_HOPS ?? 1);
  app.set('trust proxy', Number.isFinite(trustProxyHops) ? trustProxyHops : 1);

  app.setGlobalPrefix('api/v1');

  app.enableCors({
    origin: true,
    credentials: true,
  });

  app.useGlobalFilters(new GlobalExceptionFilter());
  app.useGlobalInterceptors(new TransformInterceptor());

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: {
        enableImplicitConversion: true,
      },
    }),
  );

  console.log(`[startup] binding HTTP server on configured port ${port}`);
  await bindHttpThenStartBackgroundServices(app, port, [
    app.get(AdminOperationsScheduler),
    app.get(BookingExpiryScheduler),
  ]);
  console.log(`Application running on port ${port}`);
  console.log(
    '[startup] nightly commission + booking expiry sweep schedulers start dispatched',
  );
}

bootstrap().catch((err) => {
  console.error('Error during app bootstrap:', err);
});
