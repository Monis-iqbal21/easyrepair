import { Module } from '@nestjs/common';
import { AgreementsService } from './agreements.service';
import { UstaadAcceptanceService } from './ustaad-acceptance.service';
import { UstaadTemplateService } from './ustaad-template.service';
import { UstaadAgreementAccessService } from './ustaad-agreement-access.service';
import { CustomerTemplateService } from './customer-template.service';
import { CustomerAcceptanceService } from './customer-acceptance.service';
import { CustomerAgreementAccessService } from './customer-agreement-access.service';
import { CustomerAgreementsController } from './customer-agreements.controller';
import { AgreementsRepository } from './agreements.repository';
import { StorageModule } from '../storage/storage.module';

@Module({
  imports: [StorageModule],
  controllers: [CustomerAgreementsController],
  providers: [
    AgreementsService,
    UstaadTemplateService,
    UstaadAcceptanceService,
    UstaadAgreementAccessService,
    CustomerTemplateService,
    CustomerAcceptanceService,
    CustomerAgreementAccessService,
    AgreementsRepository,
  ],
  // The three-document Ustaad flow: templates to read, acceptance to write,
  // access for the Worker Legal section and the Admin detail page. The
  // single-document Client flow mirrors it. The legacy AgreementsService is
  // still exported for template lookups elsewhere.
  exports: [
    AgreementsService,
    UstaadTemplateService,
    UstaadAcceptanceService,
    UstaadAgreementAccessService,
    CustomerTemplateService,
    CustomerAcceptanceService,
    CustomerAgreementAccessService,
  ],
})
export class AgreementsModule {}
