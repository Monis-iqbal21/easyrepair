import { ArgumentsHost, BadRequestException } from '@nestjs/common';
import { GlobalExceptionFilter } from './http-exception.filter';

/**
 * retryAfterSeconds is the one exception-payload field this filter
 * deliberately allow-lists through to the client (see OTP_RESEND_TOO_SOON,
 * AuthService.requestOtp) — everything else on a thrown exception's
 * response object is either mapped to a named field or dropped.
 */
describe('GlobalExceptionFilter', () => {
  const filter = new GlobalExceptionFilter();

  function runCatch(exception: unknown) {
    const json = jest.fn();
    const status = jest.fn().mockReturnValue({ json });
    const host = {
      switchToHttp: () => ({
        getResponse: () => ({ status }),
        getRequest: () => ({ url: '/api/v1/auth/otp/request' }),
      }),
    } as unknown as ArgumentsHost;

    filter.catch(exception, host);
    return json.mock.calls[0][0];
  }

  it('passes retryAfterSeconds through when the exception carries it', () => {
    const body = runCatch(
      new BadRequestException({
        message: 'Thori dair intezaar karein, phir dobara code mangwayein.',
        error: 'OTP_RESEND_TOO_SOON',
        retryAfterSeconds: 37,
      }),
    );

    expect(body.error).toBe('OTP_RESEND_TOO_SOON');
    expect(body.retryAfterSeconds).toBe(37);
  });

  it('omits retryAfterSeconds entirely when the exception has none', () => {
    const body = runCatch(
      new BadRequestException({
        message: 'Bohat zyada koshishein. Thori dair baad dobara koshish karein.',
        error: 'OTP_RATE_LIMITED',
      }),
    );

    expect(body.error).toBe('OTP_RATE_LIMITED');
    expect('retryAfterSeconds' in body).toBe(false);
  });

  it('ignores a non-numeric retryAfterSeconds rather than passing it through', () => {
    const body = runCatch(
      new BadRequestException({
        message: 'x',
        error: 'SOME_ERROR',
        retryAfterSeconds: 'soon',
      }),
    );

    expect('retryAfterSeconds' in body).toBe(false);
  });
});
