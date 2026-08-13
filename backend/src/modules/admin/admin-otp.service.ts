import {
  BadRequestException,
  Injectable,
  InternalServerErrorException,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AuthOtp } from '@prisma/client';
import { AdminOtpRepository } from './admin-otp.repository';
import { ListOtpQueryDto } from './dto/list-otp-query.dto';
import {
  OtpLifecycleStatus,
  OtpListItemDto,
  PaginatedOtpDto,
} from './dto/otp-list-item.dto';
import { RevealOtpResponseDto } from './dto/reveal-otp-response.dto';
import {
  decryptOtp,
  OtpDecryptionError,
  OtpEncryptionKeyError,
} from '../../common/utils/otp-encryption.util';

function deriveStatus(
  record: Pick<AuthOtp, 'consumedAt' | 'expiresAt'>,
): OtpLifecycleStatus {
  if (record.consumedAt) return 'CONSUMED';
  if (record.expiresAt.getTime() <= Date.now()) return 'EXPIRED';
  return 'ACTIVE';
}

@Injectable()
export class AdminOtpService {
  private readonly logger = new Logger(AdminOtpService.name);

  constructor(
    private readonly repository: AdminOtpRepository,
    private readonly config: ConfigService,
  ) {}

  /** GET /admin/otp */
  async list(query: ListOtpQueryDto): Promise<PaginatedOtpDto> {
    const page = query.page ?? 1;
    const pageSize = query.pageSize ?? 20;
    const { items, total } = await this.repository.findPaginated(query);

    return {
      items: items.map((r) => this._toListItemDto(r)),
      meta: {
        page,
        pageSize,
        total,
        totalPages: Math.max(1, Math.ceil(total / pageSize)),
      },
    };
  }

  /**
   * POST /admin/otp/:id/reveal
   * Only ACTIVE (not consumed, not expired) OTPs that were actually
   * dispatched via SMS (smsDispatched === true) and have a stored encrypted
   * copy may be revealed — independently re-checked here regardless of what
   * the list endpoint's `revealable` said. Every successful reveal writes an
   * OtpRevealAuditLog row — never the plaintext code itself.
   */
  async reveal(
    id: string,
    adminUserId: string,
    ipAddress: string | null,
    userAgent: string | null,
  ): Promise<RevealOtpResponseDto> {
    const record = await this.repository.findByIdForReveal(id);
    if (!record) throw new NotFoundException('OTP record not found.');

    const status = deriveStatus(record);
    if (status === 'CONSUMED') {
      throw new BadRequestException(
        'This OTP has already been used and cannot be revealed.',
      );
    }
    if (status === 'EXPIRED') {
      throw new BadRequestException(
        'This OTP has expired and cannot be revealed.',
      );
    }
    if (record.smsDispatched !== true) {
      throw new BadRequestException(
        'This OTP cannot be revealed — the SMS was never confirmed dispatched.',
      );
    }
    if (!record.otpCiphertext || !record.otpCipherIv || !record.otpCipherTag) {
      throw new BadRequestException(
        'This OTP cannot be revealed — no secure copy was stored for it.',
      );
    }

    let otp: string;
    try {
      otp = decryptOtp(
        {
          ciphertext: record.otpCiphertext,
          iv: record.otpCipherIv,
          tag: record.otpCipherTag,
        },
        this.config.get<string>('otpAdmin.encryptionKey'),
      );
    } catch (err) {
      if (
        err instanceof OtpEncryptionKeyError ||
        err instanceof OtpDecryptionError
      ) {
        // Never log the ciphertext or key material — message only.
        this.logger.error(
          `[reveal] otpId=${id} could not be decrypted: ${err.message}`,
        );
        throw new InternalServerErrorException(
          'Unable to reveal this OTP right now.',
        );
      }
      throw err;
    }

    await this.repository.createRevealAuditLog({
      adminUserId,
      authOtpId: record.id,
      targetPhone: record.phone,
      purpose: record.purpose,
      ipAddress,
      userAgent,
    });

    return { otp, expiresAt: record.expiresAt };
  }

  private _toListItemDto(r: AuthOtp): OtpListItemDto {
    const status = deriveStatus(r);
    return {
      id: r.id,
      phone: r.phone,
      purpose: r.purpose,
      createdAt: r.createdAt,
      expiresAt: r.expiresAt,
      attempts: r.attempts,
      consumedAt: r.consumedAt,
      status,
      smsStatus: r.smsDispatched ? 'DISPATCHED' : 'NOT_SENT',
      requestIp: r.requestIp,
      revealable:
        status === 'ACTIVE' &&
        r.smsDispatched === true &&
        Boolean(r.otpCiphertext && r.otpCipherIv && r.otpCipherTag),
    };
  }
}
