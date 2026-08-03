import { Module } from '@nestjs/common';
import { AgreementsService } from './agreements.service';
import { UstaadAcceptanceService } from './ustaad-acceptance.service';
import { UstaadTemplateService } from './ustaad-template.service';
import { UstaadAgreementAccessService } from './ustaad-agreement-access.service';
import { AgreementsRepository } from './agreements.repository';
import { StorageModule } from '../storage/storage.module';

@Module({
  imports: [StorageModule],
  providers: [
    AgreementsService,
    UstaadTemplateService,
    UstaadAcceptanceService,
    UstaadAgreementAccessService,
    AgreementsRepository,
  ],
  // The three-document Ustaad flow: templates to read, acceptance to write,
  // access for the Worker Legal section and the Admin detail page. The legacy
  // AgreementsService is still exported for template lookups elsewhere.
  exports: [
    AgreementsService,
    UstaadTemplateService,
    UstaadAcceptanceService,
    UstaadAgreementAccessService,
  ],
})
export class AgreementsModule {}
