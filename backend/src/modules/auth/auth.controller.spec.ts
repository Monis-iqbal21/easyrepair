import 'reflect-metadata';
import { BadRequestException } from '@nestjs/common';
import { Request } from 'express';
import { AuthController } from './auth.controller';
import { BYPASS_CLIENT_SUSPENSION_KEY } from '../../common/decorators/bypass-client-suspension.decorator';
import { Role } from '../../common/enums/role.enum';

/**
 * Pins the minimal whitelist a suspended CLIENT still needs: GET /auth/me
 * (so the app can even learn it's restricted) and POST /auth/logout
 * (session cleanup). Every other authenticated /auth endpoint is NOT
 * bypassed and falls under JwtAuthGuard's normal suspension check.
 */
describe('AuthController — Client suspension bypass whitelist', () => {
  it('GET /auth/me is marked @BypassClientSuspension', () => {
    expect(
      Reflect.getMetadata(
        BYPASS_CLIENT_SUSPENSION_KEY,
        AuthController.prototype.getMe,
      ),
    ).toBe(true);
  });

  it('POST /auth/logout is marked @BypassClientSuspension', () => {
    expect(
      Reflect.getMetadata(
        BYPASS_CLIENT_SUSPENSION_KEY,
        AuthController.prototype.logout,
      ),
    ).toBe(true);
  });

  it.each([
    'deleteAccount',
    'saveFcmToken',
    'getAvatarUrl',
    'uploadAvatar',
  ] as const)(
    '%s is NOT bypassed — a suspended Client falls under the normal 403 there',
    (method) => {
      expect(
        Reflect.getMetadata(
          BYPASS_CLIENT_SUSPENSION_KEY,
          AuthController.prototype[method],
        ),
      ).toBeUndefined();
    },
  );
});

describe('AuthController — account-delete confirmation safety', () => {
  const user = { id: 'user-1', role: Role.CLIENT };
  const request = {
    ip: '203.0.113.7',
    path: '/api/v1/auth/account',
    url: '/api/v1/auth/account?ignored=true',
    headers: { 'user-agent': 'Dart/3.10 (android)' },
  } as Request;

  let authService: { deleteAccount: jest.Mock };
  let controller: AuthController;
  let auditLogger: { log: jest.Mock; warn: jest.Mock };

  beforeEach(() => {
    authService = { deleteAccount: jest.fn() };
    controller = new AuthController(authService as never);
    auditLogger = { log: jest.fn(), warn: jest.fn() };
    (controller as unknown as { logger: typeof auditLogger }).logger =
      auditLogger;
  });

  it.each([
    ['missing body', undefined],
    ['empty body', {}],
    ['incorrect confirmation', { confirmation: 'DELETE_ACCOUNT' }],
  ])('rejects %s without mutating the User', async (_label, body) => {
    let caught: unknown;
    try {
      await controller.deleteAccount(user, body, request);
    } catch (error) {
      caught = error;
    }

    expect(caught).toBeInstanceOf(BadRequestException);
    expect((caught as BadRequestException).getStatus()).toBe(400);
    expect((caught as BadRequestException).getResponse()).toEqual({
      message: 'Explicit account-deletion confirmation is required.',
      error: 'ACCOUNT_DELETE_CONFIRMATION_REQUIRED',
    });

    expect(authService.deleteAccount).not.toHaveBeenCalled();
    expect(auditLogger.warn).toHaveBeenCalledTimes(1);
    expect(auditLogger.log).not.toHaveBeenCalled();

    const audit = JSON.parse(auditLogger.warn.mock.calls[0][0]);
    expect(audit).toMatchObject({
      userId: user.id,
      role: user.role,
      ip: request.ip,
      userAgent: request.headers['user-agent'],
      path: request.path,
      outcome: 'ATTEMPT_REJECTED',
    });
    expect(audit.timestamp).toEqual(expect.any(String));
  });

  it('accepts only the exact sentinel and audits attempt plus success', async () => {
    authService.deleteAccount.mockResolvedValue({
      message: 'Account deleted successfully.',
    });

    await expect(
      controller.deleteAccount(
        user,
        { confirmation: 'DELETE_MY_ACCOUNT' },
        request,
      ),
    ).resolves.toEqual({ message: 'Account deleted successfully.' });

    expect(authService.deleteAccount).toHaveBeenCalledTimes(1);
    expect(authService.deleteAccount).toHaveBeenCalledWith(user.id);
    expect(auditLogger.warn).not.toHaveBeenCalled();
    expect(auditLogger.log).toHaveBeenCalledTimes(2);

    const audits = auditLogger.log.mock.calls.map(([entry]) =>
      JSON.parse(entry),
    );
    expect(audits.map((audit) => audit.outcome)).toEqual([
      'ATTEMPT_ACCEPTED',
      'DELETION_SUCCESS',
    ]);
    for (const audit of audits) {
      expect(Object.keys(audit).sort()).toEqual(
        [
          'ip',
          'outcome',
          'path',
          'role',
          'timestamp',
          'userAgent',
          'userId',
        ].sort(),
      );
      expect(JSON.stringify(audit)).not.toMatch(
        /authorization|password|phone|token/i,
      );
    }
  });
});
