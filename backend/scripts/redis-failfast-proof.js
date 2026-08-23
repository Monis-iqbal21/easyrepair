/**
 * Proof for BRAIN §3.3 — backend boot hang on Valkey outage.
 *
 * Reproduces exactly what @nestjs/bull does at bull.providers.js:16
 *     new Bull(queueName, options.url, options)
 * and exactly what workers.processor.ts:39 does inside onModuleInit()
 *     await this.queue.add(JOB, {}, { jobId, repeat: {...} })
 *
 * Four configs x two worlds (Valkey down / Valkey up).
 * A healthy boot MUST still schedule the repeatable job — otherwise the fix
 * trades a crash for a silent loss of the stale-presence cleanup.
 *
 * Run:  node redis-failfast-proof.js
 */
const Bull = require('bull');

const DEAD_URL = 'redis://127.0.0.1:6399'; // nothing listening = Valkey down
const LIVE_URL = 'redis://127.0.0.1:6380'; // real redis-server started by the runner
const WAIT_MS = 15000;

const JOB_OPTS = {
  jobId: 'stale-presence-cleanup-repeat',
  repeat: { every: 60000 },
  removeOnComplete: true,
  removeOnFail: true,
};

const CONFIGS = {
  'current (url only)': undefined,
  'maxRetries+offlineOff': { maxRetriesPerRequest: 3, enableOfflineQueue: false },
  'maxRetries only': { maxRetriesPerRequest: 3 },
};

let n = 0;
const outcomeErrors = [];
process.on('unhandledRejection', (e) => {
  outcomeErrors.push('UNHANDLED: ' + (e && e.message));
});
async function trial(configName, redisOpts, url) {
  // opts === the object returned by BullModule.forRootAsync's useFactory
  const opts = { url };
  if (redisOpts) opts.redis = redisOpts;
  const queue = new Bull(`probe-${n++}`, url, opts);
  // Bull emits connection failures on 'error'; without a listener Node kills
  // the process, which would stop the table half-way. Count them instead.
  outcomeErrors.length = 0;
  queue.on('error', (e) => outcomeErrors.push(e.message));

  const t0 = Date.now();
  const outcome = await Promise.race([
    queue
      .add('stale-presence-cleanup', {}, JOB_OPTS)
      .then(() => ({ kind: 'RESOLVED' }))
      .catch((e) => ({ kind: 'REJECTED', msg: e.message })),
    new Promise((r) => setTimeout(() => r({ kind: 'PENDING' }), WAIT_MS)),
  ]);
  outcome.ms = Date.now() - t0;

  // On a healthy server, also prove the blocking client + subscriber still
  // work end-to-end: a job must actually be picked up and completed.
  if (url === LIVE_URL) {
    outcome.processed = await new Promise((resolve) => {
      const timer = setTimeout(() => resolve(false), 8000);
      queue.process('ping', async () => 'pong');
      queue.on('completed', () => {
        clearTimeout(timer);
        resolve(true);
      });
      queue.add('ping', {}).catch(() => {});
    });
    const o = queue.clients[0].options;
    outcome.resolved = `host=${o.host} port=${o.port} maxRetriesPerRequest=${o.maxRetriesPerRequest} enableOfflineQueue=${o.enableOfflineQueue}`;
  }
  outcome.errors = [...new Set(outcomeErrors)];
  try {
    await queue.close();
  } catch (_) {
    /* ignore */
  }
  return outcome;
}

const pad = (s, w) => String(s).padEnd(w);

(async () => {
  console.log('bull version   :', require('bull/package.json').version);
  console.log('ioredis version:', require('ioredis/package.json').version);
  console.log('');

  const rows = [];
  for (const [name, redisOpts] of Object.entries(CONFIGS)) {
    for (const [world, url] of [
      ['Valkey DOWN', DEAD_URL],
      ['Valkey UP', LIVE_URL],
    ]) {
      process.stdout.write(`running: ${pad(name, 24)} ${pad(world, 12)} ... `);
      const r = await trial(name, redisOpts, url);
      console.log(
        `${r.kind} (${r.ms} ms)` +
          (r.processed !== undefined ? `, job processed=${r.processed}` : ''),
      );
      if (r.msg) console.log(`         error: ${r.msg}`);
      if (r.resolved) console.log(`         client: ${r.resolved}`);
      if (r.errors && r.errors.length)
        console.log(`         queue 'error' events: ${r.errors.join(' | ')}`);
      rows.push({ name, world, ...r });
    }
  }

  console.log('\n' + '='.repeat(78));
  console.log(
    pad('config', 24) +
      pad('Valkey DOWN', 26) +
      pad('Valkey UP', 26),
  );
  console.log('='.repeat(78));
  for (const name of Object.keys(CONFIGS)) {
    const down = rows.find((r) => r.name === name && r.world === 'Valkey DOWN');
    const up = rows.find((r) => r.name === name && r.world === 'Valkey UP');
    console.log(
      pad(name, 24) +
        pad(`${down.kind} (${down.ms}ms)`, 26) +
        pad(`${up.kind} (${up.ms}ms) job=${up.processed}`, 26),
    );
  }
  console.log('='.repeat(78));
  console.log(
    'WANT:  Valkey DOWN -> REJECTED (boot continues, try/catch fires)\n' +
      '       Valkey UP   -> RESOLVED + job=true (repeatable job really scheduled)',
  );
  process.exit(0);
})();
