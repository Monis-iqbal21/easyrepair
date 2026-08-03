import * as fs from 'fs';
import { MatchingModule } from './matching.module';
import { BookingsModule } from '../bookings/bookings.module';
import { WorkersModule } from '../workers/workers.module';
import { BidsModule } from '../bids/bids.module';

function sourceOf(path: string): string {
  return fs.readFileSync(path, 'utf-8');
}

/**
 * MatchingModule exists specifically to break a dependency cycle: broadcast
 * fan-out and completion notifications are needed by BookingsService,
 * WorkersService AND BidsService, and hosting them in any one of those would
 * force Bookings ↔ Workers to import each other.
 *
 * These tests pin that structural guarantee. `nest build` is the second gate —
 * Nest raises "A circular dependency has been detected" at bootstrap.
 */
describe('MatchingModule (leaf, no circular dependencies)', () => {
  function importsOf(mod: unknown): unknown[] {
    return (Reflect.getMetadata('imports', mod as object) as unknown[]) ?? [];
  }

  it('does not import BookingsModule, WorkersModule or BidsModule', () => {
    const imports = importsOf(MatchingModule);
    expect(imports).not.toContain(BookingsModule);
    expect(imports).not.toContain(WorkersModule);
    expect(imports).not.toContain(BidsModule);
  });

  // Asserted against source rather than decorator metadata: the app already
  // contains a Notifications↔Chat↔Bookings forwardRef cycle, so evaluating
  // these modules' `imports` arrays from a test entry point yields
  // partially-initialised (undefined) entries depending on import order.
  // Nest resolves that at bootstrap via the existing forwardRefs; the source
  // check below is deterministic and expresses the same guarantee.
  it('is imported by all three consumers, so they share one implementation', () => {
    for (const path of [
      'src/modules/bookings/bookings.module.ts',
      'src/modules/workers/workers.module.ts',
      'src/modules/bids/bids.module.ts',
    ]) {
      const src = sourceOf(path);
      expect(src).toContain("from '../matching/matching.module'");
      expect(src).toMatch(/imports:\s*\[[\s\S]*?MatchingModule/);
    }
  });

  it('adds no new cycle: MatchingModule never reaches back to a consumer', () => {
    const src = sourceOf('src/modules/matching/matching.module.ts');
    expect(src).not.toMatch(/bookings\.module|workers\.module|bids\.module/);
    // …and it needs no forwardRef of its own to stay resolvable.
    expect(src).not.toContain('forwardRef');
  });

  it('exports both shared services', () => {
    const exports =
      (Reflect.getMetadata('exports', MatchingModule) as unknown[]) ?? [];
    const names = exports.map((e) => (e as { name?: string })?.name);
    expect(names).toContain('JobBroadcastService');
    expect(names).toContain('JobCompletionNotifierService');
  });

  // The cycle this module prevents: neither feature service may reach for the
  // other directly.
  it('keeps BookingsService and WorkersService free of each other', () => {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const fs = require('fs') as typeof import('fs');
    const bookings = fs.readFileSync(
      'src/modules/bookings/bookings.service.ts',
      'utf-8',
    );
    const workers = fs.readFileSync(
      'src/modules/workers/workers.service.ts',
      'utf-8',
    );
    expect(bookings).not.toMatch(/from '\.\.\/workers\/workers\.service'/);
    expect(workers).not.toMatch(/from '\.\.\/bookings\/bookings\.service'/);
  });
});
