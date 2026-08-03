import { isSupportPhone } from './support-identity.util';

const SUPPORT = '+920000000000';

describe('isSupportPhone', () => {
  it.each([
    ['+920000000000'],
    // 0092 international form: 0092 + the 10-digit national number.
    ['00920000000000'],
    ['920000000000'],
    ['00000000000'],
    ['0000000000'],
    ['+92 0000 000000'],
    ['+92-0000-000000'],
  ])('recognises %s as the support account', (phone) => {
    expect(isSupportPhone(phone, SUPPORT)).toBe(true);
  });

  it.each([
    ['+923001234567'],
    ['03001234567'],
    ['+923378372427'],
  ])('does not match a real user number %s', (phone) => {
    expect(isSupportPhone(phone, SUPPORT)).toBe(false);
  });

  it.each([[null], [undefined], ['']])(
    'is false for a missing phone (%s)',
    (phone) => {
      expect(isSupportPhone(phone, SUPPORT)).toBe(false);
    },
  );

  it('is false when no support phone is configured', () => {
    expect(isSupportPhone('+920000000000', undefined)).toBe(false);
    expect(isSupportPhone('+920000000000', '')).toBe(false);
  });

  it('is false when both normalise to empty', () => {
    expect(isSupportPhone('+++', '---')).toBe(false);
  });
});
