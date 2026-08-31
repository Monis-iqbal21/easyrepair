import {
  CallHandler,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { finalize } from 'rxjs/operators';
import { AdminReadonlyRequest } from './admin-readonly.guard';

/** Logs credential identity and route metadata, never headers, tokens, or data. */
@Injectable()
export class AdminReadonlyAuditInterceptor implements NestInterceptor {
  private readonly logger = new Logger(AdminReadonlyAuditInterceptor.name);

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const request = context.switchToHttp().getRequest<AdminReadonlyRequest>();
    const startedAt = Date.now();
    return next.handle().pipe(
      finalize(() => {
        const clientId = this.clean(
          request.adminReadonlyCredential?.clientId ?? 'unknown',
        );
        this.logger.log(
          `admin_readonly request client=${clientId} method=${request.method} path=${this.clean(request.path)} ip=${this.clean(request.ip)} durationMs=${Date.now() - startedAt}`,
        );
      }),
    );
  }

  private clean(value: string | undefined): string {
    return (value ?? '-').replace(/[^\x20-\x7E]/g, '').slice(0, 160);
  }
}
