import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Ip,
  NotFoundException,
  Param,
  Post,
  Query,
  Res,
  UseGuards,
} from '@nestjs/common';
import { Response } from 'express';
import { AgreementType } from '@prisma/client';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Role } from '../../common/enums/role.enum';
import { sendPrivatePdf } from '../../common/utils/private-pdf-response.util';
import { AgreementsRepository } from './agreements.repository';
import { CustomerTemplateService } from './customer-template.service';
import { CustomerAcceptanceService } from './customer-acceptance.service';
import { CustomerAgreementAccessService } from './customer-agreement-access.service';
import { AcceptCustomerAgreementDto } from './dto/accept-customer-agreement.dto';

/**
 * The single agreement key this endpoint family currently accepts. Kept as
 * an explicit map (rather than trusting any string) so a client can never
 * smuggle a Worker document type in through the URL, and so a future second
 * Customer document is a deliberate addition here.
 */
const AGREEMENT_KEYS: Record<string, AgreementType> = {
  'customer-terms': AgreementType.CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE,
};

@Controller('customer/agreements')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.CLIENT)
export class CustomerAgreementsController {
  constructor(
    private readonly repository: AgreementsRepository,
    private readonly templateService: CustomerTemplateService,
    private readonly acceptanceService: CustomerAcceptanceService,
    private readonly accessService: CustomerAgreementAccessService,
  ) {}

  /** Resolves the authenticated Client's own profile id — never client-supplied. */
  private async _clientProfileId(userId: string): Promise<string> {
    const profile = await this.repository.findClientProfileByUserId(userId);
    if (!profile) throw new NotFoundException('Client profile not found');
    return profile.id;
  }

  /**
   * GET /customer/agreements/required
   *
   * Whether the authenticated Client must accept Customer Terms Version 1.0,
   * the current agreement's exact text/version/hash, and (when already
   * accepted) that acceptance's metadata. `locale` is the language the app is
   * currently showing — the legal body comes back in the language it
   * genuinely exists in. Falls back to the Accept-Language header, then
   * Roman Urdu.
   */
  @Get('required')
  async getRequired(
    @CurrentUser() user: { id: string },
    @Query('locale') locale?: string,
    @Headers('accept-language') acceptLanguage?: string,
  ) {
    const clientProfileId = await this._clientProfileId(user.id);
    const template = this.templateService.getTemplateForClient(
      locale ?? acceptLanguage ?? 'ur_Latn',
    );

    const existing = await this.repository.findClientAcceptanceByUniqueKey(
      clientProfileId,
      AGREEMENT_KEYS['customer-terms'],
      template.version,
      template.sourceHash,
    );

    return {
      acceptanceRequired: !existing,
      agreement: {
        agreementKey: 'customer-terms',
        documentType: template.documentType,
        title: template.title,
        version: template.version,
        sourceHash: template.sourceHash,
        agreementLocale: template.agreementLocale,
        contentText: template.contentText,
        legalLanguageNoticeRequired: template.legalLanguageNoticeRequired,
        requestedAppLocale: template.requestedAppLocale,
      },
      existingAcceptance: existing
        ? {
            id: existing.id,
            acceptanceId: existing.acceptanceId,
            version: existing.agreementVersion,
            acceptedAt: existing.acceptedAt,
          }
        : null,
    };
  }

  /**
   * POST /customer/agreements/:agreementKey/accept
   *
   * Body: { checkboxAccepted, deviceDescriptor? }. Seals the one immutable
   * Customer Terms acceptance record. Identity, version, hash and timestamps
   * are all resolved server-side. A repeated request for an already-accepted
   * version returns the SAME record rather than creating a duplicate.
   */
  @Post(':agreementKey/accept')
  @HttpCode(HttpStatus.OK)
  async accept(
    @CurrentUser() user: { id: string; phone: string },
    @Param('agreementKey') agreementKey: string,
    @Body() dto: AcceptCustomerAgreementDto,
    @Ip() ip: string,
    @Headers('user-agent') userAgent?: string,
  ) {
    if (!(agreementKey in AGREEMENT_KEYS)) {
      throw new NotFoundException('Unknown agreement');
    }
    const clientProfileId = await this._clientProfileId(user.id);
    const profile = await this.repository.findClientProfileByUserId(user.id);
    const fullLegalName = profile
      ? `${profile.firstName} ${profile.lastName}`.trim()
      : '';

    const deviceInfo = [dto.deviceDescriptor, userAgent]
      .filter(Boolean)
      .join(' / ') || null;

    return this.acceptanceService.accept({
      clientProfileId,
      userId: user.id,
      fullLegalName,
      registeredMobile: user.phone,
      ipAddress: ip ?? null,
      deviceInfo,
      checkboxAccepted: dto.checkboxAccepted,
    });
  }

  /**
   * GET /customer/agreements/history
   * Owner-only: this client's own permanent agreement acceptance records.
   * Metadata only — no storage URL is ever returned.
   */
  @Get('history')
  async getHistory(@CurrentUser() user: { id: string }) {
    const clientProfileId = await this._clientProfileId(user.id);
    return this.accessService.listForClient(clientProfileId);
  }

  /**
   * GET /customer/agreements/acceptances/:acceptanceId/download
   *
   * Streams the accepted PDF through this authenticated endpoint after an
   * ownership check. Another client's acceptance id is rejected, the bucket
   * URL is never exposed, and the filename carries only the public
   * acceptance id — never the phone number or the Client's name.
   */
  @Get('acceptances/:acceptanceId/download')
  async download(
    @CurrentUser() user: { id: string },
    @Param('acceptanceId') acceptanceId: string,
    @Res() res: Response,
  ) {
    const clientProfileId = await this._clientProfileId(user.id);
    const pdf = await this.accessService.getPdf(acceptanceId, clientProfileId);
    sendPrivatePdf(res, pdf);
  }
}
