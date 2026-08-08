import {
  Controller,
  Get,
  NotFoundException,
  Param,
  Res,
  UseGuards,
} from '@nestjs/common';
import { Response } from 'express';
import { sendPrivatePdf } from '../../common/utils/private-pdf-response.util';
import { AgreementsRepository } from '../agreements/agreements.repository';
import { CustomerAgreementAccessService } from '../agreements/customer-agreement-access.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';

/**
 * Admin read access to a Client's accepted agreements — mirrors
 * AdminController's `/admin/workers/:workerProfileId/agreements*` routes,
 * kept as its own controller (rather than added to AdminController) because
 * the path root is `admin/clients`, not `admin/workers`.
 */
@Controller('admin/clients')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminClientAgreementsController {
  constructor(
    private readonly repository: AgreementsRepository,
    private readonly accessService: CustomerAgreementAccessService,
  ) {}

  private async _ensureExists(clientProfileId: string): Promise<void> {
    const profile = await this.repository.findClientProfileById(clientProfileId);
    if (!profile) throw new NotFoundException('Client profile not found');
  }

  /**
   * GET /admin/clients/:clientProfileId/agreements
   * The permanent legal audit record(s) with their full evidence (acceptance
   * id, accepted language, and the source/accepted/PDF hashes). Admin-only,
   * Worker documents excluded, no storage URL returned.
   */
  @Get(':clientProfileId/agreements')
  async getClientAgreements(
    @Param('clientProfileId') clientProfileId: string,
  ) {
    await this._ensureExists(clientProfileId);
    return this.accessService.listForClient(clientProfileId);
  }

  /**
   * GET /admin/clients/:clientProfileId/agreements/:acceptanceId/download
   * Streams one accepted PDF through this authenticated admin endpoint. The
   * acceptance must belong to the client in the path.
   */
  @Get(':clientProfileId/agreements/:acceptanceId/download')
  async downloadClientAgreement(
    @Param('clientProfileId') clientProfileId: string,
    @Param('acceptanceId') acceptanceId: string,
    @Res() res: Response,
  ) {
    await this._ensureExists(clientProfileId);
    const pdf = await this.accessService.getPdf(acceptanceId, clientProfileId);
    sendPrivatePdf(res, pdf);
  }
}
