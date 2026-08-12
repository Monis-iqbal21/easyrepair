import {
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { Reflector } from '@nestjs/core';
import { AccountStatus } from '@prisma/client';
import { Role } from '../enums/role.enum';
import { BYPASS_CLIENT_SUSPENSION_KEY } from '../decorators/bypass-client-suspension.decorator';

/**
 * The single guard behind nearly every authenticated endpoint app-wide —
 * enhancing it here (rather than adding a second guard everyone would have
 * to remember to also list) is what makes Client-suspension enforcement
 * centralized without touching any other controller.
 *
 * After the normal passport JWT check succeeds (still the sole source of
 * "is this token valid / is the account active/not-deleted" — see
 * JwtStrategy), a CLIENT whose AccountStatus is SUSPENDED is rejected with
 * 403 Forbidden on every endpoint EXCEPT ones explicitly marked
 * `@BypassClientSuspension()` (GET /auth/me, POST /auth/logout — see that
 * decorator's doc comment for the exact whitelist and why).
 *
 * Never applies to WORKER or ADMIN — Worker suspension is a completely
 * separate, pre-existing mechanism (WorkerStatus, enforced client-side by
 * the app's router) that this guard does not touch or reason about.
 */
@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  constructor(private readonly reflector: Reflector) {
    super();
  }

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const authenticated = (await super.canActivate(context)) as boolean;
    if (!authenticated) return false;

    const bypass = this.reflector.getAllAndOverride<boolean>(
      BYPASS_CLIENT_SUSPENSION_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (bypass) return true;

    const request = context.switchToHttp().getRequest();
    const user = request.user as
      | { role?: string; accountStatus?: AccountStatus }
      | undefined;

    if (
      user?.role === Role.CLIENT &&
      user.accountStatus === AccountStatus.SUSPENDED
    ) {
      throw new ForbiddenException(
        'This account has been suspended. Contact Support for more information.',
      );
    }

    return true;
  }
}
