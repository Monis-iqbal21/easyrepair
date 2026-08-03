import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class WhatsappOtpService {
  private readonly logger = new Logger(WhatsappOtpService.name);
  private readonly token: string | undefined;
  private readonly phoneNumberId: string | undefined;
  private readonly apiVersion: string;
  private readonly templateName: string | undefined;
  private readonly templateLanguage: string;
  private readonly includeButtonCode: boolean;

  constructor(private readonly config: ConfigService) {
    this.token = this.config.get<string>('whatsapp.token');
    this.phoneNumberId = this.config.get<string>('whatsapp.phoneNumberId');
    this.apiVersion = this.config.get<string>('whatsapp.apiVersion') || 'v20.0';
    this.templateName = this.config.get<string>('whatsapp.otpTemplateName');
    this.templateLanguage =
      this.config.get<string>('whatsapp.otpTemplateLanguage') || 'en_US';
    this.includeButtonCode =
      this.config.get<string>('whatsapp.includeButtonCode') === 'true';
  }

  get isConfigured(): boolean {
    return !!(this.token && this.phoneNumberId && this.templateName);
  }

  async sendOtp(e164Phone: string, otp: string): Promise<void> {
    if (!this.isConfigured) return;

    // WhatsApp "to" value strips the leading +
    const to = e164Phone.replace(/^\+/, '');
    const url = `https://graph.facebook.com/${this.apiVersion}/${this.phoneNumberId}/messages`;

    const components: object[] = [
      {
        type: 'body',
        parameters: [{ type: 'text', text: otp }],
      },
    ];

    if (this.includeButtonCode) {
      components.push({
        type: 'button',
        sub_type: 'url',
        index: '0',
        parameters: [{ type: 'text', text: otp }],
      });
    }

    const body = {
      messaging_product: 'whatsapp',
      to,
      type: 'template',
      template: {
        name: this.templateName,
        language: { code: this.templateLanguage },
        components,
      },
    };

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const text = await response.text().catch(() => '');
      this.logger.error(
        `WhatsApp OTP send failed [${response.status}]: ${text}`,
      );
    }
  }
}
