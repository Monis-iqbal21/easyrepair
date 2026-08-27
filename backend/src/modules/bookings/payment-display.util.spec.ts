import { derivePaymentDisplay } from './payment-display.util';

describe('derivePaymentDisplay', () => {
  it('is UNPAID without inventing amounts before a settlement exists', () => {
    expect(derivePaymentDisplay(null)).toEqual({
      paymentDisplayStatus: 'UNPAID',
      receivedAmount: null,
      expectedAmount: null,
      remainingAmount: null,
    });
  });

  it('surfaces an explicitly recorded zero payment as UNPAID', () => {
    expect(derivePaymentDisplay({ expectedTotal: 1000, received: 0 })).toEqual({
      paymentDisplayStatus: 'UNPAID',
      receivedAmount: 0,
      expectedAmount: 1000,
      remainingAmount: 1000,
    });
  });

  it('derives PARTIAL and the authoritative remaining amount', () => {
    expect(
      derivePaymentDisplay({ expectedTotal: 1000, received: 400 }),
    ).toEqual({
      paymentDisplayStatus: 'PARTIAL',
      receivedAmount: 400,
      expectedAmount: 1000,
      remainingAmount: 600,
    });
  });

  it('derives PAID only once the current settlement is fully received', () => {
    expect(
      derivePaymentDisplay({ expectedTotal: 1000, received: 1000 }),
    ).toEqual({
      paymentDisplayStatus: 'PAID',
      receivedAmount: 1000,
      expectedAmount: 1000,
      remainingAmount: 0,
    });
  });
});
