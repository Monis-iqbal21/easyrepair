import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/** `+9233****427` — never log a full phone number alongside SMS activity. */
function maskPhone(e164Phone: string): string {
  if (e164Phone.length <= 8) return '****';
  return `${e164Phone.slice(0, 5)}****${e164Phone.slice(-3)}`;
}

@Injectable()
export class SmsOtpService {
  private readonly logger = new Logger(SmsOtpService.name);
  private readonly apiKey: string | undefined;
  private readonly apiUrl: string | undefined;
  private readonly sender: string;

  constructor(private readonly config: ConfigService) {
    this.apiKey = this.config.get<string>('sms.apiKey');
    this.apiUrl = this.config.get<string>('sms.apiUrl');
    this.sender = this.config.get<string>('sms.sender') || 'Default';
  }

  get isConfigured(): boolean {
    return !!(this.apiKey && this.apiUrl);
  }

  /**
   * Sends the OTP via VeevoTech. Returns whether the provider accepted the
   * message (`STATUS === 'SUCCESSFUL'`) — never throws, so a provider hiccup
   * can be reported to the caller as a normal boolean result rather than an
   * exception that might get conflated with other failure handling.
   */
  async sendOtp(e164Phone: string, otp: string): Promise<boolean> {
    if (!this.isConfigured) return false;

    const message = `HandyGo verification code: ${otp}. Ye code 5 minute mein expire hoga. Kisi ke saath share na karein.`;

    const url = new URL(this.apiUrl!);
    url.searchParams.set('apikey', this.apiKey!);
    url.searchParams.set('receivernum', e164Phone);
    url.searchParams.set('textmessage', message);
    url.searchParams.set('sendernum', this.sender);

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10_000);

    try {
      const response = await fetch(url.toString(), {
        method: 'GET',
        signal: controller.signal,
      });

      if (!response.ok) {
        this.logger.warn(
          `SMS send failed: HTTP ${response.status} (phone ${maskPhone(e164Phone)})`,
        );
        return false;
      }

      const data = await response.json().catch(() => null);
      const status =
        data && typeof data === 'object'
          ? (data as Record<string, unknown>).STATUS
          : undefined;

      if (status !== 'SUCCESSFUL') {
        this.logger.warn(
          `SMS not accepted by provider (phone ${maskPhone(e164Phone)}, status=${String(status)})`,
        );
        return false;
      }

      this.logger.log(`SMS OTP dispatched (phone ${maskPhone(e164Phone)})`);
      return true;
    } catch (err) {
      this.logger.warn(
        `SMS send error (phone ${maskPhone(e164Phone)}): ${(err as Error).message}`,
      );
      return false;
    } finally {
      clearTimeout(timeout);
    }
  }
}
