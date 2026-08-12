import 'reflect-metadata';
import { AuthController } from './auth.controller';
import { BYPASS_CLIENT_SUSPENSION_KEY } from '../../common/decorators/bypass-client-suspension.decorator';

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
