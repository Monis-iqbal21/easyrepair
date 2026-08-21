import { NestExpressApplication } from '@nestjs/platform-express';

export interface PostListenService {
  start(): void;
}

/** Bind HTTP before starting any optional Redis-backed background service. */
export async function bindHttpThenStartBackgroundServices(
  app: NestExpressApplication,
  port: number,
  services: PostListenService[],
): Promise<void> {
  await app.listen(port, '0.0.0.0');
  for (const service of services) service.start();
}
