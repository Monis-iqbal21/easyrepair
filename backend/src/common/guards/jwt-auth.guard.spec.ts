import { ExecutionContext, ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { AccountStatus } from '@prisma/client';
import { JwtAuthGuard } from './jwt-auth.guard';
import { Role } from '../enums/role.enum';

/**
 * JwtAuthGuard is the single guard behind nearly every authenticated
 * endpoint app-wide, which is what makes enhancing it (rather than adding a
 * second guard everyone has to remember to also apply) a real central
 * enforcement point for Client AccountStatus.SUSPENDED.
 *
 * `super.canActivate` (the real passport JWT check) is stubbed at the
 * parent-prototype level so these tests exercise only the suspension logic
 * this guard adds on top — the parent's own behavior (token validity,
 * isActive/deletedAt) is already covered by jwt.strategy.spec.ts.
 */
describe('JwtAuthGuard — Client suspension enforcement', () => {
  let reflector: any;
  let guard: JwtAuthGuard;
  let parentCanActivateSpy: jest.SpyInstance;

  function mockContext(user: unknown): ExecutionContext {
    return {
      switchToHttp: () => ({ getRequest: () => ({ user }) }),
      getHandler: () => ({}),
      getClass: () => ({}),
    } as unknown as ExecutionContext;
  }

  beforeEach(() => {
    reflector = { getAllAndOverride: jest.fn().mockReturnValue(false) };
    guard = new JwtAuthGuard(reflector);
    // The actual parent class JwtAuthGuard extends (AuthGuard('jwt')) —
    // spying here, not on a fresh AuthGuard('jwt') call, since the mixin
    // factory returns a new class every invocation.
    const parentProto = Object.getPrototypeOf(JwtAuthGuard.prototype);
    parentCanActivateSpy = jest
      .spyOn(parentProto, 'canActivate')
      .mockResolvedValue(true);
  });

  afterEach(() => {
    parentCanActivateSpy.mockRestore();
  });

  it('allows an ACTIVE Client through to a normal endpoint', async () => {
    const ctx = mockContext({
      id: 'c1',
      role: Role.CLIENT,
      accountStatus: AccountStatus.ACTIVE,
    });
    await expect(guard.canActivate(ctx)).resolves.toBe(true);
  });

  it('rejects a SUSPENDED Client on a normal endpoint with 403 Forbidden', async () => {
    const ctx = mockContext({
      id: 'c1',
      role: Role.CLIENT,
      accountStatus: AccountStatus.SUSPENDED,
    });
    await expect(guard.canActivate(ctx)).rejects.toThrow(ForbiddenException);
  });

  it('allows a SUSPENDED Client through an endpoint marked @BypassClientSuspension (e.g. GET /auth/me, POST /auth/logout)', async () => {
    reflector.getAllAndOverride.mockReturnValue(true);
    const ctx = mockContext({
      id: 'c1',
      role: Role.CLIENT,
      accountStatus: AccountStatus.SUSPENDED,
    });
    await expect(guard.canActivate(ctx)).resolves.toBe(true);
  });

  it('never rejects a WORKER, even one carrying accountStatus SUSPENDED — Worker suspension is a separate mechanism (WorkerStatus)', async () => {
    const ctx = mockContext({
      id: 'w1',
      role: Role.WORKER,
      accountStatus: AccountStatus.SUSPENDED,
    });
    await expect(guard.canActivate(ctx)).resolves.toBe(true);
  });

  it('never rejects an ADMIN', async () => {
    const ctx = mockContext({
      id: 'a1',
      role: Role.ADMIN,
      accountStatus: AccountStatus.SUSPENDED,
    });
    await expect(guard.canActivate(ctx)).resolves.toBe(true);
  });

  it('a failed underlying passport authentication propagates and is never reached by the suspension check', async () => {
    parentCanActivateSpy.mockRejectedValue(new UnauthorizedException());
    const ctx = mockContext(undefined);
    await expect(guard.canActivate(ctx)).rejects.toThrow(UnauthorizedException);
  });

  it('does not proceed to the suspension check when the parent guard resolves false', async () => {
    parentCanActivateSpy.mockResolvedValue(false);
    const ctx = mockContext({
      id: 'c1',
      role: Role.CLIENT,
      accountStatus: AccountStatus.SUSPENDED,
    });
    await expect(guard.canActivate(ctx)).resolves.toBe(false);
  });
});
