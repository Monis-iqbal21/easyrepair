import { Controller, Get, Module } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import request from 'supertest';
import { bindHttpThenStartBackgroundServices } from './http-startup';

jest.setTimeout(30_000);

@Controller('health')
class TestHealthController {
  @Get()
  health() {
    return { ok: true };
  }
}

@Module({ controllers: [TestHealthController] })
class TestAppModule {}

describe('HTTP startup isolation', () => {
  it('serves health when a post-listen Redis scheduler never settles', async () => {
    const app = await NestFactory.create<NestExpressApplication>(
      TestAppModule,
      {
        logger: false,
      },
    );
    const neverSettles = new Promise(() => undefined);
    const scheduler = {
      start: jest.fn(() => {
        void neverSettles;
      }),
    };

    try {
      await bindHttpThenStartBackgroundServices(app, 0, [scheduler]);

      await request(app.getHttpServer())
        .get('/health')
        .expect(200, { ok: true });
      expect(scheduler.start).toHaveBeenCalledTimes(1);
    } finally {
      await app.close();
    }
  });
});
