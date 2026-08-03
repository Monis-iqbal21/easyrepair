import { existsSync, readFileSync, readdirSync } from 'fs';
import * as path from 'path';
import { activeSources, loadSourceText } from './agreement-source.registry';

/**
 * The approved legal documents are plain `.txt` next to the code that reads
 * them. TypeScript does not emit them, so `nest build` only lands them in
 * `dist` because nest-cli.json says to copy them.
 *
 * When that config was absent the build passed, the server booted healthy,
 * and the first Ustaad to open the agreements screen got an ENOENT. Nothing
 * in the test suite noticed, because tests run against `src`.
 *
 * These tests guard the config itself, so the failure is caught in CI rather
 * than by a user. The build additionally runs
 * `scripts/verify-build-assets.js` (wired as `postbuild`), which checks the
 * real compiled output.
 */

const REPO_BACKEND = path.join(__dirname, '..', '..', '..', '..');

type NestCli = {
  compilerOptions?: {
    assets?: Array<string | { include?: string; outDir?: string }>;
  };
};

function nestCli(): NestCli {
  return JSON.parse(
    readFileSync(path.join(REPO_BACKEND, 'nest-cli.json'), 'utf8'),
  ) as NestCli;
}

describe('agreement documents are shipped with the build', () => {
  it('nest-cli.json copies the documents folder into dist/src', () => {
    const assets = nestCli().compilerOptions?.assets ?? [];

    const entry = assets.find(
      (a) =>
        typeof a === 'object' &&
        typeof a.include === 'string' &&
        a.include.includes('modules/agreements/source/documents'),
    ) as { include: string; outDir?: string } | undefined;

    expect(entry).toBeDefined();

    // The loader resolves `__dirname/documents`, and __dirname is
    // dist/src/modules/agreements/source at runtime — so the assets must land
    // under dist/src, not dist. Without this outDir they go to the wrong place
    // and the endpoint throws ENOENT despite a green build.
    expect(entry!.outDir).toBe('dist/src');
    expect(entry!.include).toMatch(/\*\*\/\*$/);
  });

  it('every approved source file exists on disk and hashes as pinned', () => {
    // Only ACTIVE sources have a file; the English and Urdu legal bodies are
    // still PENDING_TRANSLATION and deliberately have none.
    const active = activeSources();
    expect(active.length).toBeGreaterThan(0);

    for (const descriptor of active) {
      expect(descriptor.file).toBeTruthy();
      const file = path.join(__dirname, 'documents', descriptor.file!);
      expect(existsSync(file)).toBe(true);

      // Exercises the real tamper guard rather than re-implementing it.
      const loaded = loadSourceText(
        descriptor.documentType,
        descriptor.locale,
        descriptor.trade,
      );
      expect(loaded.sha256).toBe(descriptor.sha256);
      expect(loaded.text.length).toBeGreaterThan(1000);
    }
  });

  it('the build verifier covers every file the documents folder holds', () => {
    const onDisk = readdirSync(path.join(__dirname, 'documents'))
      .filter((f) => f.endsWith('.txt') || f.endsWith('.json'))
      .sort();

    const verifier = readFileSync(
      path.join(REPO_BACKEND, 'scripts', 'verify-build-assets.js'),
      'utf8',
    );

    // A new approved document that nobody added to the verifier would
    // otherwise be able to go missing from dist unnoticed.
    for (const file of onDisk) {
      expect(verifier).toContain(file);
    }
  });
});
