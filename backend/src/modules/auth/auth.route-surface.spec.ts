import 'reflect-metadata';
import { PATH_METADATA, METHOD_METADATA } from '@nestjs/common/constants';
import { RequestMethod } from '@nestjs/common';
import { AuthController } from './auth.controller';

/**
 * Pins the resolved URL of every auth route the app calls.
 *
 * Production was answering `Cannot POST /api/v1/auth/worker/otp-verify` while
 * the route was plainly present in this file — a deployed build older than the
 * source, not a coding error. A test that reads the decorators is the cheapest
 * way to keep the two diagnoses apart: if this suite passes and production
 * still 404s, the server is running old code and the fix is a redeploy, not an
 * edit.
 *
 * The global prefix is applied in `main.ts` (`app.setGlobalPrefix('api/v1')`),
 * so the full path is `/api/v1` + controller path + route path.
 */
describe('AuthController — resolved route paths', () => {
  const GLOBAL_PREFIX = 'api/v1';

  function resolved(method: keyof typeof AuthController.prototype) {
    const handler = AuthController.prototype[method];
    const controllerPath = Reflect.getMetadata(PATH_METADATA, AuthController);
    const routePath = Reflect.getMetadata(PATH_METADATA, handler);
    const verb: RequestMethod = Reflect.getMetadata(METHOD_METADATA, handler);
    return {
      verb: RequestMethod[verb],
      path: `/${GLOBAL_PREFIX}/${controllerPath}/${routePath}`.replace(
        /\/+/g,
        '/',
      ),
    };
  }

  it.each([
    // The endpoint the production 404 was about.
    ['workerOtpVerify', 'POST', '/api/v1/auth/worker/otp-verify'],
    ['workerOtpRegister', 'POST', '/api/v1/auth/worker/otp-register'],
    ['login', 'POST', '/api/v1/auth/login'],
    ['clientOtpLogin', 'POST', '/api/v1/auth/client/otp-login'],
    ['clientPasswordLogin', 'POST', '/api/v1/auth/client/password-login'],
    [
      'clientPasswordRegister',
      'POST',
      '/api/v1/auth/client/password-register',
    ],
    ['checkClientPhoneStatus', 'POST', '/api/v1/auth/client/phone-check'],
    ['requestOtp', 'POST', '/api/v1/auth/otp/request'],
    [
      'clientForgotPasswordRequest',
      'POST',
      '/api/v1/auth/client/forgot-password/request',
    ],
    [
      'clientForgotPasswordReset',
      'POST',
      '/api/v1/auth/client/forgot-password/reset',
    ],
    ['forgotPasswordRequest', 'POST', '/api/v1/auth/forgot-password/request'],
    ['forgotPasswordReset', 'POST', '/api/v1/auth/forgot-password/reset'],
  ] as const)('%s is served at %s %s', (method, verb, path) => {
    expect(resolved(method as any)).toEqual({ verb, path });
  });

  it('the removed worker OTP-login route is really gone — Ustaad sign-in is password-only', () => {
    const removed = Object.getOwnPropertyNames(AuthController.prototype)
      .filter((m) => m !== 'constructor')
      .map((m) => resolved(m as any).path);
    expect(removed).not.toContain('/api/v1/auth/worker/otp-login');
  });
});
