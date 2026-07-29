import { normalizePakistaniPhone, phoneLookupVariants } from './phone.util';

describe('normalizePakistaniPhone', () => {
  const expected = '+923378372427';

  it.each([
    ['03378372427', 'leading-zero local format'],
    ['3378372427', 'bare 10-digit format'],
    ['923378372427', 'country-code without plus'],
    ['+923378372427', 'full E.164'],
    ['00923378372427', 'international dialing prefix'],
  ])('normalizes %s (%s) to +923378372427', (raw) => {
    expect(normalizePakistaniPhone(raw)).toBe(expected);
  });

  it('tolerates surrounding whitespace and internal dashes', () => {
    expect(normalizePakistaniPhone('  0337-8372427 ')).toBe(expected);
  });

  it.each([
    ['123456789', 'too short'],
    ['02001234567', 'landline-shaped (not starting with 3 after prefix)'],
    ['abcdefghijk', 'non-numeric'],
    ['', 'empty string'],
    ['+92337837242', '11 digits after country code (too short)'],
  ])('rejects %s (%s)', (raw) => {
    expect(normalizePakistaniPhone(raw)).toBeNull();
  });
});

describe('phoneLookupVariants', () => {
  it('produces every historical raw format for a normalized number', () => {
    const variants = phoneLookupVariants('+923378372427');
    expect(variants).toEqual(
      expect.arrayContaining([
        '+923378372427',
        '03378372427',
        '923378372427',
        '00923378372427',
      ]),
    );
    expect(variants).toHaveLength(4);
  });
});
