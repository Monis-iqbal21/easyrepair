import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { AcceptCustomerAgreementDto } from './accept-customer-agreement.dto';

/**
 * The DTO itself has no fields for identity, version or hash — combined with
 * the app's global `ValidationPipe({ whitelist: true, forbidNonWhitelisted:
 * true })` (see main.ts), any client attempt to supply
 * fullLegalName/version/agreementHash/clientProfileId in the accept body is
 * rejected outright rather than silently accepted. This test proves the DTO
 * shape enforces that — the whitelist behaviour itself is exercised by
 * class-validator here, the same mechanism main.ts wires up globally.
 */
describe('AcceptCustomerAgreementDto', () => {
  it('accepts a body with only checkboxAccepted', async () => {
    const dto = plainToInstance(AcceptCustomerAgreementDto, {
      checkboxAccepted: true,
    });
    const errors = await validate(dto, { whitelist: true, forbidNonWhitelisted: true });
    expect(errors).toEqual([]);
  });

  it('accepts an optional deviceDescriptor', async () => {
    const dto = plainToInstance(AcceptCustomerAgreementDto, {
      checkboxAccepted: true,
      deviceDescriptor: 'android/session-abc',
    });
    const errors = await validate(dto, { whitelist: true, forbidNonWhitelisted: true });
    expect(errors).toEqual([]);
  });

  it('rejects a forged full legal name / account identity', async () => {
    const dto = plainToInstance(AcceptCustomerAgreementDto, {
      checkboxAccepted: true,
      fullLegalName: 'Someone Else',
      clientProfileId: 'cp-not-mine',
    });
    const errors = await validate(dto, { whitelist: true, forbidNonWhitelisted: true });
    expect(errors.length).toBeGreaterThan(0);
    const properties = errors.map((e) => e.property);
    expect(properties).toEqual(
      expect.arrayContaining(['fullLegalName', 'clientProfileId']),
    );
  });

  it('rejects a forged agreement version or hash', async () => {
    const dto = plainToInstance(AcceptCustomerAgreementDto, {
      checkboxAccepted: true,
      version: '99.0',
      agreementHash: 'a'.repeat(64),
    });
    const errors = await validate(dto, { whitelist: true, forbidNonWhitelisted: true });
    const properties = errors.map((e) => e.property);
    expect(properties).toEqual(
      expect.arrayContaining(['version', 'agreementHash']),
    );
  });

  it('rejects a missing checkbox value', async () => {
    const dto = plainToInstance(AcceptCustomerAgreementDto, {});
    const errors = await validate(dto);
    expect(errors.some((e) => e.property === 'checkboxAccepted')).toBe(true);
  });

  it('rejects checkboxAccepted: false at the shape level only when combined with the service check', async () => {
    // The DTO alone permits `false` — it is the SERVICE that refuses it (see
    // customer-acceptance.service.spec.ts NOT_ACCEPTED tests). This is
    // deliberate: false is a valid, meaningful value the app can send.
    const dto = plainToInstance(AcceptCustomerAgreementDto, {
      checkboxAccepted: false,
    });
    const errors = await validate(dto);
    expect(errors).toEqual([]);
  });
});
