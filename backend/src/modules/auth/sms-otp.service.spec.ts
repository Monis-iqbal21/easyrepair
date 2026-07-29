import { SmsOtpService } from './sms-otp.service';

describe('SmsOtpService', () => {
  let config: any;
  let service: SmsOtpService;
  const originalFetch = global.fetch;

  beforeEach(() => {
    config = {
      get: jest.fn((key: string) => {
        if (key === 'sms.apiKey') return 'test-api-key';
        if (key === 'sms.apiUrl') return 'https://api.veevotech.com/v3/sendsms';
        if (key === 'sms.sender') return 'Default';
        return undefined;
      }),
    };
    service = new SmsOtpService(config);
  });

  afterEach(() => {
    global.fetch = originalFetch;
    jest.restoreAllMocks();
  });

  it('is not configured when apiKey/apiUrl are missing', () => {
    config.get = jest.fn().mockReturnValue(undefined);
    const unconfigured = new SmsOtpService(config);
    expect(unconfigured.isConfigured).toBe(false);
  });

  it('returns true when VeevoTech responds with STATUS SUCCESSFUL', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ STATUS: 'SUCCESSFUL', MESSAGEID: 'abc123' }),
    }) as any;

    const result = await service.sendOtp('+923378372427', '123456');
    expect(result).toBe(true);

    const calledUrl = (global.fetch as jest.Mock).mock.calls[0][0] as string;
    expect(calledUrl).toContain('apikey=test-api-key');
    expect(calledUrl).toContain('receivernum=%2B923378372427');
  });

  it('returns false when VeevoTech rejects with a non-SUCCESSFUL status', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ STATUS: 'FAILED', ERROR: 'insufficient balance' }),
    }) as any;

    const result = await service.sendOtp('+923378372427', '123456');
    expect(result).toBe(false);
  });

  it('returns false on a non-OK HTTP response', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: false,
      status: 500,
      json: async () => ({}),
    }) as any;

    const result = await service.sendOtp('+923378372427', '123456');
    expect(result).toBe(false);
  });

  it('returns false (never throws) when the request times out / aborts', async () => {
    global.fetch = jest.fn().mockImplementation(
      () =>
        new Promise((_resolve, reject) => {
          const err = new Error('The operation was aborted');
          err.name = 'AbortError';
          reject(err);
        }),
    ) as any;

    await expect(service.sendOtp('+923378372427', '123456')).resolves.toBe(
      false,
    );
  });

  it('returns false immediately without calling fetch when not configured', async () => {
    config.get = jest.fn().mockReturnValue(undefined);
    const unconfigured = new SmsOtpService(config);
    global.fetch = jest.fn();
    const result = await unconfigured.sendOtp('+923378372427', '123456');
    expect(result).toBe(false);
    expect(global.fetch).not.toHaveBeenCalled();
  });
});
