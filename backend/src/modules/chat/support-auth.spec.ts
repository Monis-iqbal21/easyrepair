import { UnauthorizedException } from '@nestjs/common';
import { AuthService } from '../auth/auth.service';
import { SUPPORT_INBOX_ROOM, SUPPORT_SOCKET_ROLES } from './chat.gateway';
import { SUPPORT_ROLES } from './support.controller';
import { Role as AppRole } from '../../common/enums/role.enum';

const SUPPORT_PHONE = '+920000000000';

/**
 * The support system account owns support conversations and is the sender of
 * admin replies. It is provisioned without credentials and must be
 * unreachable through EVERY authentication path.
 */
describe('Support account cannot be signed into', () => {
  let service: AuthService;
  let repository: any;

  beforeEach(() => {
    repository = {
      findUserByPhone: jest.fn().mockResolvedValue(null),
      createRefreshToken: jest.fn().mockResolvedValue(undefined),
    };
    const config = {
      get: jest.fn((key: string) =>
        key === 'support.userPhone' ? SUPPORT_PHONE : undefined,
      ),
      getOrThrow: jest.fn().mockReturnValue('15m'),
    };
    service = new AuthService(
      repository,
      { sign: jest.fn().mockReturnValue('token') } as any,
      config as any,
      {} as any,
      { isConfigured: false, sendOtp: jest.fn() } as any,
      { ensureSupportConversation: jest.fn() } as any,
      { handleWorkerLogout: jest.fn().mockResolvedValue(undefined) } as any,
    );
  });

  const reject = expect.objectContaining({ message: 'Invalid phone number' });

  it('rejects a password login', async () => {
    await expect(
      service.login({ phone: SUPPORT_PHONE, password: 'anything' } as any),
    ).rejects.toThrow(UnauthorizedException);
    // Never even looks the account up.
    expect(repository.findUserByPhone).not.toHaveBeenCalled();
  });

  it('rejects an OTP request', async () => {
    await expect(
      service.requestOtp(SUPPORT_PHONE, 'CLIENT_LOGIN_REGISTER' as any, '1.2.3.4'),
    ).rejects.toThrow(reject);
  });

  it('rejects client OTP login/registration', async () => {
    await expect(
      service.clientOtpLoginOrRegister('Support', SUPPORT_PHONE, '123456'),
    ).rejects.toThrow(reject);
  });

  it('rejects worker OTP login', async () => {
    await expect(
      service.workerOtpLogin(SUPPORT_PHONE, '123456'),
    ).rejects.toThrow(reject);
  });

  it('rejects client password login', async () => {
    await expect(
      service.clientPasswordLogin(SUPPORT_PHONE, 'anything'),
    ).rejects.toThrow(reject);
  });

  it('rejects the phone-status probe, so the reserved number cannot be discovered', async () => {
    await expect(
      service.checkClientPhoneStatus(SUPPORT_PHONE),
    ).rejects.toThrow(reject);
  });

  it.each([
    ['worker forgot-password', (s: AuthService) =>
      s.forgotPasswordRequest({ phone: SUPPORT_PHONE } as any)],
    ['client forgot-password', (s: AuthService) =>
      s.clientForgotPasswordRequest({ phone: SUPPORT_PHONE } as any)],
    ['password reset', (s: AuthService) =>
      s.forgotPasswordReset({
        phone: SUPPORT_PHONE,
        otp: '123456',
        newPassword: 'newpassword1',
      } as any)],
  ])('rejects %s', async (_label, call) => {
    await expect(call(service)).rejects.toThrow(reject);
  });

  it.each([
    ['password registration', (s: AuthService) =>
      s.clientPasswordRegister('Support', SUPPORT_PHONE, 'password1')],
    ['worker OTP registration', (s: AuthService) =>
      s.workerOtpRegister('Support', SUPPORT_PHONE, '123456', 'password1', 'cat-1')],
    ['generic registration', (s: AuthService) =>
      s.register({
        phone: SUPPORT_PHONE,
        password: 'password1',
        firstName: 'Support',
        lastName: '',
        role: 'CLIENT',
      } as any)],
  ])('rejects %s, so the account cannot be re-registered', async (_l, call) => {
    await expect(call(service)).rejects.toThrow(reject);
  });

  it('leaves ordinary numbers completely unaffected', async () => {
    // A real number reaches the normal lookup and fails there, not at the
    // support guard — proving the guard is not over-broad. It gets the
    // same privacy-safe PHONE_NOT_REGISTERED rejection every other
    // unregistered-number login attempt gets (see _phoneNotRegisteredError)
    // — never the password-specific "Invalid phone number or password",
    // which only fires once a real account was actually found.
    await expect(
      service.login({ phone: '+923001234567', password: 'x' } as any),
    ).rejects.toMatchObject({
      response: { error: 'PHONE_NOT_REGISTERED', message: '' },
    });
    expect(repository.findUserByPhone).toHaveBeenCalledWith('+923001234567');
  });
});

/**
 * Support-inbox membership is decided server-side from the verified JWT role.
 * There is deliberately NO client event that can request the room.
 */
describe('support:inbox authorization', () => {
  it('is restricted to ADMIN', () => {
    expect(SUPPORT_SOCKET_ROLES).toEqual(['ADMIN']);
    expect(SUPPORT_SOCKET_ROLES).not.toContain('CLIENT');
    expect(SUPPORT_SOCKET_ROLES).not.toContain('WORKER');
  });

  it('uses a single well-known room name', () => {
    expect(SUPPORT_INBOX_ROOM).toBe('support:inbox');
  });

  it('mirrors the HTTP guard, so both grant the same roles', () => {
    expect(SUPPORT_ROLES).toEqual([AppRole.ADMIN]);
    expect(SUPPORT_ROLES.map(String)).toEqual(SUPPORT_SOCKET_ROLES);
  });

  it('exposes no client-triggered join event for the inbox room', () => {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const fs = require('fs') as typeof import('fs');
    const src = fs.readFileSync('src/modules/chat/chat.gateway.ts', 'utf-8');
    // The room is joined only inside handleConnection, never from a
    // @SubscribeMessage handler a client could invoke.
    expect(src).not.toMatch(/@SubscribeMessage\(['"]join_support/);
    const joinIndex = src.indexOf(`socket.join(SUPPORT_INBOX_ROOM)`);
    expect(joinIndex).toBeGreaterThan(-1);
    expect(src.slice(0, joinIndex)).toContain('handleConnection');
  });
});
