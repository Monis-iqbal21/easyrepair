import { readFileSync } from 'fs';
import { join } from 'path';
import configuration from '../../config/configuration';
import { PLATFORM_COMMISSION_RATE } from './commission.util';

const REPO_ROOT = join(__dirname, '..', '..', '..');

/**
 * FIX 7 — HandyGo's commission has exactly one source and it is not an env
 * var. `PLATFORM_FEE_PERCENT=10` was never read by any code while the real
 * rate was 18% of labour, so it could only ever mislead whoever read the
 * config next. These tests keep it gone.
 */
describe('platform commission configuration', () => {
  it('is a single hard-coded 18% and nothing else', () => {
    expect(PLATFORM_COMMISSION_RATE).toBe(0.18);
  });

  it('exposes no platform fee percent in the runtime config', () => {
    const config = configuration() as Record<string, unknown>;
    expect(config).not.toHaveProperty('platform');
    expect(JSON.stringify(config)).not.toContain('feePercent');
  });

  it('no longer declares PLATFORM_FEE_PERCENT as a validated env var', () => {
    const validation = readFileSync(
      join(REPO_ROOT, 'src', 'config', 'config.validation.ts'),
      'utf8',
    );
    expect(validation).not.toContain('PLATFORM_FEE_PERCENT');
  });

  it('leaves no PLATFORM_FEE_PERCENT default behind in .env.example', () => {
    const env = readFileSync(join(REPO_ROOT, '.env.example'), 'utf8');
    expect(env).not.toMatch(/^PLATFORM_FEE_PERCENT=/m);
  });
});

/**
 * FIX 6 — the inspection fee is decided in exactly one place:
 * `ServiceCategory.inspectionFee`, seeded from prisma/seed.ts and snapshotted
 * onto each booking at create time. AC Technician was the odd one out at
 * Rs 1000 while every other inspection category charged Rs 500.
 */
describe('inspection fees (prisma/seed.ts is the authoritative source)', () => {
  const seed = readFileSync(join(REPO_ROOT, 'prisma', 'seed.ts'), 'utf8');

  function feeFor(categoryName: string): number | null {
    const block = new RegExp(
      `name: '${categoryName}',[\\s\\S]*?inspectionFee: (\\d+|null)`,
    ).exec(seed);
    if (!block) throw new Error(`No seeded category named ${categoryName}`);
    return block[1] === 'null' ? null : Number(block[1]);
  }

  it.each([
    ['AC Technician', 500],
    ['Electrician', 500],
    ['Plumber', 500],
    ['Carpenter', 500],
    ['Appliances Repair', 500],
  ])('%s charges Rs %i to inspect', (name, expected) => {
    expect(feeFor(name)).toBe(expected);
  });

  it('leaves the non-inspection categories without a fee', () => {
    for (const name of ['Handyman', 'Cleaning', 'Painter', 'Pest Control']) {
      expect(feeFor(name)).toBeNull();
    }
  });

  it('has no lingering Rs 1000 inspection fee anywhere in the seed', () => {
    expect(seed).not.toMatch(/inspectionFee: 1000/);
  });
});
